<template>
  <div class="orders">
    <div class="page_header">
      <div class="tabs">
        <button
          :class="['tab', { active: header_select_index === 0 }]"
          @click="aclickcClasses(0, '')"
        >
          全部
        </button>
        <button
          :class="['tab', { active: header_select_index === 1 }]"
          @click="aclickcClasses(1, 'in_progress')"
        >
          进行中
        </button>
        <button
          :class="['tab', { active: header_select_index === 2 }]"
          @click="aclickcClasses(2, 'completed')"
        >
          待客户支付
        </button>
        <button
          :class="['tab', { active: header_select_index === 3 }]"
          @click="aclickcClasses(3, 'reviewed')"
        >
          已完成
        </button>
        <button
          :class="['tab', { active: header_select_index === 4 }]"
          @click="aclickcClasses(4, 'cancelled')"
        >
          已取消
        </button>
      </div>
    </div>
    <div class="orders_list">
      <div
        class="order_card"
        v-for="item in filterDataList"
        :key="item.id"
        @click="toDetail(item.id)"
      >
        <div class="order_body">
          <div class="order_left">
            <h3 class="order_title">{{ item.need_title }}</h3>
            <div class="order_meta">
              <span>{{ item.provider_name ? `服务方: ${item.provider_name}` : '暂无服务方' }}</span>
            </div>
          </div>
          <div class="order_right">
            <span :class="['status_badge', item.status]">{{
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
            }}</span
            ><span class="order_amount">￥{{ item.amount }}</span>
            <!--v-if-->
          </div>
        </div>
        <div class="order_bottom">
          <div class="progress_row">
            <span class="progress_label">进度</span>
            <div class="progress_bar">
              <div class="progress_fill" :style="{ width: item.progress + '%' }"></div>
            </div>
            <span class="progress_text">{{ item.progress }}%</span>
          </div>
        </div>
        <div class="order_arrow">
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
import { computed, onMounted, ref } from 'vue'

// 所有订单列表
let order_list = ref([])

// 请求订单列表数据
onMounted(() => {
  axios({
    method: 'get',
    url: '/api/orders/',
  })
    .then((res) => {
      console.log(res.data)
      order_list.value = res.data
    })
    .catch((error) => ElMessage.error('请求数据失败'))
})

// 导航栏菜单激活索引
let header_select_index = ref(0)

// 跳转订单详情页
function toDetail(id) {
  router.push(`/provider/orders/${id}`)
}

// 过滤类型
let filter_type = ref('')

// 过滤后的订单列表
let filterDataList = computed(() => {
  if (filter_type.value === '') {
    return order_list.value
  }
  return order_list.value.filter((item) => {
    return item.status === filter_type.value
  })
})

// 点击筛选状态
function aclickcClasses(index, type) {
  header_select_index.value = index
  filter_type.value = type
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
        margin-top: 8px;
        .arrow {
          color: #94a3b8;
        }
      }
    }
  }
}
</style>
