<template>
  <div class="settings">
    <!-- 更新头像 -->
    <div class="card">
      <div class="section_header">
        <User style="width: 18px; color: #3b82f6" />
        <span>更新头像</span>
      </div>
      <div class="avatar_section">
        <el-upload
          class="avatar-uploader"
          action="/api/auth/me/"
          method="put"
          name="avatar"
          :show-file-list="false"
          :with-credentials="true"
          :on-success="handleAvatarSuccess"
          :on-error="handleAvatarError"
          :before-upload="beforeAvatarUpload"
        >
          <el-icon class="avatar-uploader-icon"><Plus /></el-icon>
        </el-upload>
      </div>
    </div>
    <!-- 修改用户名 -->
    <div class="card">
      <div class="section_header">
        <Document style="width: 18px; color: #3b82f6" />
        <span>修改用户名</span>
      </div>
      <div class="form_group">
        <p>用户名</p>
        <div class="input_wrapper">
          <User class="icon" style="width: 16px; color: #94a3b8" />
          <input v-model="new_username" placeholder="请输入用户名" />
        </div>
      </div>
      <button class="btn_primary" @click="updateUsername">保存修改</button>
    </div>
    <!-- 修改密码 -->
    <div class="card">
      <div class="section_header">
        <Lock style="width: 18px; color: #3b82f6" />
        <span>修改密码</span>
      </div>
      <div class="form_group">
        <p>当前密码</p>
        <div class="input_wrapper">
          <Lock class="icon" style="width: 16px; color: #94a3b8" />
          <input v-model="oldPassword" type="password" placeholder="请输入当前密码" />
        </div>
      </div>
      <div class="form_row">
        <div class="form_group">
          <p>新密码</p>
          <div class="input_wrapper">
            <Lock class="icon" style="width: 16px; color: #94a3b8" />
            <input v-model="newPassword" type="password" placeholder="至少6位" />
          </div>
        </div>
        <div class="form_group">
          <p>确认新密码</p>
          <div class="input_wrapper">
            <Lock class="icon" style="width: 16px; color: #94a3b8" />
            <input v-model="confirmPassword" type="password" placeholder="再次输入新密码" />
          </div>
        </div>
      </div>
      <button class="btn_primary" @click="updatePassword">保存修改</button>
    </div>
  </div>
</template>

<script setup>
import { ElMessage } from 'element-plus'
import { Plus, User, Document, Lock } from '@element-plus/icons-vue'
import axios from 'axios'
import { ref } from 'vue'
import { useCounterStore } from '@/stores/counter'
// 引入全局数据库中的用户信息
let StoreObj = useCounterStore()

// 上传文件前，自动触发的函数    限制上传的图片大小
const beforeAvatarUpload = (file) => {
  const isImage = file.type.startsWith('image/')
  const isLt2M = file.size / 1024 / 1024 < 2
  if (!isImage) {
    ElMessage.error('只能上传图片文件')
    return false
  }
  if (!isLt2M) {
    ElMessage.error('图片大小不能超过 2MB')
    return false
  }
  return true
}

// 上传文件成功后触发的函数
const handleAvatarSuccess = () => {
  ElMessage.success('头像更新成功')
  axios({
    url: '/api/auth/me/',
    method: 'get',
  }).then((res) => {
    // console.log(res.data)
    // 更新全局数据库中的用户信息
    StoreObj.updateUserData()
  })
}

// 上传失败时自动触发的函数
const handleAvatarError = () => {
  ElMessage.error('头像上传失败')
}

// 当前密码
let oldPassword = ref('')
// 新密码
let newPassword = ref('')
// 确认新密码
let confirmPassword = ref('')
// 修改密码按钮
function updatePassword() {
  if (newPassword.value === confirmPassword.value) {
    axios({
      url: '/api/auth/change-password/',
      method: 'post',
      data: {
        old_password: oldPassword.value,
        new_password: newPassword.value,
      },
    })
      .then(() => {
        ElMessage.success('修改成功')
        // 更新全局数据库中的用户信息
        StoreObj.updateUserData()
        // console.log(res.data)
        // 清空密码输入框
        oldPassword.value = ''
        newPassword.value = ''
        confirmPassword.value = ''
      })
      .catch((err) => {
        ElMessage.error(err.response.data.message)
      })
  } else {
    ElMessage.error('两次输入密码不一致')
  }
}

// 用户名
let new_username = ref('')
// 修改用户名按钮
function updateUsername() {
  axios({
    url: '/api/auth/me/',
    method: 'put',
    data: {
      username: new_username.value,
    },
  })
    .then(() => {
      ElMessage.success('修改成功')
      // 更新全局数据库中的用户信息
      StoreObj.updateUserData()
      // console.log(res.data)
      // 清空用户名输入框
      new_username.value = ''
    })
    .catch(() => {
      ElMessage.error('修改失败')
    })
}
</script>

<style lang="scss" scoped>
.avatar-uploader .el-upload {
  border: 1px dashed var(--el-border-color);
  border-radius: 6px;
  cursor: pointer;
  position: relative;
  overflow: hidden;
  transition: var(--el-transition-duration-fast);
}

.avatar-uploader .el-upload:hover {
  border-color: var(--el-color-primary);
}

.el-icon.avatar-uploader-icon {
  font-size: 28px;
  color: #8c939d;
  width: 100px;
  height: 100px;
  text-align: center;
  border: 1px solid #e2e8f0;
}

.settings {
  max-width: 640px;
  display: flex;
  flex-direction: column;
  gap: 20px;
  .card {
    background: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 16px;
    padding: 28px 32px;
    display: flex;
    flex-direction: column;
    gap: 20px;
    .section_header {
      display: flex;
      align-items: center;
      gap: 10px;
      font-size: 16px;
      font-weight: 600;
      color: #1e293b;
      padding-bottom: 16px;
      border-bottom: 1px solid #e2e8f0;
    }
    .avatar_section {
      display: flex;
      justify-content: center;
    }
    .form_group {
      flex-grow: 1;
      display: flex;
      flex-direction: column;
      gap: 6px;
      p {
        font-size: 13px;
        font-weight: 500;
        color: #64748b;
      }
      .input_wrapper {
        position: relative;
        display: flex;
        align-items: center;
        .icon {
          position: absolute;
          left: 12px;
          color: #94a3b8;
          pointer-events: none;
          z-index: 1;
        }
        input {
          width: 100%;
          height: 44px;
          padding: 0 12px 0 36px;
          background: #f8fafc;
          border: 1px solid #e2e8f0;
          border-radius: 10px;
          font-size: 14px;
          color: #1e293b;
          transition:
            border-color 0.2s,
            box-shadow 0.2s;
          outline: none;
        }
        input:focus {
          border-color: #3b82f6;
          box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
        }
        input::placeholder {
          color: #94a3b8;
        }
      }
    }
    .form_row {
      display: flex;
      gap: 16px;
    }
    .btn_primary {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      height: 42px;
      padding: 0 28px;
      background: #3b82f6;
      color: #fff;
      border: none;
      border-radius: 10px;
      font-size: 14px;
      font-weight: 500;
      cursor: pointer;
      align-self: flex-start;
      transition:
        background 0.2s,
        transform 0.1s;
    }
    .btn_primary:hover {
      background-color: rgba(59, 130, 246, 0.9);
    }
  }
}
</style>
