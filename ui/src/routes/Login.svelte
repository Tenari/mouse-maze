<style>
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
  import { ctx } from './state.svelte.js';
  let loginName = $state("");
  let loginPass = $state("");
  let error = $state(false);

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
        ctx.userId = data.id;
    })
  };
</script>

<div class="login">
  <h2>Log In/Sign up</h2>
  <div>Name: <input type="text" bind:value={loginName}/></div>
  <div>Password: <input type="password" bind:value={loginPass} /></div>
  <button onclick={loginOrSignUp}>Submit</button>
  {#if error}
    <p style="color: red;">{error}</p>
  {/if}
</div>
