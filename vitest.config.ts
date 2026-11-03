import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    include: ['cloudflare/test/**/*.test.ts'],
    globals: false,
    restoreMocks: true,
  },
});
