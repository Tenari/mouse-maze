import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

const path = 'http://localhost:3334';
export default defineConfig({
  plugins: [sveltekit()],
  server: {
    proxy: {
      '/user': path,
      '/game': path,
      '/map': path,
      '/state': path,
      '/chat': 'ws://localhost:3334',
      '/Indiana-Jones-PNG-HD-Image.png': path,
      '/heart.png': path,
      '/snake.png': path,
      '/character.png': path,
    }
  }
});
