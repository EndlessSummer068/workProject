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
              data-v-41f1bf25=""
              xmlns="http://www.w3.org/2000/svg"
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              class="lucide lucide-clock-icon lucide-clock"
              aria-hidden="true"
              style="color: rgb(59, 130, 246)"
            >
              <circle cx="12" cy="12" r="10"></circle>
              <path d="M12 6v6l4 2"></path>
            </svg>
          </div>
        </div>
        <div class="stat_value">{{ in_progress_orders }}</div>
      </div>
      <div class="card">
        <div class="card_top">
          <span class="stat_label">已完成订单</span>
          <div class="stat_icon" style="background: rgb(236, 253, 245)">
            <svg
              data-v-41f1bf25=""
              xmlns="http://www.w3.org/2000/svg"
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              class="lucide lucide-circle-check-icon lucide-circle-check"
              aria-hidden="true"
              style="color: rgb(16, 185, 129)"
            >
              <circle cx="12" cy="12" r="10"></circle>
              <path d="m9 12 2 2 4-4"></path>
            </svg>
          </div>
        </div>
        <div class="stat_value">{{ completed_orders }}</div>
      </div>
      <div class="card">
        <div class="card_top">
          <span class="stat_label">累计收入</span>
          <div class="stat_icon" style="background: rgb(254, 243, 199)">
            <svg
              data-v-41f1bf25=""
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
        <div class="stat_value">￥{{ monthly_income }}</div>
      </div>
      <div class="card">
        <div class="card_top">
          <span class="stat_label">平均分</span>
          <div class="stat_icon" style="background: rgb(254, 242, 242)">
            <svg
              data-v-41f1bf25=""
              xmlns="http://www.w3.org/2000/svg"
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              class="lucide lucide-star-icon lucide-star"
              aria-hidden="true"
              style="color: rgb(239, 68, 68)"
            >
              <path
                d="M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z"
              ></path>
            </svg>
          </div>
        </div>
        <div class="stat_value">{{ avg_rating }}</div>
      </div>
    </div>
    <div class="order_card">
      <div class="recent_header">
        <h3>近期订单</h3>
        <a href="/client/orders" class="view_all">查看全部 →</a>
      </div>
      <div class="order_list">
        <div
          class="order_item"
          v-for="item in order_list"
          :key="item.id"
          @click="to_orderDetail(item.id)"
        >
          <div class="left">
            <span class="title">{{ item.need_title }}</span>
          </div>
          <div class="right">
            <span class="amount">¥{{ item.amount }}</span>
            <span :class="'status ' + item.status">{{
              item.status === 'pending'
                ? '待接单'
                : item.status === 'in_progress'
                  ? '进行中'
                  : item.status === 'completed'
                    ? '待客户支付'
                    : item.status === 'paid'
                      ? '待客户评价'
                      : item.status === 'reviewed'
                        ? '已完成'
                        : item.status === 'cancelled'
                          ? '已取消'
                          : ''
            }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import router from '@/router'
import axios from 'axios'
import { ElMessage } from 'element-plus'
import { onMounted, ref } from 'vue'

// 进行中
let in_progress_orders = ref(0)
// 已完成订单数
let completed_orders = ref(0)
// 累计收入
let monthly_income = ref(0)
// 平均分
let avg_rating = ref(0)
// 订单列表
let order_list = ref([])

onMounted(function () {
  // 加载工作台卡片数据
  axios({
    url: '/api/stats/',
    method: 'get',
  })
    .then(function (res) {
      console.log(res.data)
      // 加载卡片数据
      in_progress_orders.value = res.data.in_progress_orders
      completed_orders.value = res.data.completed_orders
      monthly_income.value = res.data.monthly_income
      avg_rating.value = res.data.avg_rating
    })
    .catch(() => ElMessage.error('获取数据失败'))

  // 加载近期订单数据
  axios({
    method: 'get',
    url: '/api/orders/',
  })
    .then(function (res) {
      // console.log(res.data)
      order_list.value = res.data
    })
    .catch(function (res) {
      ElMessage.error('获取订单失败')
    })
})

// 跳转订单详情
function to_orderDetail(id) {
  router.push(`/client/orderdetail/${id}`)
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
