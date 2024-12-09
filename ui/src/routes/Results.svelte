<style>
  .centered-400 {
    width: 400px;
    margin-left: auto;
    margin-right: auto;
  }
  .winning-list li:first-of-type {
    font-size: 40px;
    font-weight: bold;
  }
  .winning-list li {
    font-size: 30px;
  }
</style>

<script>
  import { users } from './user.svelte.js';
  let results = $derived(users.toSorted((a,b)=> b.banked - a.banked));
</script>

<div class="centered-400">
  <h1 style="text-align: center">Game Over!</h1>
  <ol class="winning-list">
  {#each results as result}
    <li>{result.name}: {result.banked}</li>
  {/each}
  </ol>
</div>
