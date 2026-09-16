<template>
  <div class="order_detail">
    <div class="back_row">
      <button @click="router.back()">返回</button>
    </div>
    <div class="detail_box">
      <div class="detail_card">
        <div class="detail_header">
          <div>
            <h2>订单</h2>
            <span class="detail_id">订单号：{{ order_detail.id }}</span>
          </div>
          <span :class="['status_badge', order_detail.status]"
            >{{ title_status[order_detail.status] }}
          </span>
        </div>
        <div class="info">
          <div class="info_item">
            <span class="label">客户</span><span class="value">{{ order_detail.client_name }}</span>
          </div>
          <div class="info_item">
            <span class="label">服务方</span>
            <span class="value">{{ order_detail.provider_name }}</span>
          </div>
          <div class="info_item">
            <span class="label">订单金额</span>
            <span class="value amount">¥{{ order_detail.amount }}</span>
          </div>
          <div class="info_item">
            <span class="label">当前进度</span>
            <span class="value">{{ order_detail.progress }}%</span>
          </div>
          <div class="info_item">
            <span class="label">支付状态</span>
            <span class="value paid"></span>
          </div>
        </div>
        <div class="attachment_section">
          <span class="label">需求附件</span
          ><a :href="order_detail.need_attachment_url" target="_blank" class="attachment_link"
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
              class="lucide lucide-paperclip-icon lucide-paperclip"
              aria-hidden="true"
            >
              <path
                d="m16 6-8.414 8.586a2 2 0 0 0 2.829 2.829l8.414-8.586a4 4 0 1 0-5.657-5.657l-8.379 8.551a6 6 0 1 0 8.485 8.485l8.379-8.551"
              ></path>
            </svg>
            下载附件</a
          >
        </div>
      </div>
    </div>
    <div class="progress_section">
      <h3>订单进度</h3>
      <div class="progress_bar_large">
        <div class="progress_fill" :style="{ width: order_detail.progress }"></div>
      </div>
      <div class="progress_label">{{ order_detail.progress }}%</div>
    </div>

    <div class="review_section" v-if="reviewsData.length >= 1">
      <h3>客户评价</h3>
      <div class="review_card_inner">
        <div class="review_stars">
          <Star style="width: 16px" color="#F59E0B" />
          <Star style="width: 16px" color="#F59E0B" />
          <Star style="width: 16px" color="#F59E0B" />
          <Star style="width: 16px" color="#F59E0B" />
          <span class="review_score">4.0 分</span>€
        </div>
        <div class="review_tags">
          <span class="review_tag">评价标签1</span>
          <span class="review_tag">评价标签2</span>
          <span class="review_tag">评价标签3</span>
        </div>
        <p class="review_comment">客户评价...</p>
      </div>
    </div>

    <div class="message_section">
      <h3>沟通记录</h3>
      <div class="message_list" v-if="message_list.length >= 1">
        <div
          :class="['message_item', item.sender_role === 'provider' ? 'provider' : '']"
          v-for="item in message_list"
        >
          <div class="msg_avatar">
            <img :src="item.sender_avatar" width="100%" height="100%" alt="" />
          </div>
          <div class="msg_content">
            <span class="msg_name">{{ item.sender_name }}</span>
            <span class="msg_text">{{ item.text }}</span>
          </div>
        </div>
      </div>
      <p class="empty_msg" v-else>暂无沟通记录</p>
    </div>
  </div>
</template>

<script setup>
import router from '@/router'
import axios from 'axios'
import { ElMessage } from 'element-plus'
import { onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'

// 拿到路由中传递的id
let orderId = useRoute().params.id

// 订单的详情数据
let order_detail = ref('')

// 订单的评价数据
let reviewsData = ref([])

// 消息列表
let message_list = ref([])

onMounted(() => {
  axios({
    url: `/api/orders/${orderId}`,
    method: 'GET',
  })
    .then((res) => {
      // console.log(res.data)
      order_detail.value = res.data
    })
    .catch(() => {
      ElMessage.error('加载数据失败')
    })

  // 获取订单的评价数据
  axios({
    url: '/api/reviews/',
    method: 'get',
    params: {
      order: parseInt(orderId),
    },
  }).then((res) => {
    reviewsData.value = res.data
  })
  // 获取消息列表
  axios({
    url: '/api/messages/',
    method: 'get',
    params: {
      order: orderId,
    },
  })
    .then((res) => {
      console.log(res.data)
      message_list.value = res.data
    })
    .catch(() => {
      ElMessage.error('加载消息列表失败')
    })
})
// 状态映射对象
let title_status = {
  pending: '待接单',
  in_progress: '进行中',
  completed: '待客户支付',
  paid: '待客户评价',
  reviewed: '已完成',
  cancelled: '已取消',
}
</script>

<style lang="scss" scoped>
.order_detail {
  display: flex;
  flex-direction: column;
  gap: 20px;
  .back_row {
    display: flex;
    button {
      padding: 6px 16px;
      border: 1px solid #e2e8f0;
      border-radius: 6px;
      background: #ffffff;
      font-size: 13px;
      color: #1e293b;
    }
  }

  .detail_box {
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
          padding: 4px 10px;
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
      .info {
        display: flex;
        gap: 16px;
        .info_item {
          width: 0px;
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
          .value.paid {
            color: #059669;
            font-weight: 600;
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
        .label {
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
        transition: width 0.3s;
      }
    }
    .progress_label {
      margin-top: 8px;
      font-size: 14px;
      font-weight: 600;
      color: #3b82f6;
    }
  }

  .review_section {
    background: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 12px;
    padding: 24px;
    h3 {
      font-size: 16px;
      font-weight: 600;
      margin-bottom: 16px;
    }
    .review_card_inner {
      display: flex;
      flex-direction: column;
      gap: 12px;
      .review_stars {
        display: flex;
        align-items: center;
        gap: 4px;
        .review_score {
          font-size: 14px;
          font-weight: 600;
          color: #f59e0b;
          margin-left: 8px;
        }
      }
      .review_tags {
        display: flex;
        flex-wrap: wrap;
        gap: 6px;
        .review_tag {
          padding: 3px 10px;
          background: #eff6ff;
          color: #3b82f6;
          border-radius: 12px;
          font-size: 12px;
        }
      }
      .review_comment {
        font-size: 14px;
        line-height: 1.6;
        color: #1e293b;
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

      .message_item {
        display: flex;
        gap: 10px;
        .msg_avatar {
          width: 32px;
          height: 32px;
          border-radius: 50%;
          background: #3b82f6;
          flex-shrink: 0;
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
      .message_item.provider {
        flex-direction: row-reverse;
      }
      .message_item.provider .msg_text {
        background: #eff6ff;
      }
    }
    .empty_msg {
      text-align: center;
      color: #94a3b8;
      font-size: 13px;
      padding: 20px 0;
    }
  }
}
</style>
