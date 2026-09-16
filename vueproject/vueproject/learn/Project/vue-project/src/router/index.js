import { createRouter, createWebHistory } from 'vue-router'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      redirect: '/login',
    },
    {
      path: '/login',
      name: 'Login',
      // component: function(){
      //   return import('../views/Login.vue')
      // }
      component: () => import('../views/Login.vue'),
    },
    {
      path: '/register',
      name: 'Register',
      component: () => import('../views/Register.vue'),
    },
    {
      path: '/admin',
      name: 'Admin',
      component: () => import('../views/DashboardLayout.vue'),
      // 二级路由
      children: [
        {
          path: 'dashboard',
          name: 'AdminDashboard',
          component: () => import('../views/admin/Dashboard.vue'),
        },
        {
          path: 'users',
          name: 'AdminUsers',
          component: () => import('../views/admin/Users.vue'),
        },
        {
          path: 'orders',
          name: 'AdminOrders',
          component: () => import('../views/admin/Orders.vue'),
        },
        {
          // 三级目录
          path: 'orders/:id',
          name: 'AdminOrderDetail',
          component: () => import('../views/admin/OrderDetail.vue'),
        },
        {
          path: 'settings',
          name: 'AdminSettings',
          component: () => import('../views/admin/Settings.vue'),
        },
      ],
    },
    {
      path: '/client',
      name: 'Client',
      component: () => import('../views/DashboardLayout.vue'),
      // 二级路由
      children: [
        {
          path: 'dashboard',
          name: 'ClientDashboard',
          component: () => import('../views/client/Dashboard.vue'),
        },
        {
          path: 'publish',
          name: 'ClientPublish',
          component: () => import('../views/client/Publish.vue'),
        },
        {
          path: 'orders',
          name: 'ClientOrders',
          component: () => import('../views/client/Orders.vue'),
        },
        {
          // 三级目录
          path: 'orders/:id',
          name: 'ClientOrderDetail',
          component: () => import('../views/client/OrderDetail.vue'),
        },
        {
          path: 'review/:id',
          name: 'ClientReview',
          component: () => import('../views/client/Review.vue'),
        },
        {
          path: 'settings',
          name: 'ClientSettings',
          component: () => import('../views/client/Settings.vue'),
        },
      ],
    },
    {
      path: '/provider',
      name: 'Provider',
      component: () => import('../views/DashboardLayout.vue'),
      // 二级路由
      children: [
        {
          path: 'dashboard',
          name: 'ProviderDashboard',
          component: () => import('../views/provider/Dashboard.vue'),
        },
        {
          path: 'hall',
          name: 'ProviderHall',
          component: () => import('../views/provider/Hall.vue'),
        },
        {
          path: 'orders',
          name: 'ProviderOrders',
          component: () => import('../views/provider/Orders.vue'),
        },
        {
          // 三级目录
          path: 'orders/:id',
          name: 'ProviderOrderDetail',
          component: () => import('../views/provider/OrderDetail.vue'),
        },
        {
          path: 'hall/:id',
          name: 'ProviderHallDetail',
          component: () => import('../views/provider/HallDetail.vue'),
        },
        {
          path: 'settings',
          name: 'ProviderSettings',
          component: () => import('../views/provider/Settings.vue'),
        },
      ],
    },
  ],
})

export default router
