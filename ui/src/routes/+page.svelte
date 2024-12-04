<style>
  body, p, div, button, input {
    font-family: monospace;
  }
  p {
    font-size: 30px;
    text-align: center;
  }
  .grid {
    width: 1760px;
    margin-left: auto;
    margin-right: auto;
  }
  .row {
    display: flex;
  }
  .tile {
    height: 40px;
    width: 40px;
    background-color: black;
    overflow: hidden;
  }
  .tile.grass {
    background-color: green;
  }
  .tile.stone {
    background-color: gray;
  }
  .tile.exit {
    background-color: red;
  }
  .moves div {
    display: flex;
    margin-top: 20px;
    margin-bottom: 20px;
    justify-content: center;
  }
  .moves div button{
    font-size: 50px;
    width: 49%;
  }
  .login {
    font-size: 30px;
    padding-right: 15px;
    padding-left: 15px;
  }
  .login h2 {
    font-size: 40px;
    margin-top: 5px;
    margin-bottom: 45px;
    text-align: center;
  }
  .login input {
    width: 100%;
    margin-left: 20px;
    font-size: 25px;
  }
  .login>div {
    display: flex;
    margin-bottom: 20px;
  }
  .login button {
    display: block;
    margin-top: 45px;
    margin-left: auto;
    margin-right: auto;
    width: 50%;
    font-size: 40px;
  }
</style>

<script>
  let mode = $state('user');
  let error = $state(false);
  let moveError = $state(false);
  let user = $state(null);
  let loginName = $state("");
  let loginPass = $state("");
  fetch('/user').then((data)=> data.json()).then((data) => {
    if (data.name) {
      user = data;
    }
  });
  const loginOrSignUp = () => {
    if (loginPass.length === 0) {
      error = "At least 1 character password please";
      return;
    }
    fetch(
      '/user',
      {
        headers: {'Content-Type':'application/json'},
        method: 'POST',
        body: JSON.stringify({name: loginName, pw: loginPass})
      }
    ).then((data) => data.json()).then((data) => {
        user = data;
    })
  };
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
        //user = data;
      if (data.error) {
        moveError = data.error;
      } else {
        moveError = false;
        if (data.users) {
          user = data.users.find(u => u.id == user.id);
        }
      }
    })
  };

  let winner = $state(null);
  let grid = $state([]);
  let users = $state([]);
  function toggleFullScreen() {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen();
    } else if (document.exitFullscreen) {
      document.exitFullscreen();
    }
  }

  $effect(() => {
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
          const wsstr = window.location.host.includes("zapata") ? "wss" : "ws";
          var ws = new WebSocket(`${wsstr}://${window.location.host}/chat`);
          ws.onmessage = function(e) {
            var data = JSON.parse(e.data);
            console.log('message', data);
            if (data.map) {
              grid = data.map;
              users = data.users;
              if (data.winner) {
                winner = data.winner;
              } else {
                winner = null;
              }
            }
            return false;
          };
          ws.onclose = function(e) {
            console.log('closed', e);
          };

          ws.onopen = function(e) {
              console.log('open', e);
          };
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
  const padHex = (str) => {
    if (str.length < 6) {
      return padHex('0'+str);
    } else {
      return str.substr(0,6);
    }
  };
</script>

{#if winner}
  <h1>{winner} Wins!</h1>
{:else}
  {#if mode == 'map'}
    <div class="grid">
    {#each grid as row}
      <div class="row">
      {#each row as tile}
        <div class="tile {tile.hidden ? '' : tile.kind}">
          {#if !tile.hidden}
            {#if tile.cheese}
              <img src="https://www.pngall.com/wp-content/uploads/2016/03/Cheese-Free-Download-PNG.png" width="32" height="32"/>
            {:else}
              {#each users as user}
                {#if user.x == tile.x && user.y == tile.y}
                  <img src="https://pngimg.com/uploads/rat_mouse/rat_mouse_PNG2465.png" width="37" height="37" style="border-bottom: 3px solid #{padHex(user.id.toString(16))}"/>
                {/if}
              {/each}
            {/if}
          {/if}
        </div>
      {/each}
      </div>
    {/each}
    </div>
  {:else}
    {#if user === null}
      <div class="login">
        <h2>Log In/Sign up</h2>
        <div>Name: <input type="text" bind:value={loginName}/></div>
        <div>Password: <input type="password" bind:value={loginPass} /></div>
        <button onclick={loginOrSignUp}>Submit</button>
        {#if error}
          <p style="color: red;">{error}</p>
        {/if}
      </div>
    {:else}
      <p style="border-bottom: 5px solid #{padHex(user.id.toString(16))}">Playing as <b>{user.name}</b></p>
      <p>
        <img src="https://www.pngall.com/wp-content/uploads/2016/03/Cheese-Free-Download-PNG.png" width="64" height="64"/>
        <b>{user.cheeses}</b>
      </p>
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
      {#if moveError}
        <p style="color: red">{moveError}</p>
      {/if}
    {/if}
  {/if}
{/if}
