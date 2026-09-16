<template>
  <div class="login_view">
    <div class="left">
      <h1>TaskFlow</h1>
      <p>专业服务 高效对接</p>
      <p>
        连接优质服务方与需求方<br />
        让每一次合作都精准高效
      </p>
    </div>
    <div class="right">
      <div class="login_form">
        <h2 class="title">欢迎回来</h2>
        <p>请输入您的账号和密码登录</p>
        <div class="group">
          <p>账号</p>
          <div class="input_wrapper">
            <User style="width: 18px; color: #94a3b8" />
            <input type="text" placeholder="请输入账号" v-model="user_name" />
          </div>
        </div>
        <div class="group">
          <p>密码</p>
          <div class="input_wrapper">
            <Lock style="width: 18px; color: #94a3b8" />
            <input
              placeholder="请输入密码"
              v-model="user_password"
              :type="password_status ? 'password' : 'text'"
            />
            <!-- 隐藏密码icon -->
            <Hide
              v-show="password_status"
              @click="password_status = !password_status"
              style="width: 18px; color: #94a3b8"
            />
            <!-- 显示密码icon -->
            <View
              v-show="!password_status"
              @click="password_status = !password_status"
              style="width: 18px; color: #94a3b8"
            />
          </div>
        </div>
        <div class="row">
          <label class="checkbox-label">
            <input type="checkbox" />
            <span>记住我</span>
          </label>
          <a href="#" class="forgot-link">忘记密码？</a>
        </div>
        <button class="login_btn" @click="loginBtn">登录</button>
        <!-- <p class="error_msg">{{ error_msg }}</p> -->
        <div class="divider">
          <span class="line"></span>
          <span class="text">或</span>
          <span class="line"></span>
        </div>
        <div class="link">
          <span>还没有账号？</span>
          <RouterLink to="/register">立即注册</RouterLink>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import router from '@/router'
import { useCounterStore } from '@/stores/counter'
import axios from 'axios'
import { ElMessage } from 'element-plus'
import { ro } from 'element-plus/es/locales.mjs'
import { ref } from 'vue'
let StoreObj = useCounterStore()
// 在访问仓库中的变量时不需要添加.value，因为仓库中的变量是响应式数据
// StoreObj.count = StoreObj.count + 1

// 密码的显示状态
let password_status = ref(true)

// 账号
let user_name = ref('')
// 密码
let user_password = ref('')

// 登录
function loginBtn() {
  // console.log(user_name.value)
  // console.log(user_password.value)
  if (user_name.value !== '' && user_password.value !== '') {
    // 登录
    axios({
      method: 'post',
      url: '/api/auth/login/',
      data: {
        username: user_name.value,
        password: user_password.value,
      },
    })
      .then(function (res) {
        if (res.data.success) {
          ElMessage.success('登录成功')
          // 跳转到对应的主页
          if (res.data.user.role === 'admin') {
            router.push('/admin/dashboard')
          } else if (res.data.user.role === 'client') {
            router.push('/client/dashboard')
          } else {
            router.push('/provider/dashboard')
          }
          // 存储数据到全局仓库
          StoreObj.user_data = res.data.user
        }
      })
      .catch(function (err) {
        if (!err.response.data.success) {
          ElMessage.error('账号或密码错误')
        }
      })
  } else {
    // 错误提示
    ElMessage.error('请输入账号或密码')
  }
}
</script>

<style scoped lang="scss">
.login_view {
  display: flex;
  width: 100vw;
  height: 100vh;
  .left {
    box-sizing: border-box;

    width: 50%;
    height: 100%;
    background: linear-gradient(180deg, #1e3a5f 0%, #1e40af 60%, #3b82f6 100%);
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 32px;
    padding: 60px;
    h1 {
      color: #fff;
      font-size: 36px;
      font-weight: 800;
    }
    :nth-child(2) {
      color: rgba(255, 255, 255, 0.8);
      font-size: 18px;
    }
    :nth-child(3) {
      color: rgba(255, 255, 255, 0.6);
      font-size: 15px;
      text-align: center;
      line-height: 1.6;
      width: 360px;
    }
  }

  .right {
    box-sizing: border-box;

    width: 50%;
    height: 100%;
    background: #ffffff;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 60px 80px;
    .login_form {
      width: 360px;
      display: flex;
      flex-direction: column;
      gap: 24px;
      .title {
        font-size: 28px;
        font-weight: 700;
      }
      > p {
        font-size: 14px;
        color: #64748b;
        margin-top: -16px;
      }
      .group {
        display: flex;
        flex-direction: column;
        gap: 6px;
        > p {
          font-size: 13px;
        }
        .input_wrapper {
          display: flex;
          align-items: center;
          gap: 8px;
          height: 44px;
          background: #f8fafc;
          border: 1px solid #e2e8f0;
          border-radius: 8px;
          padding: 0 12px;
          transition: border-color 0.2s;
          svg {
            color: #94a3b8;
            flex-shrink: 0;
          }
          input {
            flex: 1;
            border: none;
            background: transparent;
            font-size: 14px;
            color: #1e293b;
          }
          input::placeholder {
            color: #94a3b8;
          }
        }
        // 当有子元素被触发聚焦时
        .input_wrapper:focus-within {
          border-color: #3b82f6;
        }
      }
      .row {
        display: flex;
        justify-content: space-between;
        align-items: center;
        label {
          display: flex;
          align-items: center;
          gap: 6px;
          font-size: 13px;
          color: #64748b;
          cursor: pointer;
        }
        a {
          font-size: 13px;
          color: #3b82f6;
        }
      }
      .login_btn {
        width: 100%;
        height: 44px;
        background: #3b82f6;
        color: #fff;
        border-radius: 8px;
        font-size: 15px;
        transition: opacity 0.2s;
        display: flex;
        justify-content: center;
        align-items: center;
      }
      .login_btn:hover {
        opacity: 0.9;
      }
      .error_msg {
        color: #ef4444;
        font-size: 13px;
        text-align: center;
        margin-top: -8px;
      }
      .divider {
        display: flex;
        align-items: center;
        gap: 16px;
        .line {
          flex: 1;
          height: 1px;
          background: #e2e8f0;
        }
        .text {
          color: #94a3b8;
          font-size: 13px;
        }
      }
      .link {
        display: flex;
        justify-content: center;
        gap: 4px;
        font-size: 14px;
        color: #64748b;
        span {
          font-size: 14px;
          color: #64748b;
        }
        a {
          color: #3b82f6;
        }
      }
    }
  }
}
</style>
