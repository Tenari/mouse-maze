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
          <img src="https://pluspng.com/img-png/explosion-png-hd--600.png" width="32" height="32"/>
        {:else if tile.gold > 0 && !tile.chest}
          <img src="https://www.onlygfx.com/wp-content/uploads/2020/11/stack-of-gold-coins-1-624x558.png" width="32" height="32"/>
        {:else if tile.chest}
          <img src="https://png.pngtree.com/png-clipart/20230103/original/pngtree-old-rusty-closed-treasure-chest-side-view-transparent-png-image_8864712.png" width="32" height="32"/>
        {:else}
          {#each ctx.monsters as monster}
            {#if monster.x == tile.x && monster.y == tile.y}
              <img src="{monster.kind}.png" width="37" height="37"/>
            {/if}
          {/each}
          {#each ctx.users as user}
            {#if !user.exited && user.x == tile.x && user.y == tile.y && user.hearts > 0}
              <img src="character.png" width="37" height="37" style="border-bottom: 3px solid #{padHex(user.id.toString(16))}"/>
            {/if}
          {/each}
        {/if}
      {/if}
    </div>
  {/each}
  </div>
{/each}
</div>
