<template>
  <div class="hall">
    <div class="page_header">
      <h2>接单大厅</h2>
      <div class="filters">
        <select class="filter_select" v-model="select_type">
          <option value="">全部类型</option>
          <option value="UI/UX设计">UI/UX设计</option>
          <option value="网站开发">网站开发</option>
          <option value="移动端开发">移动端开发</option>
          <option value="品牌设计">品牌设计</option>
          <option value="文案策划">文案策划</option>
          <option value="视频制作">视频制作</option>
          <option value="SEO优化">SEO优化</option>
          <option value="数据分析">数据分析</option>
        </select>
        <select class="filter_select" v-model="select_sort">
          <option value="newest">最新发布</option>
          <option value="budget_high">预算最高</option>
          <option value="budget_low">预算最低</option>
        </select>
      </div>
    </div>
    <div class="needs_grid">
      <div class="need_card" v-for="item in filterOrderList">
        <div class="need_header">
          <span class="need_type_badge">{{ item.type }}</span>
        </div>
        <h3 class="need_title">{{ item.title }}</h3>
        <p class="need_desc">{{ item.description }}</p>
        <div class="need_footer">
          <span class="need_budget">预算：¥{{ item.budget }}</span
          ><span class="need_client">客户：{{ item.username }}</span>
        </div>
        <div class="need_actions">
          <button class="btn_detail" @click="toDetail(item.id)">查看详情</button>
          <el-button class="btn_accept" plain @click="Accept(item.id)">接单</el-button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import router from '@/router'
import axios from 'axios'
import { ElMessage, ElMessageBox } from 'element-plus'
import { computed, onMounted, ref } from 'vue'

// 原始订单列表数据
let order_list = ref([])

// 筛选类型
let select_type = ref('')
// 订单排序
let select_sort = ref('newest')
// 筛选后的订单列表
let filterOrderList = computed(() => {
  let ls = order_list.value.filter((item) => item)
  // 排序
  if (select_sort.value == 'budget_high') {
    // sort排序函数  a-b升序   b-a降序
    ls.sort((a, b) => {
      return b.budget - a.budget
    })
  } else if (select_sort.value == 'budget_low') {
    ls.sort((a, b) => {
      return a.budget - b.budget
    })
  }

  // 筛选类型
  if (select_type.value !== '') {
    return ls.filter((item) => item.type == select_type.value)
  } else {
    return ls
  }
})

// 只获取待接单的需求
function getOrders() {
  axios({
    method: 'get',
    url: '/api/needs/',
    params: { status: 'pending' },
  })
    .then((res) => {
      order_list.value = res.data
    })
    .catch((error) => console.error(error))
}

onMounted(() => {
  getOrders()
})

// 查看详情按钮
function toDetail(id) {
  router.push(`/provider/hall/${id}`)
}

// 接单按钮
const Accept = (id) => {
  ElMessageBox.confirm('确认接单后订单状态将修改为进行中', '是否确定接单？', {
    confirmButtonText: '确定',
    cancelButtonText: '取消',
    type: 'warning',
  })
    .then(() => {
      axios({
        method: 'post',
        url: `/api/needs/${id}/accept/`,
      })
        .then(() => {
          getOrders()
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
</script>

<style lang="scss" scoped>
.hall {
  display: flex;
  flex-direction: column;
  gap: 20px;
  .page_header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    .page_header h2 {
      font-size: 18px;
      font-weight: 600;
    }
    .filters {
      display: flex;
      gap: 12px;
      .filter_select {
        height: 36px;
        padding: 0 12px;
        border: 1px solid #e2e8f0;
        border-radius: 8px;
        background: #ffffff;
        font-size: 13px;
        color: #1e293b;
        cursor: pointer;
      }
    }
  }
  .needs_grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 16px;
    .need_card {
      background: #ffffff;
      border: 1px solid #e2e8f0;
      border-radius: 12px;
      padding: 20px;
      display: flex;
      flex-direction: column;
      gap: 12px;
      transition: box-shadow 0.2s;
      justify-content: space-between;
      .need_header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        .need_type_badge {
          padding: 3px 10px;
          background: #eff6ff;
          color: #3b82f6;
          border-radius: 4px;
          font-size: 12px;
          font-weight: 500;
        }
      }
      .need_title {
        font-size: 16px;
        font-weight: 600;
      }
      .need_desc {
        font-size: 13px;
        color: #64748b;
        line-height: 1.5;
        display: -webkit-box;
        -webkit-line-clamp: 2;
        -webkit-box-orient: vertical;
        overflow: hidden;
      }
      .need_footer {
        display: flex;
        gap: 16px;
        font-size: 13px;
        color: #64748b;
        .need_footer .need_budget {
          color: #3b82f6;
          font-weight: 600;
        }
        .need_footer .need_client {
          color: #94a3b8;
        }
      }
      .need_actions {
        display: flex;
        gap: 8px;
        margin-top: 4px;
        .btn_detail {
          flex: 1;
          height: 36px;
          border: 1px solid #e2e8f0;
          border-radius: 6px;
          background: #ffffff;
          font-size: 13px;
          color: #1e293b;
        }
        .btn_accept {
          flex: 1;
          height: 36px;
          background: #3b82f6;
          color: #fff;
          border-radius: 6px;
          font-size: 13px;
          font-weight: 500;
        }
      }
    }
  }
}
</style>
