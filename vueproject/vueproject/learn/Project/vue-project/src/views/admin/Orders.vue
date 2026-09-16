<template>
  <div class="orders">
    <div class="header">
      <div class="left">订单管理</div>
      <div class="right">
        <div class="search_box">
          <Search style="width: 16px" />
          <input placeholder="搜索订单..." v-model="search_data.input_value" />
        </div>
        <select class="select" v-model="search_data.select_value">
          <option value="">全部状态</option>
          <option value="pending">待接单</option>
          <option value="in_progress">进行中</option>
          <option value="completed">待客户支付</option>
          <option value="paid">待客户评价</option>
          <option value="reviewed">已完成</option>
          <option value="cancelled">已取消</option>
        </select>
      </div>
    </div>
    <div class="table_card">
      <table class="data_table">
        <thead>
          <tr>
            <th>订单号</th>
            <th>需求标题</th>
            <th>金额</th>
            <th>状态</th>
            <th>操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="item in orders_list">
            <td class="td_id">{{ item.id }}</td>
            <td>{{ item.title }}</td>
            <td class="td_amount">¥{{ item.amount }}</td>
            <td>
              <span :class="['status_badge', item.status]">
                {{ title_status[item.status] }}
              </span>
            </td>
            <td>
              <div class="action_btns">
                <button class="btn_action" @click="toOrderDetail(item.id)">详情</button>
                <button
                  v-if="
                    item.status !== 'pending' &&
                    item.status !== 'reviewed' &&
                    item.status !== 'cancelled'
                  "
                  class="btn_action success"
                  @click="setOrderStatus(item.id, 'reviewed')"
                >
                  完成
                </button>
                <button
                  v-if="
                    item.status !== 'pending' &&
                    item.status !== 'reviewed' &&
                    item.status !== 'cancelled'
                  "
                  class="btn_action danger"
                  @click="setOrderStatus(item.id, 'cancelled')"
                >
                  取消
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import router from '@/router'
import axios from 'axios'
import { ElMessage } from 'element-plus'
import { onMounted, ref, watch } from 'vue'

// 页面渲染用户数据
let orders_list = ref([])

// 获取最新的订单列表数据
function getOrderList() {
  axios({
    url: '/api/orders/',
    method: 'GET',
  })
    .then(function (res) {
      console.log(res.data)
      orders_list.value = res.data
    })
    .catch(function () {
      ElMessage.error('数据列表加载失败')
    })
}

onMounted(function () {
  getOrderList()
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

// 筛选数据
let search_data = ref({
  input_value: '',
  select_value: '',
})
watch(search_data.value, function () {
  axios({
    url: '/api/orders/',
    method: 'GET',
    params: {
      search: search_data.value.input_value,
      status: search_data.value.select_value,
    },
  })
    .then((res) => {
      // console.log(res.data)
      orders_list.value = res.data
    })
    .catch(() => {
      ElMessage.error('加载数据失败')
    })
})

// 点击跳转到订单详情页
function toOrderDetail(id) {
  router.push(`/admin/orders/${id}`)
}

// 点击完成
function setOrderStatus(id, status) {
  axios({
    url: `/api/orders/${id}/`,
    method: 'put',
    data: {
      status,
    },
  })
    .then((res) => {
      ElMessage.success('操作成功')
      // 加载最新的数据
      getOrderList()
    })
    .catch(() => {
      ElMessage.error('操作失败')
    })
}
</script>

<style lang="scss" scoped>
.orders {
  display: flex;
  flex-direction: column;
  gap: 20px;
  .header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    .left {
      font-size: 18px;
      font-weight: 600;
    }
    .right {
      display: flex;
      gap: 12px;
      .search_box {
        display: flex;
        align-items: center;
        gap: 8px;
        height: 36px;
        padding: 0 12px;
        border: 1px solid #e2e8f0;
        border-radius: 8px;
        background: #ffffff;
        input {
          border: none;
          background: transparent;
          font-size: 13px;
          width: 200px;
        }
      }
      .select {
        height: 36px;
        padding: 0 12px;
        border: 1px solid #e2e8f0;
        border-radius: 8px;
        background: #ffffff;
        font-size: 13px;
        cursor: pointer;
      }
    }
  }
  // 表格
  .table_card {
    background: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 12px;
    overflow: hidden;
    .data_table {
      width: 100%;
      border-collapse: collapse;
      th {
        text-align: left;
        padding: 14px 20px;
        font-size: 12px;
        font-weight: 600;
        color: #64748b;
        background: #f8fafc;
        border-bottom: 1px solid #e2e8f0;
      }
      td {
        padding: 14px 20px;
        font-size: 13px;
        border-bottom: 1px solid #e2e8f0;
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
        .td_amount {
          font-weight: 600;
        }
        .action_btns {
          display: flex;
          gap: 8px;
        }
        .btn_action {
          padding: 4px 12px;
          border: 1px solid #e2e8f0;
          border-radius: 4px;
          background: #ffffff;
          font-size: 12px;
          color: #64748b;
        }
        .btn_action:hover {
          border-color: #3b82f6;
          color: #3b82f6;
        }
        .btn_action.success:hover {
          border-color: #10b981;
          color: #10b981;
        }
        .btn_action.danger:hover {
          border-color: #ef4444;
          color: #ef4444;
        }
      }
      .td_id {
        color: #94a3b8;
        font-size: 12px;
      }
      .td_amount {
        font-weight: 600;
      }
    }
  }
}
</style>
