<template>
  <div class="home">
    <el-container>
      <el-header>
        <h1>秒杀商城</h1>
        <div class="header-right">
          <template v-if="userInfo.username">
            <span>欢迎，{{ userInfo.username }}</span>
            <el-button type="text" @click="$router.push('/orders')">我的订单</el-button>
            <el-button type="text" @click="handleLogout">退出登录</el-button>
          </template>
          <template v-else>
            <el-button type="text" @click="$router.push('/login')">登录</el-button>
          </template>
        </div>
      </el-header>

      <el-main>
        <!-- 秒杀区：抢购中 + 即将开始 -->
        <div v-if="activeList.length > 0" class="section">
          <h2 class="section-title">限时秒杀</h2>
          <el-row :gutter="16">
            <el-col :xs="24" :sm="12" :md="8" v-for="goods in activeList" :key="goods.id">
              <div class="goods-card seckill-active" :class="{ 'tag-ongoing-border': getSeckillStatus(goods).key === 'ongoing' }">
                <div class="card-status">
                  <span class="status-tag" :class="getSeckillStatus(goods).tagClass">
                    {{ getSeckillStatus(goods).text }}
                  </span>
                </div>

                <h3 class="card-title">{{ goods.name }}</h3>
                <p class="card-desc">{{ goods.description || '暂无描述' }}</p>

                <div v-if="getSeckillStatus(goods).key === 'ongoing'" class="countdown-box countdown-ongoing">
                  <i class="el-icon-time"></i>
                  <span>距结束</span>
                  <span class="countdown-num">{{ countdownMap[goods.id] || '00:00:00' }}</span>
                </div>
                <div v-else-if="getSeckillStatus(goods).key === 'not_started'" class="countdown-box countdown-wait">
                  <i class="el-icon-alarm-clock"></i>
                  <span>距开始</span>
                  <span class="countdown-num">{{ countdownMap[goods.id] || '00:00:00' }}</span>
                </div>

                <div class="card-price">
                  <span class="price-seckill">¥{{ goods.seckill_price }}</span>
                  <span class="price-origin">¥{{ goods.price }}</span>
                </div>

                <div class="card-stock">
                  <div class="stock-progress">
                    <div class="stock-progress-bar" :style="{ width: stockPercent(goods) + '%' }"></div>
                  </div>
                  <span class="stock-label">剩余{{ goods.seckill_stock }}件</span>
                </div>

                <el-button
                  :type="canSeckill(goods) ? 'danger' : 'info'"
                  :disabled="!canSeckill(goods)"
                  :loading="seckillLoading[goods.id]"
                  @click="handleSeckill(goods.id)"
                  class="card-btn"
                >
                  {{ canSeckill(goods) ? '立即秒杀' : getSeckillStatus(goods).btnText }}
                </el-button>
              </div>
            </el-col>
          </el-row>
        </div>

        <!-- 分割线 -->
        <el-divider v-if="activeList.length > 0 && otherList.length > 0">
          <span class="divider-text">其他商品</span>
        </el-divider>

        <!-- 其他区：普通商品 + 已结束 + 已售罄 -->
        <div v-if="otherList.length > 0" class="section">
          <el-row :gutter="16">
            <el-col :xs="24" :sm="12" :md="8" v-for="goods in otherList" :key="goods.id">
              <div class="goods-card">
                <div class="card-status">
                  <span v-if="goods.seckill_price" class="status-tag" :class="getSeckillStatus(goods).tagClass">
                    {{ getSeckillStatus(goods).text }}
                  </span>
                  <span v-else class="status-tag tag-normal">普通商品</span>
                </div>

                <h3 class="card-title">{{ goods.name }}</h3>
                <p class="card-desc">{{ goods.description || '暂无描述' }}</p>

                <div class="card-price">
                  <template v-if="goods.seckill_price">
                    <span class="price-seckill">¥{{ goods.seckill_price }}</span>
                    <span class="price-origin">¥{{ goods.price }}</span>
                  </template>
                  <template v-else>
                    <span class="price-normal">¥{{ goods.price }}</span>
                  </template>
                </div>

                <div class="card-stock">
                  <template v-if="goods.seckill_price">
                    <div class="stock-progress">
                      <div class="stock-progress-bar" :style="{ width: stockPercent(goods) + '%' }"></div>
                    </div>
                    <span class="stock-label">剩余{{ goods.seckill_stock }}件</span>
                  </template>
                  <template v-else>
                    <span class="stock-label">库存{{ goods.stock }}件</span>
                  </template>
                </div>

                <el-button
                  v-if="goods.seckill_price"
                  type="info"
                  disabled
                  class="card-btn"
                >
                  {{ getSeckillStatus(goods).btnText }}
                </el-button>
                <el-button v-else type="info" disabled plain class="card-btn">暂无秒杀</el-button>
              </div>
            </el-col>
          </el-row>
        </div>

        <el-empty v-if="goodsList.length === 0" description="暂无商品"></el-empty>
      </el-main>
    </el-container>
  </div>
