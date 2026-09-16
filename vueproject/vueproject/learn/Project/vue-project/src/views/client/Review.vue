<template>
  <div class="review-page">
    <div class="back-row">
      <button class="btn-back" @click="router.back()">返回</button>
    </div>
    <div class="review-card">
      <h2>评价服务</h2>
      <p class="review-sub">订单号：58</p>
      <div class="rating-section">
        <span class="rating-label">服务评分</span>
        <div class="stars">
          <Star
            @click="btnStar(1)"
            :style="{ width: '32px', color: starNum >= 1 ? '#f59e0b' : '#ccc' }"
          />
          <Star
            @click="btnStar(2)"
            :style="{ width: '32px', color: starNum >= 2 ? '#f59e0b' : '#ccc' }"
          />
          <Star
            @click="btnStar(3)"
            :style="{ width: '32px', color: starNum >= 3 ? '#f59e0b' : '#ccc' }"
          />
          <Star
            @click="btnStar(4)"
            :style="{ width: '32px', color: starNum >= 4 ? '#f59e0b' : '#ccc' }"
          />
          <Star
            @click="btnStar(5)"
            :style="{ width: '32px', color: starNum >= 5 ? '#f59e0b' : '#ccc' }"
          />
          <span class="rating-text">{{ star_level[starNum] }}</span>
        </div>
      </div>
      <div class="tags-section">
        <span class="tags-label">评价标签</span>
        <div class="tags">
          <!-- <button class="tag">质量优秀</button><button class="tag">交付准时</button
          ><button class="tag">沟通顺畅</button><button class="tag">态度友好</button
          ><button class="tag">专业能力强</button><button class="tag">性价比高</button> -->
          <button
            :class="['tag', value ? 'active' : '']"
            v-for="(value, key) in tag_status"
            @click="tag_status[key] = !value"
          >
            {{ key }}
          </button>
        </div>
      </div>
      <div class="comment-section">
        <span class="comment-label">评价内容</span
        ><textarea placeholder="请分享您的使用体验..." rows="4" v-model="comment"></textarea>
      </div>
      <div class="submit-row">
        <button class="btn-submit" :disabled="starNum ? false : true" @click="btnSubmit">
          提交评价
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import router from '@/router'
import axios from 'axios'
import { ElMessage } from 'element-plus'
import { computed, ref } from 'vue'
import { useRoute } from 'vue-router'

// 拿到路由信息对象
let route = useRoute()
let orderId = route.params.id

// 评分
let starNum = ref('')

// 评分等级
let star_level = ref({
  1: '非常差',
  2: '差',
  3: '一般',
  4: '好',
  5: '非常好',
})

// 点击评分
function btnStar(num) {
  starNum.value = num
}

// 评价标签
let tag_status = ref({
  质量优秀: false,
  交付准时: false,
  沟通顺畅: false,
  态度友好: false,
  专业能力强: false,
  性价比高: false,
})

// 评价内容
let comment = ref('')

// 提交评价
function btnSubmit() {
  // 收集选中的标签
  let ls = []
  for (const key in tag_status.value) {
    if (tag_status.value[key]) {
      ls.push(key)
    }
  }

  axios({
    method: 'post',
    url: '/api/reviews/',
    data: {
      order: orderId,
      rating: starNum.value,
      tags: ls.join(','),
      comment: comment.value,
    },
  })
    .then((res) => {
      ElMessage.success('评价成功')
      router.back()
    })
    .catch((error) => ElMessage.error('评价失败'))
}
</script>

<style lang="scss" scoped>
.review-page {
  display: flex;
  flex-direction: column;
  gap: 20px;
  .back-row {
    display: flex;
    .btn-back {
      padding: 6px 16px;
      border: 1px solid #e2e8f0;
      border-radius: 6px;
      background: #ffffff;
      font-size: 13px;
      color: #1e293b;
    }
  }
  .review-card {
    background: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 12px;
    padding: 32px;
    max-width: 640px;
    margin: 0 auto;
    width: 100%;
    h2 {
      font-size: 22px;
      font-weight: 600;
    }
    .review-sub {
      font-size: 13px;
      color: #94a3b8;
      margin-top: 4px;
      margin-bottom: 24px;
    }
    .rating-section {
      margin-bottom: 24px;
      .rating-label {
        font-size: 14px;
        font-weight: 500;
        display: block;
        margin-bottom: 12px;
      }
      .stars {
        display: flex;
        align-items: center;
        gap: 8px;
      }
      .rating-text {
        font-size: 14px;
        color: #f59e0b;
        margin-left: 8px;
        font-weight: 500;
      }
    }
    .tags-section {
      margin-bottom: 24px;
      .tags-label {
        font-size: 14px;
        font-weight: 500;
        display: block;
        margin-bottom: 12px;
      }
      .tags {
        display: flex;
        flex-wrap: wrap;
        gap: 8px;
        .tag {
          padding: 6px 16px;
          border: 1px solid #e2e8f0;
          border-radius: 20px;
          font-size: 13px;
          background: #ffffff;
          color: #64748b;
          transition: all 0.2s;
        }
        .tag.active {
          border-color: #3b82f6;
          color: #3b82f6;
          background: #eff6ff;
        }
      }
    }
    .comment-section {
      margin-bottom: 24px;
      .comment-label {
        font-size: 14px;
        font-weight: 500;
        display: block;
        margin-bottom: 8px;
      }
      textarea {
        width: 100%;
        background: #f8fafc;
        border: 1px solid #e2e8f0;
        border-radius: 8px;
        padding: 12px;
        font-size: 14px;
        color: #1e293b;
        resize: vertical;
        transition: border-color 0.2s;
      }
      textarea:focus {
        border-color: #3b82f6;
      }
    }
    .submit-row {
      display: flex;
      justify-content: flex-end;
    }
    .btn-submit:disabled {
      opacity: 0.5;
      cursor: not-allowed;
    }
    .btn-submit {
      padding: 10px 32px;
      background: #3b82f6;
      color: #fff;
      border-radius: 8px;
      font-size: 15px;
      font-weight: 600;
    }
  }
}
</style>
