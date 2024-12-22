<style>
  body, p, div, button, input {
    font-family: monospace;
  }
  p {
    font-size: 30px;
    text-align: center;
  }
  .moves div, .open-chest {
    display: flex;
    margin-top: 20px;
    margin-bottom: 20px;
    justify-content: center;
  }
  .moves div button, .open-chest button{
    font-size: 50px;
    width: 49%;
  }
</style>

<script>
  import Results from './Results.svelte';
  import Map from './Map.svelte';
  import Login from './Login.svelte';
  import { ctx } from './state.svelte.js';
  import { padHex } from '$lib/index.js';
  let round = $state(1);
  let grid = $state([]);
  let mode = $state('user');
  let moveError = $state(false);
  let user = $derived((ctx.users || []).find(u => u.id === ctx.userId));

  const move = (direction) => {
    fetch(
      '/state',
      {
        headers: {'Content-Type':'application/json'},
        method: 'POST',
        body: JSON.stringify({direction: direction, uid: ""+user.id}),
        credentials: 'include',
      }
    ).then((data) => data.json()).then((data) => {
      if (data.error) {
        moveError = data.error;
      } else {
        moveError = false;
        if (data.users) {
          ctx.users = data.users;
        }
        if (data.map) {
          grid = data.map
        }
      }
    })
  };

  function toggleFullScreen() {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen();
    } else if (document.exitFullscreen) {
      document.exitFullscreen();
    }
  }

  $effect(() => {
    fetch('/user').then((data)=> data.json()).then((data) => {
      if (data.name) {
        if (!ctx.users.find(u => u.id === data.id)) {
          ctx.users.push(data);
        }
        ctx.userId = data.id;
      }
    });
    const wsstr = window.location.host.includes("zapata") ? "wss" : "ws";
    var ws = new WebSocket(`${wsstr}://${window.location.host}/chat`);
    ws.onmessage = function(e) {
      var data = JSON.parse(e.data);
      console.log('message', data);
      if (data && data.map) {
        grid = data.map;
        ctx.users = data.users;
        if (data.round) {
          round = data.round;
        }
        ctx.monsters = data.monsters;
      }
      return false;
    };
    ws.onclose = function(e) {
      console.log('closed', e);
    };

    ws.onopen = function(e) {
        console.log('open', e);
    };

    document.addEventListener(
      "keydown",
      (e) => {
        if (e.key === "Enter") {
          toggleFullScreen();
        }
        if (e.key === "?") {
          fetch(
            '/map',
            {
              headers: {'Content-Type':'application/json'},
              method: 'POST',
              credentials: 'include',
            }
          );
        }
        if (e.key === "P") {
          mode = 'map';
        }
        if (e.key === "w" && user) {
          move('n');
        }
        if (e.key === "s" && user) {
          move('s');
        }
        if (e.key === "d" && user) {
          move('e');
        }
        if (e.key === "a" && user) {
          move('w');
        }
      },
      false,
    );
  });
  const adjacentSpots = (x,y) => {
    console.log(grid);
    let results = [];
    if (grid && grid.length > 0) {
      results.push(grid[y-1] && grid[y-1][x]);
      results.push(grid[y+1] && grid[y+1][x]);
      results.push(grid[y][x-1]);
      results.push(grid[y][x+1]);
    }
    return results.filter(r => !!r);
  };
  let nearChest = $derived(user && !!adjacentSpots(user.x, user.y).find(t => t.chest));
</script>

{#if round === 4}
  <Results />
{:else}
  {#if mode == 'map'}
    <Map grid={grid} round={round} />
  {:else}
    {#if ctx.userId === null || !user}
      <Login />
    {:else}
      <p style="border-bottom: 5px solid #{padHex(ctx.userId.toString(16))}">Playing as <b>{user.name}</b></p>
      <p>
        <img src="https://www.onlygfx.com/wp-content/uploads/2020/11/stack-of-gold-coins-1-624x558.png" width="64" height="64"/>
        <b>{user.gold}</b> /
        <b>{user.banked}</b>
      </p>
      <p>Hearts: 
        {#if user.hearts == 3}
          <img src="heart.png" width="32" height="32"/>
        {/if}
        {#if user.hearts >= 2}
          <img src="heart.png" width="32" height="32"/>
        {/if}
        {#if user.hearts >= 1}
          <img src="heart.png" width="32" height="32"/>
        {/if}
      </p>
      {#if !user.exited}
        <div class="moves">
          <div>
            <button class="" onclick={() => move('n')}>↑</button>
          </div>
          <div>
            <button class="" onclick={() => move('w')}>←</button>
            <button class="" onclick={() => move('e')}>→</button>
          </div>
          <div>
            <button class="" onclick={() => move('s')}>↓</button>
          </div>
        </div>
        {#if nearChest}
          <div class="open-chest"><button onclick={() => move('o')}>Open Chest</button></div>
        {/if}
      {:else if user.hearts === 0}
        <p>Sorry, you died...</p>
      {:else}
        <p>You made it out! Wait for the next round to start</p>
      {/if}
      {#if moveError}
        <p style="color: red">{moveError}</p>
      {/if}
    {/if}
  {/if}
{/if}
