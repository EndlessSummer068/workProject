<template>
  <div class="order_detail">
    <div class="back_row">
      <button class="btn_back" @click="router.back()">返回</button>
    </div>
    <div class="detail_grid">
      <div class="main_section">
        <div class="detail_card">
          <div class="detail_header">
            <div>
              <h2>{{ order_detail.need_title }}</h2>
              <span class="detail_id">{{ order_detail.id }}</span>
            </div>
            <span :class="['status_badge', order_detail.status]">
              {{
                order_detail.status === 'pending'
                  ? '待接单'
                  : order_detail.status === 'in_progress'
                    ? '进行中'
                    : order_detail.status === 'completed'
                      ? '待客户支付'
                      : order_detail.status === 'paid'
                        ? '待客户评价'
                        : order_detail.status === 'reviewed'
                          ? '已完成'
                          : order_detail.status === 'cancelled'
                            ? '已取消'
                            : ''
              }}
            </span>
          </div>
          <div class="info_grid">
            <div class="info_item">
              <span class="label">服务方</span>
              <span class="value">{{
                order_detail.provider ? order_detail.provider : '待分配'
              }}</span>
            </div>
            <div class="info_item">
              <span class="label">订单金额</span>
              <span class="value amount">¥{{ order_detail.amount }}</span>
            </div>
            <div class="info_item">
              <span class="label">当前进度</span>
              <span class="value">{{ order_detail.progress }}%</span>
            </div>
          </div>
          <!--v-if-->
        </div>
        <div class="progress_section">
          <h3>订单进度</h3>
          <div class="progress_bar_large">
            <div class="progress_fill" :style="{ width: `${order_detail.progress}%` }"></div>
          </div>
          <div class="progress_steps">
            <div class="step">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="lucide lucide_circle_check_icon lucide_circle_check"
                aria-hidden="true"
              >
                <circle cx="12" cy="12" r="10"></circle>
                <path d="m9 12 2 2 4-4"></path>
              </svg>
              需求确认
            </div>
            <div class="step">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="lucide lucide_circle_check_icon lucide_circle_check"
                aria-hidden="true"
              >
                <circle cx="12" cy="12" r="10"></circle>
                <path d="m9 12 2 2 4-4"></path>
              </svg>
              开始执行
            </div>
            <div class="step">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="lucide lucide_circle_check_icon lucide_circle_check"
                aria-hidden="true"
              >
                <circle cx="12" cy="12" r="10"></circle>
                <path d="m9 12 2 2 4-4"></path>
              </svg>
              交付验收
            </div>
            <div class="step">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="lucide lucide_circle_check_icon lucide_circle_check"
                aria-hidden="true"
              >
                <circle cx="12" cy="12" r="10"></circle>
                <path d="m9 12 2 2 4-4"></path>
              </svg>
              完成
            </div>
          </div>
        </div>
        <div class="review-section" v-if="reviews">
          <h3>我的评价</h3>
          <div class="review-card-inner">
            <div class="review-stars">
              <Star
                v-for="(itme, index) in 5"
                :data-a="index"
                :style="{ width: '32px', color: index < reviews.rating ? '#f59e0b' : '#ccc' }"
              />
              <span class="review-score">{{ reviews.rating }}.0 分</span>
            </div>
            <div class="review-tags">
              <span class="review-tag" v-for="item in reviews.tags.split(',')">{{ item }}</span>
            </div>
            <p class="review-comment">{{ reviews.comment }}</p>
          </div>
        </div>
        <div class="message_section">
          <h3>沟通记录</h3>
          <div class="message_list" ref="messageWindow">
            <div
              :class="['message_item', item.sender_role]"
              v-for="item in order_message"
              :key="item.id"
            >
              <div class="msg_avatar">
                <img :src="item.sender_avatar" width="100%" height="100%" />
              </div>
              <div class="msg_content">
                <span class="msg_name">{{ item.sender_name }}</span
                ><span class="msg_text">{{ item.text }}</span>
              </div>
            </div>
          </div>
          <div class="message_input">
            <input placeholder="输入消息..." v-model="input_message" /><button
              class="btn_send"
              @click="sendMessage"
            >
              发送
            </button>
          </div>
        </div>
      </div>
      <div class="side_section">
        <div class="payment_card">
          <h3>支付信息</h3>
          <div class="payment_info">
            <div class="pay_row">
              <span>订单金额</span>
              <span>¥{{ order_detail.amount }}</span>
            </div>
            <div class="pay_row">
              <span>支付状态</span>
              <span class="unpaid">{{
                order_detail.status === 'paid' || order_detail.status === 'reviewed'
                  ? '已支付'
                  : '未支付'
              }}</span>
            </div>
          </div>
          <button class="btn_pay" v-if="order_detail.status === 'completed'" @click="playBtn">
            确认支付 ¥{{ order_detail.amount }}
          </button>
          <button class="btn_review" v-if="order_detail.status === 'paid'" @click="reviewBtn">
            去评价
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import router from '@/router'
import axios from 'axios'
import { ElMessage } from 'element-plus'

