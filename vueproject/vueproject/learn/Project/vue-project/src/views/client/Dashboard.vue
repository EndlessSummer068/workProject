<template>
  <div class="dashboard">
    <div class="welcome">
      <h2 class="title">欢迎回来</h2>
      <p class="title_info">这是您今天的业务概览</p>
    </div>
    <div class="stats_row">
      <div class="card">
        <div class="card_top">
          <span class="stat_label">进行中的订单</span>
          <div class="stat_icon" style="background: rgb(239, 246, 255)">
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
              class="lucide lucide-users-icon lucide-users"
              aria-hidden="true"
              style="color: rgb(59, 130, 246)"
            >
              <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"></path>
              <path d="M16 3.128a4 4 0 0 1 0 7.744"></path>
              <path d="M22 21v-2a4 4 0 0 0-3-3.87"></path>
              <circle cx="9" cy="7" r="4"></circle>
            </svg>
          </div>
        </div>
        <div class="stat_value">{{ user_data.in_progress_orders }}</div>
      </div>
      <div class="card">
        <div class="card_top">
          <span class="stat_label">待接单</span>
          <div class="stat-icon" style="background: rgb(236, 253, 245)">
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
              class="lucide lucide-clipboard-list-icon lucide-clipboard-list"
              aria-hidden="true"
              style="color: rgb(16, 185, 129)"
            >
              <rect width="8" height="4" x="8" y="2" rx="1" ry="1"></rect>
              <path
                d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"
              ></path>
              <path d="M12 11h4"></path>
              <path d="M12 16h4"></path>
              <path d="M8 11h.01"></path>
              <path d="M8 16h.01"></path>
            </svg>
          </div>
        </div>
        <div class="stat_value">{{ user_data.pending_needs }}</div>
      </div>
      <div class="card">
        <div class="card_top">
          <span class="stat_label">已完成订单</span>
          <div class="stat-icon" style="background: rgb(254, 243, 199)">
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
              class="lucide lucide-dollar-sign-icon lucide-dollar-sign"
              aria-hidden="true"
              style="color: rgb(217, 119, 6)"
            >
              <line x1="12" x2="12" y1="2" y2="22"></line>
              <path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"></path>
            </svg>
          </div>
        </div>
        <div class="stat_value">{{ user_data.completed_orders }}</div>
      </div>
      <div class="card">
        <div class="card_top">
          <span class="stat_label">总花费</span>
          <div class="stat-icon" style="background: rgb(254, 242, 242)">
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
              class="lucide lucide-trending-up-icon lucide-trending-up"
              aria-hidden="true"
              style="color: rgb(239, 68, 68)"
            >
              <path d="M16 7h6v6"></path>
              <path d="m22 7-8.5 8.5-5-5L2 17"></path>
            </svg>
          </div>
        </div>
        <div class="stat_value">￥{{ user_data.total_spent }}</div>
      </div>
    </div>
    <div class="order_card">
      <div class="recent_header">
        <h3>近期订单</h3>
        <a href="/client/orders" class="view_all">查看全部 →</a>
      </div>
      <div class="order_list">
        <div class="order_item" v-for="order in recent_orders" :key="order.id">
          <div class="left">
            <span class="title">{{ order.need_title }}</span>
          </div>
          <div class="right">
            <span class="amount">¥{{ order.amount }}</span>
            <span :class="['status', order.status]">{{ title_status[order.status] }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import axios from 'axios'
import { onMounted, ref } from 'vue'
// 仪表盘订单数据
let user_data = ref('')
// 最近订单数据
let recent_orders = ref('')

onMounted(() => {
  axios({
    method: 'get',
    url: '/api/stats',
  })
    .then((res) => {
      user_data.value = res.data
    })
    .catch((err) => {
      console.log(err)
    })

  // 获取最近订单
  axios({
    method: 'get',
    url: '/api/orders',
  })
    .then((res) => {
      recent_orders.value = res.data
    })
    .catch((err) => {
      console.log(err)
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
.dashboard {
  display: flex;
  flex-direction: column;
  gap: 24px;
  .welcome {
    .title {
      font-size: 22px;
      font-weight: 600;
    }
    .title_info {
      font-size: 14px;
      color: #64748b;
      margin-top: 4px;
    }
  }

  .stats_row {
    display: flex;
    gap: 16px;

    .card {
      background: #ffffff;
      border: 1px solid #e2e8f0;
      border-radius: 12px;
      padding: 20px;
      display: flex;
      flex-direction: column;
      gap: 4px;
      width: 0px;
      flex-grow: 1;
      .card_top {
        display: flex;
        justify-content: space-between;
        align-items: center;
        .stat_label {
          font-size: 13px;
          color: #64748b;
        }
        .stat_icon {
          width: 32px;
          height: 32px;
          border-radius: 8px;
          display: flex;
          align-items: center;
          justify-content: center;
        }
      }
      .stat_value {
        font-size: 28px;
        font-weight: 700;
      }
    }
  }

  .order_card {
    flex: 1;
    background: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 12px;
    overflow: hidden;
    .recent_header {
      padding: 16px 20px;
      border-bottom: 1px solid #e2e8f0;
      display: flex;
      justify-content: space-between;
      align-items: center;
      h3 {
        font-size: 15px;
        font-weight: 600;
      }
      a {
        font-size: 13px;
        color: #3b82f6;
        font-weight: 500;
      }
    }
    .order_list {
      padding: 8px 0;
      .order_item {
        padding: 12px 20px;
        display: flex;
        justify-content: space-between;
        align-items: center;
        cursor: pointer;
        transition: background 0.2s;
        .left {
          font-size: 14px;
          font-weight: 500;
        }
        .right {
          display: flex;
          align-items: center;
          width: 200px;
          justify-content: space-between;

          .amount {
            font-size: 14px;
            font-weight: 600;
          }
          .status {
            padding: 4px 10px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 500;
          }
          .status.in_progress {
            background: #eff6ff;
            color: #3b82f6;
          }
          .status.paid {
            background: #ecfdf5;
            color: #059669;
          }
          .status.pending {
            background: #e0e7ff;
            color: #4f46e5;
          }
          .status.completed {
            background: #fef3c7;
            color: #d97706;
          }
          .status.reviewed {
            background: #ecfdf5;
            color: #059669;
          }
          .status.cancelled {
            background: #fef2f2;
            color: #dc2626;
          }
        }
      }
      .order_item:hover {
        background: #f8fafc;
      }
    }
  }
}
</style>
