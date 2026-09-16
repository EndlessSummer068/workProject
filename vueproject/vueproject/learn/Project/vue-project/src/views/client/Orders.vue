<template>
  <div class="orders">
    <div class="page_header">
      <div class="tabs">
        <button
          @click="typeSelectBtn(0, '')"
          :class="['tab', btn_active_index === 0 ? 'active' : '']"
        >
          全部
        </button>
        <button
          @click="typeSelectBtn(1, 'pending')"
          :class="['tab', btn_active_index === 1 ? 'active' : '']"
        >
          待接单
        </button>
        <button
          @click="typeSelectBtn(2, 'in_progress')"
          :class="['tab', btn_active_index === 2 ? 'active' : '']"
        >
          进行中
        </button>
        <button
          @click="typeSelectBtn(3, 'completed')"
          :class="['tab', btn_active_index === 3 ? 'active' : '']"
        >
          待客户支付
        </button>
        <button
          @click="typeSelectBtn(4, 'reviewed')"
          :class="['tab', btn_active_index === 4 ? 'active' : '']"
        >
          已完成
        </button>
        <button
          @click="typeSelectBtn(5, 'cancelled')"
          :class="['tab', btn_active_index === 5 ? 'active' : '']"
        >
          已取消
        </button>
      </div>
      <RouterLink to="/client/publish" class="btn_publish">+ 发布需求</RouterLink>
    </div>
    <div class="orders_list">
      <div class="order_card" v-for="item in filter_data_list" :key="item.id">
        <div class="order_body">
          <div class="order_left">
            <h3 class="order_title">{{ item.need_title }}</h3>
            <div class="order_meta">
              <span>服务方:{{ item.provider_name ? item.provider_name : '无' }}</span>
            </div>
          </div>
          <div class="order_right">
            <span :class="['status_badge', item.status]">{{ title_status[item.status] }}</span
            ><span class="order_amount">￥111</span>
            <!--v-if-->
          </div>
        </div>
        <div class="order_bottom">
          <div class="progress_row">
            <span class="progress_label">进度</span>
            <div class="progress_bar">
              <div class="progress_fill" :style="{ width: `${item.progress}%` }"></div>
            </div>
            <span class="progress_text">{{ item.progress }}%</span>
          </div>
        </div>
        <div class="order_arrow" @click="toOrderDetail(item.id)">
          <span class="arrow_text">详情</span>
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
            class="lucide arrow lucide_chevron_right_icon lucide_chevron_right arrow"
            aria-hidden="true"
          >
            <path d="m9 18 6-6-6-6"></path>
          </svg>
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

// 过滤后的订单数据
let filter_data_list = ref([])

// 总订单数据
let order_data_list = ref([])

onMounted(() => {
  axios({
    url: '/api/orders/',
    method: 'get',
  })
    .then((res) => {
      //console.log(res.data)
      order_data_list.value = res.data
      filter_data_list.value = res.data
    })
    .catch(() => {
      ElMessage.error('请求订单数据失败')
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

// 按钮当前的激活索引
let btn_active_index = ref(0)
// 筛选按钮点击事件
let typeSelectBtn = (index, status) => {
  btn_active_index.value = index
  // 果是'', 那么表示的是查看全部订单数据
  if (status === '') {
    filter_data_list.value = order_data_list.value
  } else {
    filter_data_list.value = order_data_list.value.filter((obj) => {
      return obj.status === status
    })
  }
}
// 跳转订单详情页
function toOrderDetail(id) {
  router.push(`/client/orders/${id}`)
}
</script>

<style lang="scss" scoped>
.orders {
  display: flex;
  flex-direction: column;
  gap: 20px;
  a {
    text-decoration: none;
    color: inherit;
  }
  .page_header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    .tabs {
      display: flex;
      gap: 4px;
      background: #ffffff;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      padding: 4px;
      flex-wrap: wrap;
      .tab.active {
        background: #3b82f6;
        color: #fff;
      }
      .tab {
        padding: 8px 16px;
        border-radius: 6px;
        font-size: 13px;
        font-weight: 500;
        background: transparent;
        color: #64748b;
        transition: all 0.2s;
      }
    }
    .btn_publish {
      height: 36px;
      padding: 0 16px;
      background: #3b82f6;
      color: #fff;
      border-radius: 8px;
      font-size: 14px;
      font-weight: 500;
      display: flex;
      align-items: center;
    }
  }
  .orders_list {
    display: flex;
    flex-direction: column;
    gap: 12px;
    .order_card {
      background: #ffffff;
      border: 1px solid #e2e8f0;
      border-radius: 12px;
      padding: 20px 24px;
      cursor: pointer;
      transition: box-shadow 0.2s;
      .order_body {
        display: flex;
        justify-content: space-between;
        align-items: center;
        gap: 24px;
        .order_left {
          flex: 1;
          min-width: 0;
          .order_title {
            font-size: 16px;
            font-weight: 600;
            margin: 0;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
          }
          .order_meta {
            display: flex;
            gap: 16px;
            font-size: 12px;
            color: #94a3b8;
            margin-top: 6px;
            flex-wrap: wrap;
          }
        }
        .order_right {
          display: flex;
          align-items: center;
          gap: 16px;
          flex-shrink: 0;
          .status_badge {
            padding: 4px 14px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 500;
            min-width: 64px;
            text-align: center;
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
          .order_amount {
            font-size: 18px;
            font-weight: 700;
            color: #1e293b;
            white-space: nowrap;
          }
        }
      }
      .order_bottom {
        margin-top: 12px;
        padding-top: 12px;
        border-top: 1px solid #e2e8f0;
        .progress_row {
          display: flex;
          align-items: center;
          gap: 10px;
          .progress_label {
            font-size: 12px;
            color: #94a3b8;
          }
          .progress_bar {
            flex: 1;
            height: 6px;
            background: #e2e8f0;
            border-radius: 3px;
            overflow: hidden;
            max-width: 400px;
            .progress_fill {
              height: 100%;
              background: #3b82f6;
              border-radius: 3px;
              transition: width 0.3s;
            }
            .progress_text {
              font-size: 12px;
              color: #3b82f6;
              font-weight: 500;
            }
          }
        }
      }
      .order_arrow {
        display: flex;
        justify-content: flex-end;
        margin-top: 5px;
        .arrow {
          margin-right: 4px;
          color: #94a3b8;
        }
        .arrow_text {
          font-size: 12px;
          color: #78a4e2;
        }
      }
    }
  }
}
</style>
