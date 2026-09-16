<template>
  <div class="orders-page">
   <el-container>
      <el-header>
        <h1>我的订单</h1>
        <div class="header-right">
          <el-button type="text" @click="$router.push('/')">返回首页</el-button>
          <el-button type="text" @click="handleLogout">退出登录</el-button>
        </div>
      </el-header>
      <el-main>
        <div v-if="orderList.length > 0" class="order-list">
          <div class="order-card" v-for="order in orderList" :key="order.id">
            <div class="order-header">
              <span class="order-id">订单号：{{ order.order_no }}</span>
              <el-tag
                :type="statusTagType(order.status)"
                size="small"
                effect="dark"
              >
                {{ order.status_text }}
              </el-tag>
            </div>
            <div class="order-body">
              <div class="order-info">
                <span class="order-goods-name">{{ order.goods_name }}</span>
                <span class="order-price">¥{{ order.order_price }}</span>
              </div>
              <div class="order-time">{{ formatDate(order.created_at) }}</div>
            </div>
            <div class="order-footer" v-if="order.status === 0">
              <el-button
                type="primary"
                size="small"
                @click="handlePay(order.id)"
              >
                去支付
              </el-button>
              <el-button
                type="danger"
                size="small"
                plain
                @click="handleCancel(order.id)"
              >
                取消订单
              </el-button>
            </div>
          </div>
        </div>
        <el-empty v-if="orderList.length === 0" description="暂无订单"></el-empty>
      </el-main>
    </el-container>
  </div>
</template>

<style scoped>
/* 顶栏 - 跟首页一致 */
.el-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    background: linear-gradient(135deg, #e53935, #ff6f00);
    color: white;
    padding: 0 20px;
    height: 56px !important;
}
.el-header h1 {
    font-size: 20px;
    margin: 0;
}
.header-right {
    display: flex;
    align-items: center;
    gap: 12px;
}
.header-right .el-button {
    color: white;
}
/* 订单列表 */
.order-list {
    max-width: 800px;
    margin: 0 auto;
}
/* 订单卡片 */
.order-card {
    background: #fff;
    border-radius: 12px;
    margin-bottom: 12px;
    box-shadow: 0 2px 12px rgba(0,0,0,0.06);
    overflow: hidden;
    transition: box-shadow 0.2s;
}
.order-card:hover {
    box-shadow: 0 4px 16px rgba(0,0,0,0.1);
}
/* 卡片头部 */
.order-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px 16px;
    background: #fafafa;
    border-bottom: 1px solid #f0f0f0;
}
.order-id {
    font-size: 13px;
    color: #757575;
}
/* 卡片内容 */
.order-body {
    padding: 16px;
}
.order-info {
    display: flex;
    justify-content: space-between;
    align-items: center;
}
.order-goods-name {
    font-size: 16px;
    font-weight: 600;
    color: #212121;
    }
.order-price {
    font-size: 20px;
    font-weight: 800;
    color: #e53935;
}
.order-time {
    margin-top: 8px;
    font-size: 13px;
    color: #9e9e9e;
}
/* 卡片底部 */
.order-footer {
    padding: 8px 16px 12px;
    text-align: right;
    border-top: 1px solid #f5f5f5;
}
</style>

<script>
import request from '@/utils/request'

export default {
    name: 'OrdersView',
    data() {
        return {
            orderList: []
        }
    },
    async created() {
        await this.getOrders()
    },
    methods: {
        async getOrders() {
            try {
                const res = await request.get('/seckill/my-orders')
                this.orderList = res.data
            } catch (error) {
                this.$message.error('获取订单失败')
            }
        },
        statusTagType(status) {
            if (status === 0) return 'warning'
            if (status === 1) return 'success'
            return 'info'
        },
        formatDate(dateStr) {
            if (!dateStr) return ''
            const date = new Date(dateStr)
            return date.toLocaleString('zh-CN')
        },
        handleCancel(orderId) {
            this.$confirm('确定取消此订单？库存将自动归还。', '取消订单', {
                confirmButtonText: '确定取消',
                cancelButtonText: '再想想',
                type: 'warning'
            }).then(async () => {
                try {
                    await request.put(`/seckill/${orderId}/cancel`)
                    this.$message.success('订单已取消，库存已归还')
                    await this.getOrders()
                } catch (error) {
                    this.$message.error(error.response?.data?.detail || '取消订单失败')
                }
            }).catch(() => {})
        },
        handlePay() {
            localStorage.removeItem('token')
            this.$router.push('/login')
        }
    }
}

</script>