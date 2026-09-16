import axios from 'axios'

// 创建实例
const request = axios.create({
  // 开发时用完整地址，打包部署后改为 /api/v1（走 Nginx 反向代理） // [NEW]
  baseURL: '/api/v1', // api的base_url
  timeout: 10000 // 请求超时时间
})

// 请求拦截器: 在发送请求之前做一切处理
request.interceptors.request.use(
  config => {
    // 从 localStorage 取 Token
    const token = localStorage.getItem('token')
    // 如果有 Token，加到请求头里
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }
    return config
  },
  error => {
    // 对请求错误做些什么
    return Promise.reject(error)
  }
)

// 响应拦截器: 在接收到响应后做一切处理
request.interceptors.response.use(
  response => {
    // 直接返回响应数据
    return response.data
  },
  error => {
    // 统一处理响应错误
    if (error.response) {
      if (error.response.status === 401) {
        // Token 失效，清除 Token 并跳转到登录页
        localStorage.removeItem('token')
        window.location.href = '/login'
      }
    }
    return Promise.reject(error)
  }
)

export default request