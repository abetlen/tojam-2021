package main

import (
	"bufio"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"sync"

	// Router
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"

	// Websockets
	"github.com/gobwas/ws"
)

type Message struct {
	Type    string `json:"type,omitempty"`
	From    string `json:"from,omitempty"`
	To      string `json:"to,omitempty"`
	Topic   string `json:"topic,omitempty"`
	Payload string `json:"payload,omitempty"`
}

type Peer struct {
	joined  chan string
	message chan Message
	quit    chan string
	ID      string
	IDHash  string
}

type Room struct {
	ID    string
	peers sync.Map
}

func (r *Room) Leave(user *Peer) {
	r.peers.Range(func(key interface{}, value interface{}) bool {
		peerID, ok := key.(string)
		if !ok {
			return true
		}
		if peerID == user.ID {
			return true
		}
		peer, ok := value.(Peer)
		if !ok {
			return true
		}
		select {
		case peer.quit <- user.ID:
			return true
		default:
			r.peers.Delete(key)
		}
		return true
	})
	r.peers.Delete(user.ID)
	log.Printf("left: user %s left room %s\n", user.ID, r.ID)
}

func (r *Room) Join(user *Peer) bool {
	_, loaded := r.peers.LoadOrStore(user.ID, *user)
	if loaded {
		return false
	}
	r.peers.Range(func(key interface{}, value interface{}) bool {
		peer, ok := value.(Peer)
		if !ok {
			return true
		}
		select {
		case peer.joined <- user.ID:
			return true
		default:
			r.peers.Delete(key)
		}
		return true
	})
	log.Printf("joined: user %s joined room %s\n", user.ID, r.ID)
	return true
}

func (r *Room) Broadcast(user *Peer, m Message) {
	m.From = user.ID
	r.peers.Range(func(key interface{}, value interface{}) bool {
		peerID, ok := key.(string)
		if !ok {
			return true
		}
		if peerID == user.ID {
			return true
		}
		peer, ok := value.(Peer)
		if !ok {
			return true
		}
		if m.To != "" && m.To != peer.ID {
			return true
		}
		select {
		case peer.message <- m:
			return true
		default:
			return true
		}
	})
}

func ReadJSON(rw *bufio.ReadWriter, v interface{}) error {
	dec := json.NewDecoder(rw.Reader)
	return dec.Decode(v)
}

func WriteJSON(rw *bufio.ReadWriter, v interface{}) error {
	enc := json.NewEncoder(rw.Writer)
	return enc.Encode(v)
}

func wsReader(rw *bufio.ReadWriter, user *Peer, room *Room) {
	for {
		m := Message{}
		err := ReadJSON(rw, &m)
		if err != nil {
			room.Leave(user)
			log.Print(err)
			return
		}
		room.Broadcast(user, m)
	}
}

func main() {
	secret := os.Getenv("PORT")
	if secret == "" {
		secret = "secret"
	}
	rooms := sync.Map{}
	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.Get("/{roomID}", func(w http.ResponseWriter, r *http.Request) {
		conn, rw, _, err := ws.UpgradeHTTP(r, w)
		if err != nil {
			log.Print(err)
			return
		}
		defer conn.Close()
		roomID := chi.URLParam(r, "roomID")
		v, loaded := rooms.LoadOrStore(roomID, &Room{
			peers: sync.Map{},
			ID:    roomID,
		})
		if !loaded {
			log.Printf("created room: %s\n", roomID)
		}
		room, ok := v.(*Room)
		if !ok {
			log.Print("type assertion: failed to assert interface{} as Room")
			return
		}
		userID := fmt.Sprintf("%d", rand.Uint64())

		mac := hmac.New(sha256.New, []byte(secret))
		mac.Write([]byte(userID))
		userIDHash := base64.URLEncoding.EncodeToString(mac.Sum(nil))

		queryParams := r.URL.Query()
		claimedUserID := queryParams.Get("id")
		claimedUserIDHash := queryParams.Get("token")

		if claimedUserID != "" && claimedUserIDHash != "" {
			mac := hmac.New(sha256.New, []byte(secret))
			mac.Write([]byte(claimedUserID))
			computedMAC := mac.Sum(nil)
			decodedMAC, err := base64.URLEncoding.DecodeString(claimedUserIDHash)

			if err != nil {
				return
			}

			if hmac.Equal(decodedMAC, computedMAC) {
				userID = claimedUserID
				userIDHash = claimedUserIDHash
			}
		}

		user := Peer{
			joined:  make(chan string, 1),
			message: make(chan Message),
			quit:    make(chan string),
			ID:      userID,
			IDHash:  userIDHash,
		}

		ok = room.Join(&user)
		if !ok {
			log.Print("user exists: user already exists")
			return
		}

		go wsReader(rw, &user, room)

		for {
			select {
			case peerID := <-user.joined:
				m := Message{
					Type: "join",
					From: peerID,
					To:   user.ID,
				}
				if user.ID == peerID {
					m.Payload = user.IDHash
				}
				err := WriteJSON(rw, m)
				if err != nil {
					room.Leave(&user)
					log.Print(err)
					return
				}
			case peerID := <-user.quit:
				err := WriteJSON(rw, Message{
					Type: "leave",
					From: peerID,
					To:   user.ID,
				})
				if err != nil {
					room.Leave(&user)
					log.Print(err)
					return
				}
			case m := <-user.message:
				err := WriteJSON(rw, Message{
					Type:    "message",
					To:      m.To,
					From:    m.From,
					Topic:   m.Topic,
					Payload: m.Payload,
				})
				if err != nil {
					room.Leave(&user)
					log.Print(err)
					return
				}
			}
		}

	})
	host := os.Getenv("HOST")
	port := os.Getenv("PORT")
	if port == "" {
		port = "3000"
	}
	address := host + ":" + port
	log.Printf("Starting server at %v", address)
	http.ListenAndServe(address, r)
}
