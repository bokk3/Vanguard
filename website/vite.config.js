import { defineConfig } from 'vite';
import fs from 'fs';
import path from 'path';

let version = '0.8.0';
try {
  const versionPath = path.resolve(__dirname, '../VERSION');
  if (fs.existsSync(versionPath)) {
    version = fs.readFileSync(versionPath, 'utf-8').trim();
  }
} catch (e) {
  // fallback
}

export default defineConfig({
  root: './',
  publicDir: 'public',
  define: {
    __APP_VERSION__: JSON.stringify(version),
    __BUILD_TIME__: JSON.stringify(new Date().toISOString()),
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
  },
  server: {
    port: 3000,
    open: true,
  }
});
