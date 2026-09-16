<template>
  <div class="dashbard_layout">
    <!-- 侧边导航栏 -->
    <div class="sidebar">
      <div class="side_logo">
        <div class="side_logo_text">TaskFlow</div>
      </div>
      <div class="side_menu">
        <RouterLink
          :class="['side_menu_item', useRoute().path === item.path ? 'active' : '']"
          v-for="item in Menu"
          :key="item.path"
          :to="item.path"
        >
          <!-- <User style="width: 18px" /> -->
          <component :is="item.icon" style="width: 18px"></component>
          <span>{{ item.label }}</span>
        </RouterLink>
      </div>
      <div class="side_bottom">
        <div class="side_menu_item" @click="logout">
          <SwitchButton style="width: 18px" />
          <span>退出登录</span>
        </div>
      </div>
    </div>
    <!-- 顶部导航栏 -->
    <div class="top_bar">
      <div class="left_title">{{ pageTitles[useRoute().path] }}</div>
      <div class="right">
        <img class="user_pice" :src="StoreObj.user_avatar" alt="" />
        <div class="user_name">{{ StoreObj.user_name }}</div>
      </div>
    </div>
    <div class="content">
      <!-- 用于放置二级路由页面的 -->
      <RouterView></RouterView>
    </div>
  </div>
</template>

<script setup>
import { onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { useCounterStore } from '@/stores/counter'
import axios from 'axios'
import router from '@/router'
import { ElMessage } from 'element-plus'

let StoreObj = useCounterStore()

onMounted(function () {
  // console.log(useRoute().path)
  // 更新数据仓库中的用户数据
  StoreObj.updateUserData()

  // 设置对应的侧边栏菜单
  axios({
    url: '/api/auth/me/',
    method: 'get',
  })
    .then((res) => {
      if (res.data.role === 'admin') {
        Menu.value = adminMenu
      } else if (res.data.role === 'client') {
        Menu.value = clientMenu
      } else {
        Menu.value = providerMenu
      }
    })
    .catch(() => {
      ElMessage.error('请求用户数据失败')
    })
})

// 客户菜单项
const clientMenu = [
  { path: '/client/dashboard', label: '工作台', icon: 'Menu' },
  { path: '/client/publish', label: '发布需求', icon: 'DocumentAdd' },
  { path: '/client/orders', label: '订单管理', icon: 'Memo' },
  { path: '/client/settings', label: '个人设置', icon: 'Setting' },
]

// 服务方菜单项
const providerMenu = [
  { path: '/provider/dashboard', label: '工作台', icon: 'Menu' },
  { path: '/provider/hall', label: '接单大厅', icon: 'Document' },
  { path: '/provider/orders', label: '我的订单', icon: 'Memo' },
  { path: '/provider/settings', label: '个人设置', icon: 'Setting' },
]

// 管理员菜单项
const adminMenu = [
  { path: '/admin/dashboard', label: '工作台', icon: 'Menu' },
  { path: '/admin/users', label: '用户管理', icon: 'UserFilled' },
  { path: '/admin/orders', label: '订单管理', icon: 'Memo' },
  { path: '/admin/settings', label: '个人设置', icon: 'Setting' },
]

// 决定页面中渲染的菜单项
let Menu = ref([])

// 顶部导航栏标题与路由地址的映射关系
const pageTitles = {
  '/client/dashboard': '工作台',
  '/client/publish': '发布需求',
  '/client/orders': '订单管理',
  '/client/orders/': '订单详情',
  '/client/review/': '评价服务',
  '/client/settings': '个人设置',
  '/provider/dashboard': '工作台',
  '/provider/hall': '接单大厅',
  '/provider/hall/': '需求详情',
  '/provider/orders': '我的订单',
  '/provider/orders/': '订单详情',
  '/provider/settings': '个人设置',
  '/admin/dashboard': '工作台',
  '/admin/users': '用户管理',
  '/admin/orders': '订单管理',
  '/admin/orders/': '订单详情',
  '/admin/settings': '个人设置',
}
// 退出登录
function logout() {
  axios({
    url: '/api/auth/logout/',
    method: 'post',
  }).then(() => {
    ElMessage.success('退出登录成功')
    // 跳转到登录页
    router.push('/login')
  })
}
</script>

<style lang="scss" scoped>
.dashbard_layout {
  background: #f8fafc;
  height: 100vh;
  box-sizing: border-box;
  padding-left: 240px;
  // 侧边导航栏
  .sidebar {
    position: fixed;
    left: 0;
    top: 0;
    width: 240px;
    height: 100vh;
    background: #0f172a;
    display: flex;
    flex-direction: column;
    flex-shrink: 0;
    .side_logo {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 18px 20px;
      .side_logo_icon {
        width: 28px;
        height: 28px;
        border-radius: 50%;
        background: #3b82f6;
      }
      .side_logo_text {
        color: #fff;
        font-size: 18px;
        font-weight: 700;
      }
    }
    .side_menu {
      flex: 1;
      padding: 8px 0;
      display: flex;
      flex-direction: column;
      gap: 4px;
      .side_menu_item {
        display: flex;
        align-items: center;
        gap: 10px;
        padding: 10px 20px;
        color: #94a3b8;
        font-size: 14px;
        cursor: pointer;
        transition: all 0.2s;
      }
      .side_menu_item:hover {
        color: #fff;
        background: rgba(255, 255, 255, 0.05);
      }
      .active {
        color: #fff;
        background: #1e3a5f;
      }
    }
    .side_bottom {
      padding: 8px 0 16px;
      border-top: 1px solid #1e293b;
      .side_menu_item {
        display: flex;
        align-items: center;
        gap: 10px;
        padding: 10px 20px;
        color: #94a3b8;
        font-size: 14px;
        cursor: pointer;
        transition: all 0.2s;
      }
      .side_menu_item:hover {
        color: #fff;
        background: rgba(255, 255, 255, 0.05);
      }
    }
  }
  // 顶部导航栏
  .top_bar {
    position: fixed;
    z-index: 99;
    width: calc(100% - 240px);
    box-sizing: border-box;
    top: 0;
    right: 0;
    height: 60px;
    background: #ffffff;
    border-bottom: 1px solid #e2e8f0;
    padding: 0 24px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-shrink: 0;
    .left_title {
      font-size: 18px;
      font-weight: 600;
    }
    .right {
      display: flex;
      align-items: center;
      gap: 8px;
      .user_pice {
        width: 32px;
        height: 32px;
        border-radius: 50%;
        background: #3b82f6;
        object-fit: cover;
      }
      .user_name {
        font-size: 14px;
        font-weight: 500;
      }
    }
  }
  .content {
    padding: 24px 32px;
    margin-top: 60px;
    box-sizing: border-box;
  }
}
</style>
