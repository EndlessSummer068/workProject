<template>
  <div class="publish">
    <h2 class="form_title">填写需求信息</h2>
    <div class="form_row">
      <div class="form_group">
        <label>需求标题</label><input placeholder="例如：企业官网UI设计" v-model="need_title" />
      </div>
      <div class="form_group">
        <label>服务类型</label>
        <select v-model="need_type">
          <option value="">请选择服务类型</option>
          <option value="UI/UX设计">UI/UX设计</option>
          <option value="网站开发">网站开发</option>
          <option value="移动端开发">移动端开发</option>
          <option value="品牌设计">品牌设计</option>
          <option value="文案策划">文案策划</option>
          <option value="视频制作">视频制作</option>
          <option value="SEO优化">SEO优化</option>
          <option value="数据分析">数据分析</option>
        </select>
      </div>
    </div>
    <div class="form_group">
      <label>需求描述</label
      ><textarea placeholder="请详细描述您的需求..." rows="5" v-model="need_info"></textarea>
    </div>
    <div class="form_group">
      <label>预算金额</label><input type="number" placeholder="例如:5000" v-model="need_budget" />
    </div>
    <div class="form_group">
      <label>附件（可选）</label>
      <div class="upload_area" @click="upload">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="24"
          height="24"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="lucide lucide-upload-icon lucide-upload"
          aria-hidden="true"
        >
          <path d="M12 3v12"></path>
          <path d="m17 8-5-5-5 5"></path>
          <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
        </svg>
        <span>点击上传文件</span>
      </div>
      <input ref="inputFile" type="file" style="display: none" @change="fileChange($event)" />
      <p class="file_name">{{ file_obj ? file_obj.name : '未选择文件' }}</p>
    </div>
    <div class="form_actions">
      <button class="btn_submit" @click="submitForm">发布需求</button>
    </div>
  </div>
</template>

<script setup>
import axios from 'axios'
import { ref } from 'vue'
import { ElMessage } from 'element-plus'

// 需求标题
let need_title = ref('')
// 需求类型
let need_type = ref('')
// 需求描述
let need_info = ref('')
// 预算金额
let need_budget = ref('')
// input标签对象
let inputFile = ref(null)
// 文件对象
let file_obj = ref(null)

// 点击选择附件按钮
function upload() {
  // 通过click()方法激活input标签的上传事件
  inputFile.value.click()
}
// 文件选择完毕后的触发的事件
function fileChange(event) {
  file_obj.value = event.target.files[0]
}

// 发布需求按钮
function submitForm() {
  // 提交表单数据
  if (file_obj.value) {
    // 有附件
    const formData = new FormData()
    formData.append('title', need_title.value)
    formData.append('type', need_type.value)
    formData.append('description', need_info.value)
    formData.append('budget', need_budget.value)
    formData.append('attachment', file_obj.value)

    axios({
      url: '/api/needs/',
      method: 'post',
      data: formData,
      headers: { 'Content-Type': 'multipart/form-data' },
    })
      .then((res) => {
        ElMessage.success('发布成功')
        // 清空表单数据
        need_title.value = ''
        need_type.value = ''
        need_info.value = ''
        need_budget.value = ''
        file_obj.value = null
      })
      .catch((error) => ElMessage.error('发布失败'))
  } else {
    // 没有附件
    axios({
      method: 'post',
      url: '/api/needs/',
      data: {
        title: need_title.value,
        type: need_type.value,
        budget: need_budget.value,
        description: need_info.value,
      },
    })
      .then((res) => {
        ElMessage.success('发布成功')
        // 清空表单数据
        need_title.value = ''
        need_type.value = ''
        need_info.value = ''
        need_budget.value = ''
      })
      .catch((error) => ElMessage.error('发布失败'))
  }
}
</script>

<style lang="scss" scoped>
input,
select,
textarea {
  font-family: inherit;
  outline: none;
}

button {
  cursor: pointer;
  border: none;
  outline: none;
  font-family: inherit;
}
.publish {
  background: #ffffff;
  border: 1px solid #ffffff;
  border-radius: 12px;
  padding: 32px;
  display: flex;
  flex-direction: column;
  gap: 24px;
  .form_title {
    font-size: 20px;
    font-weight: 600;
  }
  .form_row {
    display: flex;
    gap: 20px;
  }
  .form_group {
    flex-grow: 1;
    display: flex;
    flex-direction: column;
    gap: 6px;
    label {
      font-size: 13px;
      font-weight: 500;
    }

    input,
    select,
    textarea {
      height: 40px;
      background: #f8fafc;
      border: 1px solid #e2e8f0;
      border-radius: 6px;
      padding: 0 12px;
      font-size: 14px;
      color: #1e293b;
      transition: border-color 0.2s;
    }

    textarea {
      height: auto;
      padding: 10px 12px;
      resize: vertical;
    }
    .upload_area {
      border: 2px dashed #e2e8f0;
      border-radius: 8px;
      padding: 32px;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 8px;
      color: #94a3b8;
      font-size: 14px;
      cursor: pointer;
      transition: border-color 0.2s;
    }
  }

  .file_name {
    font-size: 14px;
    color: #1e293b;
  }
  .form_actions {
    display: flex;
    justify-content: flex-end;
    gap: 12px;
    margin-top: 8px;
    .btn_submit {
      height: 40px;
      padding: 0 24px;
      border-radius: 8px;
      background: #3b82f6;
      color: #fff;
      font-size: 14px;
      font-weight: 500;
      transition: opacity 0.2s;
    }
  }
}
</style>
