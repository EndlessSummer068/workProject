import { fileURLToPath, URL } from 'node:url'

import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueDevTools from 'vite-plugin-vue-devtools'

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue(), vueDevTools()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  server: {
    // 开发服务器代理配置
    proxy: {
      // 将 /api 开头的请求转发到 Django 后端
      '/api': {
        // 后端服务器地址
        target: 'http://127.0.0.1:8000',
        // 启动跨域请求修改
        changeOrigin: true,
      },
      '/media': {
        target: 'http://127.0.0.1:8000',
        changeOrigin: true,
      },
      '/ws': {
        // ← 新增 WebSocket 代理
        target: 'ws://127.0.0.1:8000',
        ws: true, // ← 关键：启用 WebSocket 代理
      },
    },
  },
})
