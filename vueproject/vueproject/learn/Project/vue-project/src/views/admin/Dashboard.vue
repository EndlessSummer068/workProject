<template>
  <div class="dashboard">
    <div class="welcome">
      <h2 class="title">管理后台概览</h2>
      <p class="title_info">平台运营数据一目了然</p>
    </div>
    <div class="stats_row">
      <div class="card">
        <div class="card_top">
          <span class="stat_label">总用户数</span>
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
        <div class="stat_value">{{ total_data.total_users }}</div>
      </div>
      <div class="card">
        <div class="card_top">
          <span class="stat_label">总订单数</span>
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
        <div class="stat_value">{{ total_data.total_orders }}</div>
      </div>
      <div class="card">
        <div class="card_top">
          <span class="stat_label">平台流水</span>
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
        <div class="stat_value">￥{{ total_data.total_revenue }}</div>
      </div>
      <div class="card">
        <div class="card_top">
          <span class="stat_label">已完成订单数</span>
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
        <div class="stat_value">{{ total_data.completed_orders }}</div>
      </div>
    </div>
    <div class="charts_grid">
      <div class="chart_card">
        <h3>需求类型分布</h3>
        <ECharts class="chart" :option="pieOption" />
      </div>
      <div class="chart_card">
        <h3>订单状态分布</h3>
        <ECharts class="chart" :option="statusPieOption" />
      </div>
    </div>
    <div class="chart_card">
      <h3>热门服务排行</h3>
      <ECharts class="chart" :option="barOption" />
    </div>
  </div>
</template>

<script setup>
import axios from 'axios'
import { ElMessage } from 'element-plus'
import { onMounted, ref } from 'vue'

let total_data = ref({})

// 需求类型分布图
let pieOption = ref({
  tooltip: {
    trigger: 'item',
  },
  legend: {
    top: '5%',
    right: 'right',
  },
  series: [
    {
      name: 'pieOption',
      type: 'pie',
      radius: ['40%', '70%'],
      avoidLabelOverlap: false,
      itemStyle: {
        borderRadius: 10,
        borderColor: '#fff',
        borderWidth: 2,
      },
      label: {
        show: false,
        position: 'center',
      },
      emphasis: {
        label: {
          show: true,
          fontSize: 40,
          fontWeight: 'bold',
        },
      },
      labelLine: {
        show: false,
      },
      data: [],
    },
  ],
})

// 订单状态分布图
let statusPieOption = ref({
  tooltip: {
    trigger: 'item',
  },
  legend: {
    top: '5%',
    right: 'right',
  },
  series: [
    {
      name: 'statusPieOption',
      type: 'pie',
      radius: ['40%', '70%'],
      avoidLabelOverlap: false,
      itemStyle: {
        borderRadius: 10,
        borderColor: '#fff',
        borderWidth: 2,
      },
      label: {
        show: false,
        position: 'center',
      },
      emphasis: {
        label: {
          show: true,
          fontSize: 40,
          fontWeight: 'bold',
        },
      },
      labelLine: {
        show: false,
      },
      data: [],
    },
  ],
})

// 排行图
let barOption = ref({
  tooltip: {
    trigger: 'axis',
    axisPointer: {
      type: 'shadow',
    },
  },
  grid: {
    top: '0%',
    left: '3%',
    right: '4%',
    bottom: '10%',
    containLabel: true,
  },
  xAxis: [
    {
      type: 'value',
    },
  ],
  yAxis: [
    {
      type: 'category',
      data: [],
      axisTick: {
        alignWithLabel: true,
      },
    },
  ],
  series: [
    {
      name: '数量',
      type: 'bar',
      barWidth: '60%',
      data: [],
    },
  ],
})

// 生命周期钩子   onMounted() 当页面加载完毕后自动触发
onMounted(function () {
  axios({
    url: '/api/stats/',
    method: 'get',
  })
    .then(function (res) {
      console.log(res.data)
      total_data.value = res.data
      // 设置 需求类型分布图 数据
      res.data.type_distribution.forEach(function (obj) {
        pieOption.value.series[0].data.push({
          // 转换格式
          name: obj.name,
          value: obj.count,
        })
      })

      // 设置 订单状态分布图 数据
      res.data.status_distribution.forEach(function (obj) {
        statusPieOption.value.series[0].data.push({
          // 转换格式
          name: obj.name,
          value: obj.count,
        })
      })

      // 设置 排行图 数据
      res.data.type_distribution.forEach(function (obj) {
        barOption.value.yAxis[0].data.splice(0, 0, obj.name)
        barOption.value.series[0].data.splice(0, 0, obj.count)
        // barOption.value.series[0].data.push({
        //   // 转换格式
        //   name: obj.name,
        //   value: obj.count,
        // })
      })

      console.log(pieOption.value.series[0].data)
    })
    .catch(function (err) {
      ElMessage.error('数据请求失败')
    })
})
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
  .charts_grid {
    display: flex;
    gap: 20px;
    .chart_card {
      // flex-grow: 1;
      width: 50%;
      background: #ffffff;
      border: 1px solid #e2e8f0;
      border-radius: 12px;
      overflow: hidden;
      height: 300px;
      padding: 24px;
      .chart {
        width: 100%;
        height: 300px;
      }
      h3 {
        font-size: 16px;
        font-weight: 600;
        margin-bottom: 20px;
      }
    }
  }
  .chart_card {
    // flex-grow: 1;
    background: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 12px;
    overflow: hidden;
    height: 300px;
    padding: 24px;
    .chart {
      width: 100%;
      height: 300px;
    }
    h3 {
      font-size: 16px;
      font-weight: 600;
      margin-bottom: 20px;
    }
  }
}
</style>
