<script>
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
        body: JSON.stringify({direction: direction})
      }
    ).then((data) => data.json()).then((data) => {
        //user = data;
    })
  };
</script>
<style>
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
