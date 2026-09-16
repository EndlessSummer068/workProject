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
              <h2>{{ order_detail.title }}</h2>
              <span class="detail_id">{{ order_detail.id }}</span>
            </div>
            <span class="status_badge in_progress">{{
              title_status_obj[order_detail.status]
            }}</span>
          </div>
          <div class="info_grid">
            <div class="info_item">
              <span class="label">客户</span
              ><span class="value">{{ order_detail.client_name }}</span>
            </div>
            <div class="info_item">
              <span class="label">订单金额</span
              ><span class="value amount">¥{{ order_detail.amount }}</span>
            </div>
            <div class="info_item">
              <span class="label">当前进度</span
              ><span class="value">{{ order_detail.progress }}%</span>
            </div>
            <div class="info_item">
              <span class="label">支付状态</span
              ><span class="value unpaid">{{
                order_detail.status === 'paid' || order_detail.status === 'reviewed'
                  ? '已支付'
                  : '未支付'
              }}</span>
            </div>
          </div>
          <div class="attachment_section">
            <span class="label">需求附件</span>
            <a
              v-if="order_detail.need_attachment_url"
              :href="order_detail.need_attachment_url"
              target="_blank"
              class="attachment_link"
              ><svg
                xmlns="http://www.w3.org/2000/svg"
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="lucide lucide_paperclip_icon lucide_paperclip"
                aria-hidden="true"
              >
                <path
                  d="m16 6-8.414 8.586a2 2 0 0 0 2.829 2.829l8.414-8.586a4 4 0 1 0-5.657-5.657l-8.379 8.551a6 6 0 1 0 8.485 8.485l8.379-8.551"
                ></path>
              </svg>
              扶持.png</a
            >
            <span v-else style="font-size: 14px; color: #ccc">无附件</span>
          </div>
        </div>
        <div class="progress_section" v-if="order_detail.status == 'in_progress'">
          <h3>更新进度</h3>
          <div class="progress_control">
            <div class="progress_bar_large">
              <div class="progress_fill" :style="{ width: `${input_range_value}%` }"></div>
            </div>
            <div class="progress_slider">
              <input type="range" min="0" max="100" v-model="input_range_value" /><span
                >{{ input_range_value }}%</span
              >
            </div>
          </div>
        </div>
        <!--v-if-->
        <div class="review-section" v-if="reviews">
          <h3>我的评价</h3>
          <div class="review-card-inner">
            <div class="review-stars">
              <Star
                v-for="(itme, index) in 5"
                :data-a="index"
                :style="{ width: '32px', color: index < reviews.rating ? '#f59e0b' : '#ccc' }"
              />
              <span class="review-score">4.0 分</span>
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
              v-for="item in message_list"
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
      <div class="side_section" v-if="order_detail.status === 'in_progress'">
        <div class="actions_card">
          <h3>操作</h3>
          <button class="btn_action complete" @click="Accept">完成订单</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import router from '@/router'
