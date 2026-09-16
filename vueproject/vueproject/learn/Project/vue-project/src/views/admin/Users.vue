<template>
  <div class="users">
    <div class="header">
      <div class="left">用户管理</div>
      <div class="right">
        <div class="search_box">
          <Search style="width: 16px" />
          <input placeholder="搜索用户..." v-model="searchtValue.inputValue" />
        </div>
        <select class="select" v-model="searchtValue.selectValue">
          <option value="">全部角色</option>
          <option value="client">客户</option>
          <option value="provider">服务方</option>
        </select>
      </div>
    </div>
    <div class="table_card">
      <table>
        <thead>
          <tr>
            <th>用户ID</th>
            <th>用户名</th>
            <th>角色</th>
            <th>状态</th>
            <th>操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="item in users_list" :key="item.id">
            <td class="td-id">{{ item.id }}</td>
            <td>
              <div class="user_ell">
                <div class="user_avatar"></div>
                <span>{{ item.username }}</span>
              </div>
            </td>
            <td>
              <!--  :class="'role_badge ' + item.role"     -->
              <span :class="['role_badge ', item.role]">{{
                item.role === 'admin'
                  ? '管理员'
                  : item.role === 'client'
                    ? '客户'
                    : item.role === 'provider'
                      ? '服务方'
                      : ''
              }}</span>
            </td>
            <td>
              <span :class="['status_dot', item.is_active ? 'active' : 'disabled']"></span>
              {{ item.is_active ? '正常' : '已禁用' }}
            </td>
            <td>
              <span class="admin_locked" v-if="item.role === 'admin'">-</span>
              <div class="action_btns" v-else>
                <button class="btn_action" @click="btnAction(item.id, item.is_active)">
                  {{ item.is_active ? '禁用' : '启用' }}
                </button>
                <button class="btn_action danger" @click="btnDelete(item.id)">删除</button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import axios from 'axios'
import { ElMessage } from 'element-plus'
import { onMounted, ref, watch } from 'vue'

// 页面渲染用户数据
let users_list = ref([])

// 搜索框中与选择框中的值
let searchtValue = ref({
  inputValue: '',
  selectValue: '',
})
// 监听数据变化
watch(searchtValue.value, function () {
  // console.log(searchtValue.value);
  axios({
    method: 'get',
    url: '/api/users/',
    params: {
      seach: searchtValue.value.inputValue,
      role: searchtValue.value.selectValue,
    },
  })
    .then(function (res) {
      console.log(res.data)
      // 将匹配的用户列表更新到users.list
      users_list.value = res.data
    })
    .catch(function () {
      ElMessage.error('请求失败')
    })
})

// let obj123 = ref({
//   client: '客户',
//   admin: '管理员',
//   provider: '服务方',
// })

onMounted(function () {
  axios({
    url: '/api/users/',
    method: 'get',
  }).then(function (res) {
    console.log(res.data)
    users_list.value = res.data
  })
})

// 点击禁用的方法
function btnAction(id, is_active) {
  // console.log(id);
  axios({
    url: `/api/users/${id}/`,
    method: 'PUT',
    data: {
      is_active: !is_active,
    },
  })
    .then(function (res) {
      // console.log(res.data)
      ElMessage.success('操作成功')
      // 渲染最新数据
      axios({
        url: '/api/users/',
        method: 'get',
      }).then(function (res) {
        //console.log(res.data)
        users_list.value = res.data
      })
    })
    .catch(function () {
      ElMessage.error('禁用失败')
    })
}

// 删除事件
function btnDelete(id) {
  axios({
    url: `/api/users/${id}`,
    method: 'delete',
  })
    .then(function (res) {
      ElMessage.success('删除成功')
      // 渲染最新数据
      axios({
        url: '/api/users/',
        method: 'get',
      }).then(function (res) {
        //console.log(res.data)
        users_list.value = res.data
      })
    })
    .catch(function () {
      ElMessage.error('删除失败')
    })
}
</script>

<style lang="scss" scoped>
.users {
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
  // 用户列表
  .table_card {
    background: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 12px;
    overflow: hidden;
    table {
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
        .user_cell {
          display: flex;
          align-items: center;
          gap: 8px;
          .user_avatar {
            width: 28px;
            height: 28px;
            border-radius: 50%;
            background: #3b82f6;
            object-fit: cover;
          }
        }
        .role_badge {
          padding: 3px 10px;
          border-radius: 4px;
          font-size: 12px;
          font-weight: 500;
        }
        .role_badge.admin {
          background: #e0e7ff;
          color: #4f46e5;
        }
        .role_badge.client {
          background: #eff6ff;
          color: #3b82f6;
        }
        .role_badge.provider {
          background: #fef3c7;
          color: #d97706;
        }
        .status_dot {
          display: inline-block;
          width: 6px;
          height: 6px;
          border-radius: 50%;
          margin-right: 6px;
        }

        .status_dot.active {
          background: #10b981;
        }
        .status_dot.disabled {
          background: #ef4444;
        }
        .action_btns {
          display: flex;
          gap: 8px;
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
          .btn_action {
            padding: 4px 12px;
            border: 1px solid #e2e8f0;
            border-radius: 4px;
            background: #ffffff;
            font-size: 12px;
            color: #64748b;
          }
          .btn_action.danger:hover {
            border-color: #ef4444;
            color: #ef4444;
          }
        }
      }
    }
  }
}
</style>
