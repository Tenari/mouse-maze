import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [sveltekit()],
  server: {
    proxy: {
      '/user': 'http://localhost:3333',
      '/game': 'http://localhost:3333',
      '/map': 'http://localhost:3333',
      '/state': 'http://localhost:3333',
      '/chat': 'ws://localhost:3333',
      '/Indiana-Jones-PNG-HD-Image.png': 'http://localhost:3333',
      '/heart.png': 'http://localhost:3333',
      '/character.png': 'http://localhost:3333',
    }
  }
});
