the absolute basics:

- / => the view of the overall gameboard. this is the SPA where the overall gamestate is found
- /me => either the login form or the player's view. this is the SPA where they can do actions

1. generate a "hidden" grid-map
2. let players move around it
3. let them find the exit


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
