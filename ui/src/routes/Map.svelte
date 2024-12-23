<style>
  .grid {
    width: 1760px;
    margin-left: auto;
    margin-right: auto;
    touch-action: manipulation;
  }
  .row {
    display: flex;
  }
  .tile {
    height: 44px;
    width: 44px;
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
</style>

<script>
  import { padHex } from '$lib/index.js';
  import { ctx } from './state.svelte.js';
  let { grid, round } = $props();
</script>

<h1>Treasure Hunt - Round #{round}</h1>
<div class="grid">
{#each grid as row}
  <div class="row">
  {#each row as tile}
    <div class="tile {tile.hidden ? '' : tile.kind}">
      {#if !tile.hidden}
        {#if (Date.now() - tile.exploded_at) < 2000 }
          <img src="explosion.png" width="36" height="36"/>
        {:else if tile.gold > 0 && !tile.chest}
          <img src="gold-coins.png" width="36" height="36"/>
        {:else if tile.chest}
          <img src="treasure-chest.png" width="36" height="36"/>
        {:else}
          {#each ctx.monsters as monster}
            {#if monster.x == tile.x && monster.y == tile.y}
              <img src="{monster.kind}.png" width="40" height="40"/>
            {/if}
          {/each}
          {#each ctx.users as user}
            {#if !user.exited && user.x == tile.x && user.y == tile.y && user.hearts > 0}
              <img src="character{user.id}.png" width="40" height="40" style="border-bottom: 3px solid #{padHex(user.id.toString(16))}"/>
            {/if}
          {/each}
        {/if}
      {/if}
    </div>
  {/each}
  </div>
{/each}
</div>