import axios from 'axios'
import { ElMessage, ElMessageBox } from 'element-plus'
import { nextTick, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
// 需求id
let order_id = useRoute().params.id

// 消息列表
let message_list = ref('')

// 连接 WebSocket
const ws = new WebSocket(`ws://localhost:5173/ws/chat/${order_id}/`)
// 连接成功
ws.onopen = () => {
  console.log('WebSocket 已连接')
}

// 收到消息（实时推送）
ws.onmessage = (event) => {
  const msg = JSON.parse(event.data)
  message_list.value.push(msg)
  // DOM更新后滚动到底部
  nextTick(() => {
    messageWindow.value.scrollTop = messageWindow.value.scrollHeight
  })
}

// 发送消息
function sendMessage() {
  ws.send(JSON.stringify({ text: input_message.value }))
  input_message.value = ''
}
let messageWindow = ref(null)

// 需要发送的消息
let input_message = ref('')

// 订单详情
let order_detail = ref({})

// 自定义进度条值
let input_range_value = ref('')

// 标题状态映射
let title_status_obj = ref({
  pending: '待接单',
  in_progress: '进行中',
  completed: '待客户支付',
  paid: '待客户评价',
  reviewed: '已完成',
  cancelled: '已取消',
})

// 点击完成
let Accept = () => {
  ElMessageBox.confirm('确认提醒', '是否确定完成？', {
    confirmButtonText: '确定',
    cancelButtonText: '取消',
    type: 'warning',
  })
    .then(() => {
      axios({
        method: 'put',
        url: `/api/orders/${order_id}/`,
        data: { status: 'completed', progress: 100 },
      })
        .then(() => {
          ElMessage.success('订单状态已更新')
          // 实时刷新当前页面数据和页面
          router.go(0)
        })
        .catch(() => {
          ElMessage.error('订单状态更新失败')
        })
    })
    .catch(() => {
      ElMessage.info('已取消')
    })
}
// 评价数据
let reviews = ref('')
// 初始化
onMounted(() => {
  // 获取订单详情
  axios({
    method: 'get',
    url: `/api/orders/${order_id}/`,
  })
    .then((res) => {
      order_detail.value = res.data
    })
    .catch(() => ElMessage.error('加载数据失败'))

  // 获取消息列表
  axios({
    method: 'get',
    url: '/api/messages/',
    params: { order: order_id },
  })
    .then((res) => {
      message_list.value = res.data
      // DOM更新后滚动到底部
      nextTick(() => {
        messageWindow.value.scrollTop = messageWindow.value.scrollHeight
      })
    })
    .catch((error) => console.error(error))

  // 获取评价信息
  axios({
    method: 'get',
    url: '/api/reviews/',
    params: { order: order_id },
  })
    .then((res) => (reviews.value = res.data[0]))
    .catch((error) => console.error(error))
})
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
      background: #fff;
      font-size: 13px;
      color: var(--text-primary);
    }
  }
  .detail_grid {
    display: grid;
    grid-template-columns: 1fr 280px;
    gap: 20px;
    .main_section {
      display: flex;
      flex-direction: column;
      gap: 20px;
      .detail_card {
        background: #fff;
        border: 1px solid #e2e8f0;
        border-radius: 12px;
        padding: 24px;
        .detail_header {
          display: flex;
          justify-content: space-between;
          align-items: flex-start;
          margin-bottom: 20px;
          h2 {
            font-size: 22px;
            font-weight: 600;
          }
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
          display: grid;
          grid-template-columns: repeat(3, 1fr);
          gap: 16px;
          .info_item {
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
            .value.unpaid {
              color: #d97706;
            }
          }
        }
        .attachment_section {
          display: flex;
          align-items: center;
          gap: 8px;
          margin-top: 16px;
          padding-top: 16px;
          border-top: 1px solid #e2e8f0;
          .attachment_section .label {
            font-size: 12px;
            color: #94a3b8;
          }
          .attachment_link {
            display: flex;
            align-items: center;
            gap: 4px;
            font-size: 14px;
            color: #3b82f6;
            text-decoration: none;
            font-weight: 500;
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
        .progress_control {
          display: flex;
          flex-direction: column;
          gap: 12px;
          .progress_bar_large {
            height: 8px;
            background: #e2e8f0;
            border-radius: 4px;
            overflow: hidden;
            .progress_fill {
              height: 100%;
              background: #3b82f6;
              border-radius: 4px;
              transition: width 0.3s;
            }
          }
          .progress_slider {
            display: flex;
            align-items: center;
            gap: 12px;
            input[type='range'] {
              flex: 1;
              accent-color: #3b82f6;
            }
            span {
              font-size: 14px;
              font-weight: 600;
              color: #3b82f6;
              min-width: 40px;
            }
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
        background: #fff;
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
          input:focus {
            border-color: #3b82f6;
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
      display: flex;
      flex-direction: column;
      gap: 20px;
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
        .btn_action.complete {
          background: #10b981;
          color: #fff;
          border-color: #10b981;
        }
        .btn_action {
          width: 100%;
          height: 40px;
          border: 1px solid #e2e8f0;
          border-radius: 8px;
          background: #ffffff;
          font-size: 13px;
          color: #1e293b;
          margin-bottom: 8px;
        }
      }
    }
  }
}
</style>
