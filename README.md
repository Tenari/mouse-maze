# build the ui

```bash
cd ui && npm run build
```

# startup

```bash
cd server && zig build run
```

on the "projector" screen press "P" and "Enter" to put it in fullscreen

## TO DO

- [x] make the projector-view update on long-polling or websocket push
- [x] make the rats able to see down the hallways
- [x] figure out why the sessions aren't sticking
- [x] improve the login ui
- [x] color the rats uniquely
- [x] add cheeses to collect, change win condition to "first to exit the map with N cheeses"
- [x] reset-able games

## transform it into the temple-run/incan-gold

- [x] gold amounts
- [x] treasure chest
- [x] hearts for life
- [x] auto-reset and keep score across 3 rounds
- [x] trapped chests
- [x] display hearts as hearts not a number
- [x] better player icon
- [x] monsters
- [ ] different player avatars
- [ ] bigger squares
- [ ] space out the buttons
- [ ] limit your move speed
    - either mad-dash/speed-clicking
    - or turn-based n-moves per turn
    - or tick-based

## notes

the absolute basics:

- / => the view of the overall gameboard. this is the SPA where the overall gamestate is found
- /me => either the login form or the player's view. this is the SPA where they can do actions

1. generate a "hidden" grid-map
2. let players move around it
3. let them find the exit

# temple-runner dungeon game

goal: get the most treasure out of the dungeon.

turns: players all can act at "same time" but you have limited moves. Then monsters all act.

actions: move, search for traps, attack direction, examine treasure, pick up loot

players have various stats: carrying capacity, hp/heart, move speed, lock picking, etc

combat is a bad proposition, but you can team up and fight monsters.

players are sort-of working together, but the longer they stay in the maze, the more monsters spawn. If you die, you get nothing

# Merchants trading game

goal: make the most money in some amount of turns

making money: you're a merchant. buying low, moving to a new place, and selling high.

map: 9x9 grid, center tile is starting city, full map is generated and visible at the start

tiles: city, village, forest, plains, river

play: turn-based, but everyone does their turns at the same time and the results are displayed on the "master" screen. Each player has their own "private" view

turns:

- in a city/village you can:
    - trade with 1 vendor
    - hire guard(s)
    - buy/sell carts
- in a 

# Pretty princess game

goal: marry the "best" guy, each princess has different definition of "best"

you have to discover information about the eligible bachelors by spending time/actions with them

you can travel to various balls/noble houses to meet up with people

guys have different stats, money, power, romanticness, kindness, which can be revealed by princesses spending actions on them

each princess has a relationship valence mechanic with all the guys

Balls provide opportunities to meet people, and to gossip about others (potentially hurt their relationships)


### how to deploy

vim /etc/nginx/sites-available/treasure

```
server {
    server_name treasure.zapatas.xyz ;

    location / {
        proxy_pass http://127.0.0.1:3334;
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    server_name treasure.zapatas.xyz ;

}
```
