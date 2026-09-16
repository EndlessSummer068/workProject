<template>
  <div class="hall_detail">
    <div class="back_row">
      <button class="btn_back" @click="router.back()">返回</button>
    </div>
    <div class="detail_card">
      <div class="detail_header">
        <div>
          <span class="type_badge">{{ need_detail.type }}</span>
          <h2>{{ need_detail.title }}</h2>
        </div>
        <span :class="['status_badge', need_detail.status]">{{
          title_status_obj[need_detail.status]
        }}</span>
      </div>
      <div class="info_grid">
        <div class="info_item">
          <span class="label">预算</span><span class="value amount">¥{{ need_detail.budget }}</span>
        </div>
        <div class="info_item">
          <span class="label">类型</span><span class="value">{{ need_detail.type }}</span>
        </div>
      </div>
    </div>
    <div class="desc_card">
      <h3>需求描述</h3>
      <p class="desc_text">
        {{ need_detail.description === '' ? '无需求描述' : need_detail.description }}
      </p>
    </div>
    <div class="attachment_card">
      <h3>需求附件</h3>
      <a
        v-if="need_detail.attachment"
        :href="need_detail.attachment"
        target="_blank"
        class="attachment_link"
      >
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
          class="lucide lucide-paperclip-icon lucide-paperclip"
          aria-hidden="true"
        >
          <path
            d="m16 6-8.414 8.586a2 2 0 0 0 2.829 2.829l8.414-8.586a4 4 0 1 0-5.657-5.657l-8.379 8.551a6 6 0 1 0 8.485 8.485l8.379-8.551"
          ></path>
        </svg>
        {{ fileName }}
      </a>
      <span v-else class="info">无附件</span>
    </div>
    <div class="action_bar">
      <button class="btn_accept" @click="Accept">接单</button>
    </div>
  </div>
</template>

<script setup>
import router from '@/router'
import axios from 'axios'
import { ElMessage, ElMessageBox } from 'element-plus'
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'

// 需求id
let need_id = useRoute().params.id
// 需求详情
let need_detail = ref({})
// 附件名
let fileName = computed(() => {
  if (need_detail.value.attachment) {
    let ls = need_detail.value.attachment.split('/')
    // decodeURIComponent() 对文件名进行解码
    return decodeURIComponent(ls[ls.length - 1])
  }
  return ''
})
// 标题状态映射
let title_status_obj = ref({
  pending: '待接单',
  in_progress: '进行中',
  completed: '待客户支付',
  paid: '待客户评价',
  reviewed: '已完成',
  cancelled: '已取消',
})
// 接单按钮
let Accept = () => {
  ElMessageBox.confirm('确认接单后订单状态将修改为进行中', '是否确定接单？', {
    confirmButtonText: '确定',
    cancelButtonText: '取消',
    type: 'warning',
  })
    .then(() => {
      axios({
        method: 'post',
        url: `/api/needs/${need_id}/accept/`,
      })
        .then(() => {
          ElMessage.success('接单成功请去往【我的订单】查看')
          router.push('/provider/orders')
        })
        .catch(() => {
          ElMessage.error('接单失败')
        })
    })
    .catch(() => {
      ElMessage.info('已取消')
    })
}

onMounted(() => {
  axios({
    method: 'get',
    url: `/api/needs/${need_id}/`,
  })
    .then((res) => {
      need_detail.value = res.data
    })
    .catch((error) => ElMessage.error('加载数据失败'))
})
</script>

<style lang="scss" scoped>
.hall_detail {
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
      .type_badge {
        padding: 3px 10px;
        background: #eff6ff;
        color: #3b82f6;
        border-radius: 4px;
        font-size: 12px;
        font-weight: 500;
      }
      .status_badge {
        padding: 4px 14px;
        border-radius: 4px;
        font-size: 12px;
        font-weight: 500;
      }
      .status_badge.pending {
        background: #fef3c7;
        color: #d97706;
      }
    }
    .info_grid {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 16px;
      .info_item {
        display: flex;
        flex-direction: column;
        gap: 4px;
        .label {
          font-size: 12px;
          color: #94a3b8;
        }
        .value.amount {
          color: #3b82f6;
          font-size: 20px;
          font-weight: 700;
        }
        .value {
          font-size: 14px;
          font-weight: 500;
        }
      }
    }
  }
  .desc_card {
    background: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 12px;
    padding: 24px;
    h3 {
      font-size: 16px;
      font-weight: 600;
      margin-bottom: 12px;
    }
    .desc_text {
      font-size: 14px;
      line-height: 1.8;
      color: #64748b;
    }
  }
  .attachment_card {
    background: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 12px;
    padding: 24px;
    h3 {
      font-size: 16px;
      font-weight: 600;
      margin-bottom: 12px;
    }
    .attachment_link {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      font-size: 14px;
      color: #3b82f6;
      text-decoration: none;
      font-weight: 500;
      padding: 8px 16px;
      background: #eff6ff;
      border-radius: 8px;
    }
    .info {
      color: #666;
      font-size: 14px;
    }
  }
  .action_bar {
    display: flex;
    justify-content: center;
    .btn_accept {
      width: 240px;
      height: 48px;
      background: #3b82f6;
      color: #fff;
      border-radius: 10px;
      font-size: 16px;
      font-weight: 600;
      cursor: pointer;
      transition: opacity 0.2s;
    }
  }
}
</style>
