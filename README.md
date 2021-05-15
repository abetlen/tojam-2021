# tojam-2021

## Game Design

The game will consist of an online table hockey game with high fantasy characters.

2-4 players can join a game to play against eachother on 2 teams.

A game has a time limit and periods vs. a game goes to a fixed number of points?

Players control 2-4 characters on the board at once.

The characters on each team are each one of 4 positions: a goalie, a defensemen, a mid fielder, and a forward.

Depending on their positions each character can move forward and backward along a fixed path on the track.

Each character position has a different movement speed, turning speed, and stick radius.

The puck is always moving, with it's speed going between a minimum and a maximum velocity.

## Software Design

From the main screen players can either host a new game or join one that's not already in progress.

Games are either in the lobby phase or they are in progress.

When a player hosts a game a new lobby is created with an invite code they can share with their friends.

Each player has a unique id generated when they land on the website to identify them.

As players enter the lobby they connect to the host player, the host is responsible for managing the game, all updates are sent to the host and updates are broadcast out to all other players.

When all players are ready the game begins.

The puck enters the arena from either the left or right side.

Each player has an on-screen indication of which characters they are currently controlling.

Players have 4 keys mapped to each character, these keys map to turn clockwise, turn counterclockwise, go forward, and go backward.

What happens if a player disconnects?