import { nextTick, onMounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'

// 拿到路由信息对象
let route = useRoute()
let orderId = route.params.id

// 订单详情数据
let order_detail = ref({})

// 订单消息
let order_message = ref([])

// 评价数据
let reviews = ref('')

onMounted(() => {
  // 获取订单数据
  axios({
    method: 'get',
    url: `/api/orders/${orderId}/`,
  })
    .then((res) => {
      order_detail.value = res.data
    })
    .catch((error) => ElMessage.error('请求数据失败'))

  // 获取消息
  axios({
    method: 'get',
    url: '/api/messages/',
    params: { order: orderId },
  })
    .then((res) => {
      order_message.value = res.data
      // DOM更新后滚动到底部
      nextTick(() => {
        messageWindow.value.scrollTop = messageWindow.value.scrollHeight
      })
    })
    .catch((error) => ElMessage.error('获取信息'))

  // 获取评价信息
  axios({
    method: 'get',
    url: '/api/reviews/',
    params: { order: orderId },
  })
    .then((res) => (reviews.value = res.data[0]))
    .catch((error) => console.error(error))
})

// 创建WebSocket连接
// 连接 WebSocket
const ws = new WebSocket(`ws://localhost:5173/ws/chat/${orderId}/`)

// 连接成功
ws.onopen = () => {
  console.log('WebSocket 已连接')
}

let messageWindow = ref(null)

// 收到消息（实时推送）
ws.onmessage = (event) => {
  const msg = JSON.parse(event.data)
  order_message.value.push(msg)
  // DOM更新后滚动到底部
  nextTick(() => {
    messageWindow.value.scrollTop = messageWindow.value.scrollHeight
  })
}

// 输入框内容
let input_message = ref('')

// 发送信息
function sendMessage() {
  ws.send(JSON.stringify({ text: input_message.value }))
  input_message.value = ''
}

// 确定支付
function playBtn() {
  // 客户确认支付
  axios({
    method: 'put',
    url: `/api/orders/${orderId}/`,
    data: { status: 'paid' },
  })
    .then((res) => ElMessage.success('支付成功'))
    .catch((error) => ElMessage.error('支付失败'))
}

// 去评价
function reviewBtn() {
  router.push(`/client/review/${orderId}`)
}
</script>

<style lang="scss" scoped>
.order_detail {
  display: flex;
  flex-direction: column;
  gap: 20px;
  .back_row {
    display: flex;
    .btn_back {
      padding: 6px 16px;
      border: 1px solid #e2e8f0;
      border-radius: 6px;
      background: #ffffff;
      font-size: 13px;
      color: #1e293b;
    }
  }
  .detail_grid {
    display: flex;
    gap: 20px;
    .main_section {
      flex-grow: 3;
      display: flex;
      flex-direction: column;
      gap: 20px;
      .detail_card {
        background: #ffffff;
        border: 1px solid #e2e8f0;
        border-radius: 12px;
        padding: 24px;
        .detail_header {
          display: flex;
          justify-content: space-between;
          align-items: flex-start;
          margin-bottom: 20px;
          .detail_id {
            font-size: 12px;
            color: #94a3b8;
            margin-top: 4px;
            display: block;
          }
          .status_badge {
            padding: 4px 12px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 500;
          }
          .status_badge.in_progress {
            background: #eff6ff;
            color: #3b82f6;
          }
          .status_badge.paid {
            background: #ecfdf5;
            color: #059669;
          }
          .status_badge.pending {
            background: #e0e7ff;
            color: #4f46e5;
          }
          .status_badge.completed {
            background: #fef3c7;
            color: #d97706;
          }
          .status_badge.reviewed {
            background: #ecfdf5;
            color: #059669;
          }
          .status_badge.cancelled {
            background: #fef2f2;
            color: #dc2626;
          }
        }
        .info_grid {
          display: flex;
          gap: 16px;
          .info_item {
            flex-grow: 1;
            display: flex;
            flex-direction: column;
            gap: 4px;
            .label {
              font-size: 12px;
              color: #94a3b8;
            }
            .value {
              font-size: 14px;
              font-weight: 500;
            }
            .value.amount {
              color: #3b82f6;
              font-size: 18px;
              font-weight: 700;
            }
          }
        }
      }
      .progress_section {
        background: #ffffff;
        border: 1px solid #e2e8f0;
        border-radius: 12px;
        padding: 24px;
        h3 {
          font-size: 16px;
          font-weight: 600;
          margin-bottom: 16px;
        }
        .progress_bar_large {
          height: 8px;
          background: #e2e8f0;
          border-radius: 4px;
          overflow: hidden;
          .progress_fill {
            height: 100%;
            background: #3b82f6;
            border-radius: 4px;
            transition: width 0.5s;
          }
        }
        .progress_steps {
          display: flex;
          justify-content: space-between;
          margin-top: 12px;
          .step {
            display: flex;
            align-items: center;
            gap: 4px;
            font-size: 12px;
            color: #94a3b8;
          }
        }
      }
      .review-section {
        background: #ffffff;
        border: 1px solid #e2e8f0;
        border-radius: 12px;
        padding: 24px;
        h3 {
          font-size: 16px;
          font-weight: 600;
          margin-bottom: 16px;
        }
        .review-card-inner {
          display: flex;
          flex-direction: column;
          gap: 12px;
          .review-stars {
            display: flex;
            align-items: center;
            gap: 4px;
            .review-score {
              font-size: 14px;
              font-weight: 600;
              color: #f59e0b;
              margin-left: 8px;
            }
          }
          .review-tags {
            display: flex;
            flex-wrap: wrap;
            gap: 6px;
            .review-tag {
              padding: 3px 10px;
              background: #eff6ff;
              color: #3b82f6;
              border-radius: 12px;
              font-size: 12px;
            }
          }
          .review-comment {
            font-size: 14px;
            line-height: 1.6;
            color: var(--text-primary);
            margin: 0;
          }
        }
      }

      .message_section {
        background: #ffffff;
        border: 1px solid #e2e8f0;
        border-radius: 12px;
        padding: 24px;
        h3 {
          font-size: 16px;
          font-weight: 600;
          margin-bottom: 16px;
        }
        .message_list {
          display: flex;
          flex-direction: column;
          gap: 16px;
          max-height: 300px;
          overflow-y: auto;
          padding-bottom: 8px;
          .message_item.provider {
            flex-direction: row-reverse;
            .msg-text {
              background: #eff6ff;
            }
          }

          .message_item {
            display: flex;
            gap: 10px;
            .msg_avatar {
              width: 32px;
              height: 32px;
              border-radius: 50%;
              background: #3b82f6;
              flex-shrink: 0;
              overflow: hidden;
            }
            .msg_content {
              display: flex;
              flex-direction: column;
              gap: 2px;
              max-width: 70%;
              .msg_name {
                font-size: 12px;
                color: #94a3b8;
              }
              .msg_text {
                font-size: 14px;
                background: #f8fafc;
                padding: 8px 12px;
                border-radius: 8px;
                line-height: 1.5;
              }
            }
          }
        }
        .message_input {
          display: flex;
          gap: 8px;
          margin-top: 12px;
          input {
            flex: 1;
            height: 40px;
            padding: 0 12px;
            border: 1px solid #e2e8f0;
            border-radius: 8px;
            font-size: 14px;
            background: #f8fafc;
          }
          .btn_send {
            padding: 0 20px;
            background: #3b82f6;
            color: #fff;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 500;
          }
        }
      }
    }
    .side_section {
      flex-grow: 1;
      display: flex;
      flex-direction: column;
      gap: 20px;
      .payment_card,
      .actions_card {
        background: #ffffff;
        border: 1px solid #e2e8f0;
        border-radius: 12px;
        padding: 20px;
        h3 {
          font-size: 15px;
          font-weight: 600;
          margin-bottom: 16px;
        }
        .payment_info {
          display: flex;
          flex-direction: column;
          gap: 12px;
          margin-bottom: 16px;
          .pay_row {
            display: flex;
            justify-content: space-between;
            font-size: 14px;
            .unpaid {
              color: #d97706;
              font-weight: 500;
            }
          }
        }
        .btn_pay {
          width: 100%;
          height: 44px;
          background: #3b82f6;
          color: #fff;
          border-radius: 8px;
          font-size: 15px;
          font-weight: 600;
        }
        .btn_review {
          width: 100%;
          height: 44px;
          background: #059669;
          color: #fff;
          border-radius: 8px;
          font-size: 15px;
          font-weight: 600;
          margin-top: 8px;
        }
      }
    }
  }
}
</style>
