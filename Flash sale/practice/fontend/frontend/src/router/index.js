import Vue from 'vue'
import VueRouter from 'vue-router'
import HomeView from '../views/HomeView.vue'
import LoginView from '../views/LoginView.vue'
import OrdersView from '../views/OrdersView.vue'

Vue.use(VueRouter)

const routes = [
   {
    path: '/',
    name: 'HomeView',
    component: HomeView
  },
  {
    path: '/login',
    name: 'LoginView',
    component: LoginView
  },
  {
    path: '/orders',
    name: 'OrdersView',
    component: OrdersView
  }
]

const router = new VueRouter({
  mode: 'history',
  base: process.env.BASE_URL,
  routes
})

// 路由守卫：进入首页前检查是否登录
router.beforeEach((to, from, next) => {
  const token = localStorage.getItem('token')
  // 如果要去首页且没 Token，跳转到登录页
  if (to.path === '/' && !token) {
    next('/login')
  } else {
    next()
  }
})

export default router
