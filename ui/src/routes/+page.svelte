<style>
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
</style>

<script>
  let mode = $state('user');
  let user = $state(null);
  let loginName = $state("");
  let loginPass = $state("");
  fetch('/user').then((data)=> data.json()).then((data) => {
    if (data.name) {
      user = data;
    }
  });
  const loginOrSignUp = () => {
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
        if (e.key === "P") {
          mode = 'map';
          setInterval(() => {
            fetch('/state').then((data)=> data.json()).then((data) => {
              if (data) {
                console.log(data);
                grid = data.map;
                users = data.users;
                if (data.winner) {
                  winner = data.winner;
                }
              }
            });
          }, 200);
        }
      },
      false,
    );
  });
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
          {#each users as user}
            {#if user.x == tile.x && user.y == tile.y}
              <img src="https://pngimg.com/uploads/rat_mouse/rat_mouse_PNG2465.png" width="39" height="39"/>
            {/if}
          {/each}
        </div>
      {/each}
      </div>
    {/each}
    </div>
  {:else}
    {#if user === null}
      <h2>Log In/Sign up</h2>
      <div>Name: <input type="text" bind:value={loginName}/></div>
      <div>Password: <input type="password" bind:value={loginPass} /></div>
      <button onclick={loginOrSignUp}>Submit</button>
    {:else}
      <p>Welcome back, {user.name}</p>
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
    {/if}
  {/if}
{/if}
