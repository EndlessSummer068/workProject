<template>
  <div class="register_view">
    <div class="left">
      <h1>TaskFlow</h1>
      <p>加入我们 开启高效合作</p>
      <p>
        注册成为平台用户<br />
        享受专业的服务对接体验
      </p>
    </div>
    <div class="right">
      <div class="form">
        <h2>创建账号</h2>
        <p>填写一下信息完成注册</p>
        <div class="group">
          <p>选择角色</p>
          <div class="role_row">
            <div :class="['role_card', role === 'client' ? 'active' : '']" @click="role = 'client'">
              <svg
                data-v-c7806062=""
                xmlns="http://www.w3.org/2000/svg"
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="lucide lucide-briefcase-icon lucide-briefcase"
                aria-hidden="true"
              >
                <path d="M16 20V4a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"></path>
                <rect width="20" height="14" x="2" y="6" rx="2"></rect>
              </svg>
              <span>我是客户</span>
            </div>
            <div
              :class="['role_card', role === 'provider' ? 'active' : '']"
              @click="role = 'provider'"
            >
              <svg
                data-v-c7806062=""
                xmlns="http://www.w3.org/2000/svg"
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="lucide lucide-wrench-icon lucide-wrench"
                aria-hidden="true"
              >
                <path
                  d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.106-3.105c.32-.322.863-.22.983.218a6 6 0 0 1-8.259 7.057l-7.91 7.91a1 1 0 0 1-2.999-3l7.91-7.91a6 6 0 0 1 7.057-8.259c.438.12.54.662.219.984z"
                ></path>
              </svg>
              <span>我是服务方</span>
            </div>
          </div>
        </div>
        <div class="group">
          <p>账号</p>
          <div class="input_wrapper">
            <svg
              data-v-08aaad4e=""
              xmlns="http://www.w3.org/2000/svg"
              width="18"
              height="18"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              class="lucide input-icon lucide-user-icon lucide-user input-icon"
              aria-hidden="true"
            >
              <path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"></path>
              <circle cx="12" cy="7" r="4"></circle>
            </svg>
            <input type="text" placeholder="请设置账号" v-model="user_name" />
          </div>
        </div>
        <div class="group">
          <p>密码</p>
          <div class="input_wrapper">
            <svg
              data-v-08aaad4e=""
              xmlns="http://www.w3.org/2000/svg"
              width="18"
              height="18"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              class="lucide input-icon lucide-lock-icon lucide-lock input-icon"
              aria-hidden="true"
            >
              <rect width="18" height="11" x="3" y="11" rx="2" ry="2"></rect>
              <path d="M7 11V7a5 5 0 0 1 10 0v4"></path>
            </svg>
            <input type="password" placeholder="请设置密码（至少6位）" v-model="password" />
          </div>
        </div>
        <div class="group">
          <p>确认密码</p>
          <div class="input_wrapper">
            <svg
              data-v-08aaad4e=""
              xmlns="http://www.w3.org/2000/svg"
              width="18"
              height="18"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              class="lucide input-icon lucide-lock-icon lucide-lock input-icon"
              aria-hidden="true"
            >
              <rect width="18" height="11" x="3" y="11" rx="2" ry="2"></rect>
              <path d="M7 11V7a5 5 0 0 1 10 0v4"></path>
            </svg>
            <input type="password" placeholder="请再次输入密码" v-model="password2" />
          </div>
        </div>
        <div class="agree">
          <input type="checkbox" v-model="checked" />
          <span> 我已阅读并同意<a href="#">《服务协议》</a> </span>
        </div>
        <button class="register_btn" @click="RegisterBtn">注 册</button>
        <!-- <p class="error_msg">{{ error_msg }}</p> -->
        <div class="switch_link">
          <span>已有账号？</span>
          <RouterLink to="/login" class="to_login">立即登录</RouterLink>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import axios from 'axios'
import { ElMessage } from 'element-plus'
import { ref } from 'vue'

// 账号
let user_name = ref('')
// 密码
let password = ref('')
// 二次密码
let password2 = ref('')
// 角色
let role = ref('client')
// 协议勾选状态
let checked = ref(false)

// 注册
function RegisterBtn() {
  // console.log(user_name.value)
  // console.log(password.value)
  // console.log(password2.value)
  // console.log(role.value)
  // console.log(checked.value)

  if (user_name.value === '' || password.value === '' || password2.value === '') {
    ElMessage.error('数据不完整')
  } else if (password.value.length < 6) {
    ElMessage.error('密码长度至少6位')
  } else if (password.value !== password2.value) {
    ElMessage.error('两次密码不一致')
  } else if (!checked.value) {
    ElMessage.error('请同意服务协议')
  } else {
    // 调用注册接口
    axios({
      url: '/api/auth/register/',
      method: 'post',
      data: {
        username: user_name.value,
        password: password.value,
        role: role.value,
      },
    })
      .then(function (res) {
        if (res.data.success) {
          ElMessage.success('注册成功')
          // 跳转到登录页
          router.push('/login')
        }
      })
      .catch(function (err) {
        if (!err.response.data.success) {
          ElMessage.error(err.response.data.message)
        }
      })
  }
}
</script>

<style scoped lang="scss">
.register_view {
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
    width: 50%;
    height: 100%;
    background: #ffffff;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 40px 80px;
    overflow-y: auto;
    .form {
      width: 360px;
      display: flex;
      flex-direction: column;
      gap: 20px;
      h2 {
        font-size: 28px;
        font-weight: 700;
      }
      > p {
        font-size: 14px;
        color: #64748b;
        margin-top: -12px;
      }
      .group {
        display: flex;
        flex-direction: column;
        gap: 6px;
        > p {
          font-size: 13px;
        }
        .role_row {
          display: flex;
          gap: 12px;
          .role_card {
            flex: 1;
            height: 64px;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            gap: 4px;
            background: #f8fafc;
            border: 2px solid #e2e8f0;
            border-radius: 8px;
            cursor: pointer;
            font-size: 13px;
            color: #64748b;
            transition: all 0.2s;
          }
          .active {
            border-color: #3b82f6;
            color: #3b82f6;
          }
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
        .input_wrapper:focus-within {
          border-color: #3b82f6;
        }
      }
      .agree {
        display: flex;
        align-items: center;
        gap: 6px;
        font-size: 13px;
        color: #64748b;
        cursor: pointer;
        input {
          // input标签的强调颜色
          accent-color: #3b82f6;
        }
        span {
          font-size: 13px;
          color: #64748b;
          cursor: pointer;
          a {
            color: #3b82f6;
          }
        }
      }
      .register_btn {
        width: 100%;
        height: 44px;
        background: #3b82f6;
        color: #fff;
        border-radius: 8px;
        font-size: 15px;
        font-weight: 600;
        transition: opacity 0.2s;
      }
      .register_btn:hover {
        opacity: 0.9;
      }
      .error_msg {
        color: #ef4444;
        font-size: 13px;
        text-align: center;
        margin-top: -8px;
      }
      .switch_link {
        display: flex;
        justify-content: center;
        gap: 4px;
        font-size: 14px;
        color: #64748b;
        .to_login {
          color: #3b82f6;
          font-weight: 600;
        }
      }
    }
  }
}
</style>
