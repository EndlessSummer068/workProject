import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import axios from 'axios'
// 全局数据仓库，用于存储全局数据
export const useCounterStore = defineStore('counter', () => {
  // 用户头像
  let user_avatar = ref('')
  // 用户名
  let user_name = ref('')
  // 用户角色
  let user_role = ref('')
  // 更新用户信息
  function updateUserData() {
    axios({
      url: '/api/auth/me/',
      method: 'get',
    })
      .then((res) => {
        console.log(res.data)
        user_avatar.value = res.data.avatar
        user_name.value = res.data.username
        user_role.value = res.data.role
      })
      .catch(() => {
        ElMessage.error('获取用户信息失败')
      })
  }
  return { user_avatar, user_name, updateUserData }
})