</template>

<style scoped>
/* 顶栏 */
.el-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: linear-gradient(135deg, #e53935, #ff6f00);
  color: white;
  padding: 0 20px;
  height: 56px !important;
}
.el-header h1 { font-size: 20px; margin: 0; }
.header-right { display: flex; align-items: center; gap: 12px; }
.header-right span { color: white; font-size: 14px; }
.header-right .el-button { color: white; }

/* 区域标题 */
.section { margin-bottom: 10px; }
.section-title { font-size: 20px; font-weight: 700; margin: 0 0 16px 0; color: #e53935; }
.divider-text { font-size: 14px; color: #9e9e9e; }

/* 秒杀区抢购中卡片带红边 */
.seckill-active.tag-ongoing-border { border: 2px solid #ffe0b2; }

/* 商品卡片 - 等高 */
.el-col { display: flex; }
.goods-card {
  background: #fff;
  border-radius: 12px;
  padding: 20px;
  margin-bottom: 16px;
  box-shadow: 0 2px 12px rgba(0,0,0,0.06);
  display: flex;
  flex-direction: column;
  gap: 10px;
  flex: 1;
  transition: transform 0.2s, box-shadow 0.2s;
}
.goods-card:hover { transform: translateY(-2px); box-shadow: 0 6px 20px rgba(0,0,0,0.1); }

/* 按钮撑到底部 */
.card-btn { margin-top: auto; width: 100%; font-size: 15px; font-weight: 600; letter-spacing: 2px; border-radius: 8px; height: 40px; }

/* 状态标签 */
.card-status { display: flex; align-items: center; }
.status-tag { display: inline-block; padding: 3px 10px; border-radius: 4px; font-size: 12px; font-weight: 600; color: #fff; line-height: 1.5; }
.tag-ongoing { background: linear-gradient(135deg, #e53935, #ff6f00); }
.tag-soon { background: linear-gradient(135deg, #ff9800, #ffc107); color: #fff; }
.tag-ended { background: #546e7a; color: #fff; }
.tag-sold-out { background: #e53935; }
.tag-normal { background: #43a047; }

/* 标题 */
.card-title { font-size: 16px; font-weight: 700; margin: 0; color: #212121; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.card-desc { font-size: 13px; color: #9e9e9e; margin: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

/* 倒计时 */
.countdown-box { display: flex; align-items: center; gap: 6px; padding: 6px 10px; border-radius: 6px; font-size: 13px; }
.countdown-ongoing { background: #fbe9e7; color: #d84315; }
.countdown-wait { background: #fff8e1; color: #f57f17; }
.countdown-num { font-weight: 700; font-size: 18px; font-family: 'Courier New', Consolas, monospace; letter-spacing: 1px; }

/* 价格 */
.card-price { display: flex; align-items: baseline; gap: 8px; }
.price-seckill { font-size: 22px; font-weight: 800; color: #e53935; }
.price-origin { font-size: 13px; color: #bdbdbd; text-decoration: line-through; }
.price-normal { font-size: 20px; font-weight: 700; color: #424242; }

/* 库存 */
.card-stock { display: flex; align-items: center; gap: 8px; }
.stock-progress { flex: 1; height: 6px; background: #f5f5f5; border-radius: 3px; overflow: hidden; }
.stock-progress-bar { height: 100%; background: linear-gradient(90deg, #e53935, #ff6f00); border-radius: 3px; transition: width 0.3s; }
.stock-label { font-size: 12px; color: #9e9e9e; white-space: nowrap; }
</style>

<script>
import request from '@/utils/request'

export default {
  name: 'HomeView',
  data() {
    return {
      userInfo: {},         // 当前登录的用户信息
      goodsList: [],        // 商品列表 
      countdownMap: {},     // 每个商品的倒计时文字
      seckillLoading: {},   // 每个商品的秒杀按钮 loading 状态
      timer: null           // 定时器引用 
    }
  },
  // 生命周期钩子方法
  // 组件创建时获取用户信息和商品列表
  async created() {
    await this.getUserInfo()
    await this.getGoodsList()
    this.startCountdown()
  }, 
  // 组件销毁时清除定时器，不然它会持续运行，导致内存泄漏
  beforeDestroy() {
    if (this.timer) clearInterval(this.timer) 
  },
  methods: {
    // 获取当前登录用户信息（未登录时跳过）
    async getUserInfo() {
      const token = localStorage.getItem('token')
      if (!token) return   // 未登录,跳过
      try {
        const res = await request.get('/users/me')
        this.userInfo = res.data
      } catch (error) {
        // token 过期或无效，清除本地存储
        localStorage.removeItem('token')
      }
    },
    // 获取商品列表, 并按状态排序
    async getGoodsList() {
      console.log('>>> 正在请求商品列表...') // 如果控制台打印了这行，说明函数被执行了
      try {
        const res = await request.get('/goods/list')
        console.log('>>> 后端返回的完整数据:', res) // 看看打印出来的 res 到底是什么！
        // 排序：抢购中 > 即将开始 > 普通商品 > 已结束 > 已售罄
        const statusOrder = { 'ongoing': 0, 'not_started': 1, 'normal': 2, 'ended': 3, 'sold_out': 4 }
        this.goodsList = (res.data || []).sort((a, b) => {
          // 先算出每个商品的状态 key 没有秒杀价格的默认普通商品
          const sa = a.seckill_price ? this.getSeckillStatus(a).key : 'normal'
          const sb = b.seckill_price ? this.getSeckillStatus(b).key : 'normal'
          // ?? 9 是兜底 万一查询不到就排序最后
          return (statusOrder[sa] ?? 9) - (statusOrder[sb] ?? 9)
        })
      } catch (error) {
        this.$message.error('获取商品列表失败，请稍后重试')
      }
    },
    // 退出登录
    handleLogout() {
      localStorage.removeItem('token')
      this.$router.push('/Login')
    },
    // 判断秒杀状态，返回 { key, text, tagClass, btnText }
    getSeckillStatus(goods) {
      const now = new Date()
      const start = goods.seckill_start ? new Date(goods.seckill_start) : null
      const end = goods.seckill_end ? new Date(goods.seckill_end) : null

      if (goods.seckill_stock <= 0) {
        return { key: 'sold_out', text: '已售罄', tagClass: 'tag-sold-out', btnText: '已售罄' }
      }
      if (start && now < start) {
        return { key: 'not_started', text: '即将开始', tagClass: 'tag-soon', btnText: '即将开始' }
      }
      if (end && now > end) {
        return { key: 'ended', text: '已结束', tagClass: 'tag-ended', btnText: '已结束' }
      }
      return { key: 'ongoing', text: '抢购中', tagClass: 'tag-ongoing', btnText: '立即秒杀' }
    },
    // 只有“抢购中”才能点
    canSeckill(goods) {
      return this.getSeckillStatus(goods).key === 'ongoing'
    },
    // 库存进度条百分比（最小 8% 最大 100%）
    stockPercent(goods) {
      if (!goods.seckill_price) return 0
      return Math.min(100, Math.max(8, (goods.seckill_stock / 10) * 100))     
    },
    // 把毫秒差值转成 HH:MM:SS 格式
    formatCountdown(diff) {
      if (diff <= 0) return '00:00:00'
      const h = Math.floor(diff / 3600000)
      const m = Math.floor((diff % 3600000) / 60000)
      const s = Math.floor((diff % 60000) / 1000)
      return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
    },
    // 启动倒计时定时器
    startCountdown() {
      this.updateCountdowns()
      this.timer = setInterval(() => {
        this.updateCountdowns()
      }, 1000)
    },
    // 每秒更新所有商品的倒计时
    updateCountdowns() {
      const now = new Date()
      this.goodsList.forEach(goods => {
        if (!goods.seckill_price) return
        const status = this.getSeckillStatus(goods)
        if (status.key === 'ongoing' && goods.seckill_end) {
          // 抢购中：显示距结束时间
          this.$set(this.countdownMap, goods.id, this.formatCountdown(new Date(goods.seckill_end) - now))
        } else if (status.key === 'not_started' && goods.seckill_start) {
          // 即将开始：显示距开始时间
          this.$set(this.countdownMap, goods.id, this.formatCountdown(new Date(goods.seckill_start) - now))
        }
      })
    },
     // 秒杀请求（未登录时跳转登录页）
    async handleSeckill(goodsId) {
      const token = localStorage.getItem('token')
      if (!token) {
        this.$message.warning('请先登录后再秒杀')
        this.$router.push('/login')
        return
      }
      this.$set(this.seckillLoading, goodsId, true)
      try {
        const res = await request.post(`/seckill/${goodsId}`)
        this.$message.success(res.data.message || '秒杀成功！')
        await this.getGoodsList()  // 刷新商品列表（库存会变）
      } catch (error) {
        this.$message.error(error.response?.data?.detail || '秒杀失败')
      } finally {
        this.$set(this.seckillLoading, goodsId, false)
      }
    },

  } ,
  computed: {
    // 秒杀区：只有 抢购中 + 即将开始
    activeList() {
      return this.goodsList.filter(g => {
        if (!g.seckill_price) return false
        const key = this.getSeckillStatus(g).key
        return key === 'ongoing' || key === 'not_started'
      })
    },
    // 其他区：普通商品 + 已结束 + 已售罄
    otherList() {
      return this.goodsList.filter(g => {
        if (!g.seckill_price) return true
        const key = this.getSeckillStatus(g).key
        return key !== 'ongoing' && key !== 'not_started'
      })
    }
  },
}

</script>

