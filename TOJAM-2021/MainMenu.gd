extends Control

var Arena = preload("res://Arena.tscn")

func _ready():
	randomize()

func _on_Host_pressed():
	$MainMenu.hide()
	$Lobby.show()
	var game_id = str(randi() % 100000)
	$Lobby/GameID.text = "Your Game ID is : %s" % game_id
	GameManager.connect("game_started", self, "_on_game_started")
	GameManager.host_game(game_id)

func _on_Join_pressed():
	var game_id = $MainMenu/GameID.text
	GameManager.connect("game_started", self, "_on_game_started")
	GameManager.join_game(game_id)

func _on_game_started():
	$Lobby.hide()
	$MainMenu.hide()
	self.add_child(Arena.instance())
	GameManager.disconnect("game_started", self, "_on_game_started")
