# TaskFlow 接单平台 - 后端接口文档

## 一、项目概述

TaskFlow 是一个服务订单匹配平台，支持三种角色：

| 角色 | 值 | 说明 |
|------|------|------|
| 客户 | `client` | 发布需求、支付订单、评价服务 |
| 服务方 | `provider` | 浏览需求、接单、完成订单 |
| 管理员 | `admin` | 管理用户、管理订单、查看统计 |

### 什么是 API 接口？

后端提供了若干个 **API 接口**（URL 地址），前端通过向这些地址发送 **HTTP 请求** 来获取或提交数据。

- 每个接口有一个 **URL**，例如 `/api/auth/login/`
- 每个接口支持特定的 **HTTP 方法**：`GET`（获取数据）、`POST`（创建数据）、`PUT`（修改数据）、`DELETE`（删除数据）
- 请求和响应的数据格式都是 **JSON**

### 基础 URL

后端运行在 `http://localhost:8000`，所有接口以 `/api/` 开头。

但前端开发时不需要写完整的 `http://localhost:8000/api/...`，而是直接写 `/api/...`，因为 Vite 开发服务器会通过**代理**自动转发到后端（代理配置见文档最后）。

---

## 二、安装与配置 axios

### 什么是 axios？

axios 是一个流行的 HTTP 请求库，比浏览器原生的 `fetch` 更好用：
- 自动将响应数据解析为 JSON（不需要手动调用 `.json()`）
- 自动将请求对象序列化为 JSON（不需要手动 `JSON.stringify()`）
- 更好的错误处理（非 2xx 状态码会自动抛出错误）
- 支持请求/响应拦截器（统一添加配置）

### 安装步骤

```bash
# 在前端项目根目录下执行
npm install axios
```

安装完成后，在代码中导入使用：

```javascript
import axios from 'axios'
```

### 全局配置

在项目入口文件（如 `src/main.js`）中配置 axios 全局默认值：

```javascript
import { createApp } from 'vue'
import App from './App.vue'
import axios from 'axios'


axios.defaults.withCredentials = true

createApp(App).mount('#app')
```

> **说明**：
> 
> - `withCredentials: true`：**关键配置！** 让浏览器在每次请求时自动携带 Cookie。没有这个配置，Session 认证不会生效

---

## 三、认证机制

### 认证方式：Session + Cookie

本项目使用 **Session 认证**。简单来说：

1. 用户调用**登录接口**，传入用户名和密码
2. 后端验证通过后，会在响应头中返回一个 `Set-Cookie: sessionid=xxxx`
3. 浏览器会**自动保存**这个 Cookie
4. **之后的所有请求**，浏览器会**自动在请求头中携带**这个 Cookie
5. 后端通过这个 Cookie 识别"当前登录用户是谁"

### 前端需要做什么？

前端**不需要手动获取、存储或设置 Cookie**。浏览器会自动完成这一切。

但有一个**关键配置**必须做，否则浏览器不会自动携带 Cookie：

```javascript
// 全局配置（推荐，在入口文件设置一次即可）
import axios from 'axios'
axios.defaults.withCredentials = true  // ← 这一行是关键！

// 之后所有请求都会自动携带 Cookie
axios({
  method: 'get',
  url: '/api/orders/',
})
.then(res => console.log(res.data))
.catch(error => console.error(error))
```

> **如果没有配置 `withCredentials: true`**：浏览器不会发送 Cookie，后端无法识别用户身份，会返回 401 错误。

### 推荐的全局配置

在项目入口文件中配置 axios 全局默认值，之后所有请求都会自动应用这些配置：

```javascript
// src/main.js
import axios from 'axios'

axios.defaults.baseURL = '/api'
axios.defaults.withCredentials = true
axios.defaults.headers.post['Content-Type'] = 'application/json'

// 响应拦截器：统一处理 401 未登录
axios.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response && error.response.status === 401) {
      window.location.href = '/login'
    }
    return Promise.reject(error)
  }
)
```

使用方式：

```javascript
// GET 请求
axios({
  method: 'get',
  url: '/api/auth/me/',
})
.then(res => console.log(res.data))
.catch(error => console.error(error))

// POST 请求
axios({
  method: 'post',
  url: '/api/auth/login/',
  data: {
    username: 'testuser',
    password: '123456'
  },
})
.then(res => console.log(res.data))
.catch(error => console.error(error))

// PUT 请求
axios({
  method: 'put',
  url: '/api/orders/1/',
  data: { status: 'completed' },
})
.then(res => console.log(res.data))
.catch(error => console.error(error))
```

> **注意**：axios 的响应数据在 `response.data` 中，不是直接就是数据对象。所以获取用户信息应该用 `res.data`，而不是 `res`。

### 文件上传请求的特殊处理

当需要上传文件（如头像、附件）时，**不能使用 JSON 格式**，必须使用 `FormData`：

```javascript
// ✅ 文件上传的正确写法
const formData = new FormData()
formData.append('title', '需求标题')
formData.append('attachment', fileInput.files[0])  // 文件对象

axios({
  method: 'post',
  url: '/api/needs/',
  data: formData,
  headers: {
    'Content-Type': 'multipart/form-data',  // ← 上传文件时设置这个
  },
})
.then(res => console.log(res.data))
.catch(error => console.error(error))
```

> **常见错误**：
> 1. 文件上传时使用 `Content-Type: application/json` — 应该用 `multipart/form-data`
> 2. 上传文件时不使用 `FormData` 对象 — 必须用 `FormData`
> 3. 手动设置 `Content-Type: multipart/form-data; boundary=...` — 不要手动设置 boundary，浏览器会自动处理

---

## 四、通用响应格式

### HTTP 状态码说明

| 状态码 | 含义 | 说明 |
|--------|------|------|
| 200 | 成功 | GET 请求获取数据成功，PUT 请求修改成功 |
| 201 | 创建成功 | POST 请求创建数据成功 |
| 400 | 请求错误 | 参数验证失败（字段缺失、格式错误等） |
| 401 | 未授权 | 未登录或登录已过期 |
| 403 | 禁止访问 | 没有权限访问该资源 |
| 404 | 未找到 | 请求的资源不存在 |
| 500 | 服务器错误 | 后端代码出错 |

### 成功响应

HTTP 状态码为 200 或 201，返回 JSON 数据。具体格式见每个接口的说明。

### 错误响应

**业务错误**（如登录失败、密码错误）：

```json
{
  "success": false,
  "message": "错误描述信息"
}
```

**所有错误响应**的格式统一为：

```json
{
  "success": false,
  "message": "错误描述信息"
}
```

> **说明**：前端只需判断 `success` 是否为 `false`，然后读取 `message` 显示给用户即可。数据格式校验由前端完成，后端只返回第一条错误信息。

---

## 五、认证接口

### 5.1 注册

```
POST /api/auth/register/
```

**权限**：无需登录

**请求体**：

```json
{
  "username": "string, 必填, 用户名",
  "password": "string, 必填, 最少6位",
  "email": "string, 可选, 邮箱",
  "role": "string, 必填, 只能填 client 或 provider（不支持 admin）",
  "phone": "string, 可选, 手机号"
}
```

> **说明**：注册时不支持 `admin` 角色，如果传 `role: "admin"` 会返回 400 错误。注册成功后会自动登录（后端会设置 Session Cookie）。

**成功响应** (201)：

```json
{
  "success": true,
  "user": {
    "id": 1,
    "username": "testuser",
    "email": "",
    "role": "client",
    "phone": "",
    "avatar": null,
    "bio": "",
    "skills": "",
    "rating": 0.0,
    "completed_orders": 0,
    "is_active": true
  }
}
```

**user 对象字段说明**：

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | int | 用户ID，唯一标识 |
| `username` | string | 用户名 |
| `email` | string | 邮箱，可为空字符串 |
| `role` | string | 角色：`client`（客户）/ `provider`（服务方）/ `admin`（管理员） |
| `phone` | string | 手机号，可为空字符串 |
| `avatar` | string \| null | 头像URL，`null` 表示无头像；有头像时为 `/media/avatars/xxx.png` |
| `bio` | string | 个人简介，可为空字符串 |
| `skills` | string | 专业技能，可为空字符串 |
| `rating` | float | 评分（0-5），只读，前端不能修改 |
| `completed_orders` | int | 完成订单数，只读，前端不能修改 |
| `is_active` | bool | 账号是否启用，被管理员禁用后为 `false` |

> **说明**：`user` 对象在注册、登录、获取当前用户信息、用户列表等接口中都会返回，字段格式相同。

**失败响应** (400)：

用户名已存在时：
```json
{
  "success": false,
  "message": "已存在一位使用该名字的用户。"
}
```

其他验证失败时（如字段为空、密码不足6位、注册admin角色等），后端会返回对应的第一条错误信息：
```json
{
  "success": false,
  "message": "该字段不能为空。"
}
```

> **说明**：前端负责数据格式校验，后端只返回第一条错误信息。建议前端在提交前做好校验，如：用户名不能为空、密码至少6位、角色只能选client或provider。

**axios 示例**：

```javascript
axios({
  method: 'post',
  url: '/api/auth/register/',
  data: {
    username: 'newuser',
    password: '123456',
    role: 'client'
  },
})
.then(res => {
  // 注册成功，res.data = { success: true, user: {...} }
  const user = res.data.user
  // 根据 user.role 跳转到对应页面
})
.catch(error => {
  // 注册失败，error.response.data = { success: false, message: '已存在一位使用该名字的用户。' }
  const msg = error.response.data.message
  alert(msg)
})
```

> **前端处理建议**：注册成功后将 `user` 对象保存到全局状态（如 Pinia store），然后根据 `user.role` 跳转到对应页面（`client` → `/client/dashboard`，`provider` → `/provider/dashboard`）。

---

### 5.2 登录

```
POST /api/auth/login/
```

**权限**：无需登录

**请求体**：

```json
{
  "username": "string, 必填",
  "password": "string, 必填"
}
```

**成功响应** (200)：

```json
{
  "success": true,
  "user": {
    "id": 2,
    "username": "testclient",
    "email": "",
    "role": "client",
    "phone": "13800138000",
    "avatar": null,
    "bio": "",
    "skills": "",
    "rating": 0.0,
    "completed_orders": 0,
    "is_active": true
  }
}
```

> `user` 对象的字段说明见 [5.1 注册 - user 对象字段说明](#51-注册)。

**失败响应** (401)：

```json
{
  "success": false,
  "message": "账号或密码错误"
}
```

**axios 示例**：

```javascript
axios({
  method: 'post',
  url: '/api/auth/login/',
  data: {
    username: 'testclient',
    password: 'client123'
  },
})
.then(res => {
  // 登录成功，res.data = { success: true, user: {...} }
  const user = res.data.user
  // 保存用户信息到 store/localStorage，然后跳转
})
.catch(error => {
  if (error.response && error.response.status === 401) {
    // 登录失败，显示错误信息
    const message = error.response.data.message  // "账号或密码错误"
  }
})
```

> **关于 Cookie 的说明**：
>
> 登录成功后，Django 会在响应头中返回 `Set-Cookie: sessionid=xxxx`。浏览器会自动保存这个 Cookie，后续请求会自动携带。**前端不需要手动操作 Cookie**，只需要确保配置了 `axios.defaults.withCredentials = true` 即可。
>
> **前端处理建议**：
> 1. 登录成功后将 `user` 对象保存到全局状态和 `localStorage`（用于页面刷新后恢复登录状态）
> 2. 根据 `user.role` 跳转到对应首页
> 3. 登录失败时显示错误提示

---

### 5.3 退出登录

```
POST /api/auth/logout/
```

**权限**：需要登录

**请求体**：无

**成功响应** (200)：

```json
{
  "success": true
}
```

**axios 示例**：

```javascript
axios({
  method: 'post',
  url: '/api/auth/logout/',
})
.then(res => {
  // 清除本地保存的用户信息（localStorage、Pinia store），然后跳转到登录页
})
.catch(error => console.error(error))
```

> **前端处理建议**：调用退出接口后，清除本地保存的用户信息（`localStorage`、Pinia store），然后跳转到登录页。

---

### 5.4 获取当前用户信息

```
GET /api/auth/me/
```

**权限**：需要登录

**用途**：页面刷新后，用这个接口验证登录状态是否有效，并获取最新的用户信息。

**成功响应** (200)：

```json
{
  "id": 1,
  "username": "testuser",
  "email": "",
  "role": "client",
  "phone": "",
  "avatar": null,
  "bio": "",
  "skills": "",
  "rating": 0.0,
  "completed_orders": 0,
  "is_active": true
}
```

**失败响应** (401)：

```json
{
  "success": false,
  "message": "身份认证信息未提供。"
}
```

**axios 示例**：

```javascript
axios({
  method: 'get',
  url: '/api/auth/me/',
})
.then(res => {
  // 已登录，res.data 就是用户对象
  const user = res.data
})
.catch(error => {
  if (error.response && error.response.status === 401) {
    // 未登录或 Session 过期，跳转到登录页
    window.location.href = '/login'
  }
})
```

> **字段说明**：
>
> | 字段 | 类型 | 说明 |
> |------|------|------|
> | `id` | int | 用户ID |
> | `username` | string | 用户名 |
> | `email` | string | 邮箱 |
> | `role` | string | 角色：`client` / `provider` / `admin`，用于判断应进入哪个页面 |
> | `phone` | string | 手机号 |
> | `avatar` | string \| null | 头像URL。`null` 表示无头像；有头像时为 `/media/avatars/xxx.png`，在 `<img>` 中可直接使用 |
> | `bio` | string | 个人简介 |
> | `skills` | string | 专业技能 |
> | `rating` | float | 评分（0-5），只读 |
> | `completed_orders` | int | 完成订单数，只读 |
> | `is_active` | bool | 账号是否启用，被管理员禁用后为 `false` |

---

### 5.5 修改当前用户信息

```
PUT /api/auth/me/
```

**权限**：需要登录

**请求体**（JSON 格式，可部分提交，只传需要修改的字段）：

```json
{
  "username": "string, 可选, 新用户名",
  "email": "string, 可选, 邮箱",
  "phone": "string, 可选, 手机号",
  "bio": "string, 可选, 个人简介",
  "skills": "string, 可选, 专业技能"
}
```

**上传头像**（需要使用 `multipart/form-data` 格式）：

| 字段 | 类型 | 说明 |
|------|------|------|
| `avatar` | File | 图片文件（支持 jpg、png 等格式） |

**上传头像示例**：

```javascript
const formData = new FormData()
formData.append('avatar', selectedFile)

axios({
  method: 'put',
  url: '/api/auth/me/',
  data: formData,
  headers: {
    'Content-Type': 'multipart/form-data'
  },
})
.then(res => console.log(res.data))
.catch(error => console.error(error))
```

**成功响应** (200)：

```json
{
  "id": 2,
  "username": "newname",
  "email": "new@example.com",
  "role": "client",
  "phone": "13800138000",
  "avatar": "/media/avatars/photo.png",
  "bio": "个人简介",
  "skills": "Vue, Python",
  "rating": 4.5,
  "completed_orders": 10,
  "is_active": true
}
```

> 字段说明见 [5.4 获取当前用户信息 - 字段说明](#54-获取当前用户信息)。

**失败响应** (400)：字段验证错误

```json
{
  "success": false,
  "message": "已存在一位使用该名字的用户。"
}
```

> **注意**：上传头像时使用 `FormData` 对象，并设置 `Content-Type: multipart/form-data`。

---

### 5.6 修改密码

```
POST /api/auth/change-password/
```

**权限**：需要登录

**请求体**：

```json
{
  "old_password": "string, 必填, 当前密码",
  "new_password": "string, 必填, 新密码, 最少6位"
}
```

**成功响应** (200)：

```json
{
  "success": true,
  "message": "密码修改成功"
}
```

**失败响应** (400)：

未填写完整信息时：
```json
{
  "success": false,
  "message": "请填写完整信息"
}
```

当前密码错误时：
```json
{
  "success": false,
  "message": "当前密码错误"
}
```

新密码不足6位时：
```json
{
  "success": false,
  "message": "新密码至少6位"
}
```

**axios 示例**：

```javascript
axios({
  method: 'post',
  url: '/api/auth/change-password/',
  data: {
    old_password: 'oldpass123',
    new_password: 'newpass456'
  },
})
.then(res => {
  // 密码修改成功
})
.catch(error => {
  if (error.response && error.response.status === 400) {
    const message = error.response.data.message
    // 显示错误信息：如 "当前密码错误" 或 "新密码至少6位"
  }
})
```

> **说明**：修改密码后 Session 不会失效，用户不需要重新登录。

---

## 六、用户管理接口（管理员）

### 6.1 获取用户列表

```
GET /api/users/
```

**权限**：仅管理员

**查询参数**（拼在 URL 后面，例如 `?role=client&search=test`）：

| 参数 | 类型 | 说明 |
|------|------|------|
| `role` | string | 可选，按角色筛选：`client` / `provider` |
| `search` | string | 可选，按用户名模糊搜索 |

**示例**：

```javascript
// 获取所有用户
axios({
  method: 'get',
  url: '/api/users/',
})
.then(res => console.log(res.data))
.catch(error => console.error(error))

// 只获取客户
axios({
  method: 'get',
  url: '/api/users/',
  params: { role: 'client' },
})
.then(res => console.log(res.data))
.catch(error => console.error(error))

// 搜索用户名包含 test 的用户
axios({
  method: 'get',
  url: '/api/users/',
  params: { search: 'test' },
})
.then(res => console.log(res.data))
.catch(error => console.error(error))

// 组合筛选
axios({
  method: 'get',
  url: '/api/users/',
  params: { role: 'client', search: 'test' },
})
.then(res => console.log(res.data))
.catch(error => console.error(error))
```

> **关于查询参数**：在 `axios()` 中通过 `params` 属性传递查询参数，axios 会自动拼接到 URL 后面。例如 `params: { role: 'client' }` 等同于 URL 后追加 `?role=client`。

**成功响应** (200)：

```json
[
  {
    "id": 1,
    "username": "testclient",
    "email": "",
    "role": "client",
    "phone": "13800138000",
    "avatar": null,
    "bio": "",
    "skills": "",
    "rating": 0.0,
    "completed_orders": 0,
    "is_active": true
  }
]
```

> 每个用户对象的字段说明见 [5.1 注册 - user 对象字段说明](#51-注册)。

**失败响应** (403)：

```json
{
  "success": false,
  "message": "无权限"
}
```

---

### 6.2 获取单个用户详情

```
GET /api/users/{id}/
```

**权限**：需要登录

> **URL 中的 `{id}`** 表示用户ID，是动态的。例如获取 ID 为 3 的用户：`GET /api/users/3/`

**axios 示例**：

```javascript
axios({
  method: 'get',
  url: `/api/users/${userId}/`,
})
.then(res => console.log(res.data))
.catch(error => console.error(error))
```

**成功响应** (200)：

```json
{
  "id": 3,
  "username": "testprovider",
  "email": "",
  "role": "provider",
  "phone": "",
  "avatar": null,
  "bio": "",
  "skills": "Python, Vue",
  "rating": 4.5,
  "completed_orders": 10,
  "is_active": true
}
```

> 字段说明见 [5.1 注册 - user 对象字段说明](#51-注册)。

**失败响应** (404)：

```json
{
  "success": false,
  "message": "用户不存在"
}
```

---

### 6.3 修改用户信息

```
PUT /api/users/{id}/
```

**权限**：管理员 或 用户本人（只能修改自己的信息）

**请求体**（JSON，可部分提交）：

```json
{
  "is_active": false,
  "username": "newname"
}
```

> **说明**：管理员可以通过设置 `is_active: false` 来禁用用户。

**axios 示例**：

```javascript
axios({
  method: 'put',
  url: `/api/users/${userId}/`,
  data: {
    is_active: false,
    username: 'newname'
  },
})
.then(res => console.log(res.data))
.catch(error => console.error(error))
```

**成功响应** (200)：

```json
{
  "id": 3,
  "username": "newname",
  "email": "",
  "role": "provider",
  "phone": "",
  "avatar": null,
  "bio": "",
  "skills": "Python, Vue",
  "rating": 4.5,
  "completed_orders": 10,
  "is_active": false
}
```

> 字段说明见 [5.1 注册 - user 对象字段说明](#51-注册)。

---

### 6.4 删除用户

```
DELETE /api/users/{id}/
```

**权限**：仅管理员

**axios 示例**：

```javascript
axios({
  method: 'delete',
  url: `/api/users/${userId}/`,
})
.then(res => console.log(res.data))
.catch(error => console.error(error))
```

**成功响应** (200)：

```json
{
  "success": true
}
```

---

## 七、需求接口

### 7.1 获取需求列表

```
GET /api/needs/
```

**权限**：需要登录

**查询参数**：

| 参数 | 类型 | 说明 |
|------|------|------|
| `status` | string | 可选，按状态筛选 |
| `user` | int | 可选，按发布用户ID筛选 |
| `type` | string | 可选，按需求类型筛选 |

**axios 示例**：

```javascript
// 获取所有需求
axios({
  method: 'get',
  url: '/api/needs/',
})
.then(res => console.log(res.data))
.catch(error => console.error(error))

// 只获取待接单的需求
axios({
  method: 'get',
  url: '/api/needs/',
  params: { status: 'pending' },
})
.then(res => console.log(res.data))
.catch(error => console.error(error))

// 获取用户ID=2 发布的需求
axios({
  method: 'get',
  url: '/api/needs/',
  params: { user: 2 },
})
.then(res => console.log(res.data))
.catch(error => console.error(error))
```

**成功响应** (200)：

```json
[
  {
    "id": 1,
    "user": 2,
    "username": "testclient",
    "title": "设计一个企业官网",
    "type": "网站开发",
    "description": "需要一个响应式的企业官网...",
    "budget": "5000",
    "status": "pending",
    "attachment": null
  }
]
```

> **字段说明**：
>
> | 字段 | 类型 | 说明 |
> |------|------|------|
> | `id` | int | 需求ID |
> | `user` | int | 发布者用户ID（创建时后端自动设置，前端不能传） |
> | `username` | string | 发布者用户名（只读，后端自动填充） |
> | `title` | string | 需求标题 |
> | `type` | string | 需求类型（如：网站开发、UI/UX设计、移动开发） |
> | `description` | string | 需求详细描述，可为空字符串 |
> | `budget` | string | 预算金额，**string 类型**，不是 number |
> | `status` | string | 状态：`pending`（待接单）/ `matched`（已匹配）/ `draft`（草稿）/ `in_progress`（进行中）/ `completed`（已完成）/ `cancelled`（已取消） |
> | `attachment` | string \| null | 附件URL。`null` 表示无附件；有附件时为 `/media/attachments/xxx.pdf`，可在 `<a>` 标签中使用 |

---

### 7.2 获取需求详情

```
GET /api/needs/{id}/
```

**权限**：需要登录

**axios 示例**：

```javascript
axios({
  method: 'get',
  url: `/api/needs/${needId}/`,
})
.then(res => console.log(res.data))
.catch(error => console.error(error))
```

**成功响应** (200)：

```json
{
  "id": 1,
  "user": 2,
  "username": "testclient",
  "title": "设计一个企业官网",
  "type": "网站开发",
  "description": "需要一个响应式的企业官网...",
  "budget": "5000",
  "status": "pending",
  "attachment": null
}
```

> 字段说明见 [7.1 获取需求列表 - 字段说明](#71-获取需求列表)。

**失败响应** (404)：

```json
{
  "success": false,
  "message": "需求不存在"
}
```

---

### 7.3 创建需求

```
POST /api/needs/
```

**权限**：需要登录

**无附件时**（JSON 格式）：

```json
{
  "title": "string, 必填, 需求标题",
  "type": "string, 必填, 需求类型（如：网站开发、UI/UX设计）",
  "description": "string, 可选, 需求详细描述",
  "budget": "string, 必填, 预算金额（如 '5000'）"
}
```

**有附件时**（`multipart/form-data` 格式）：

| 字段 | 类型 | 说明 |
|------|------|------|
| `title` | string | 必填 |
| `type` | string | 必填 |
| `description` | string | 可选 |
| `budget` | string | 必填 |
| `attachment` | File | 可选，附件文件 |

> **重要**：`user` 字段由后端自动设置为当前登录用户，**前端不需要也不能传递** `user` 字段。`status` 默认为 `pending`，也不需要传。

**axios 示例**：

```javascript
// 无附件
axios({
  method: 'post',
  url: '/api/needs/',
  data: {
    title: '设计一个企业官网',
    type: '网站开发',
    budget: '5000',
    description: '需要一个响应式的企业官网...'
  },
})
.then(res => console.log(res.data))
.catch(error => console.error(error))

// 有附件
const formData = new FormData()
formData.append('title', '设计一个企业官网')
formData.append('type', '网站开发')
formData.append('budget', '5000')
formData.append('attachment', fileInput.files[0])

axios({
  method: 'post',
  url: '/api/needs/',
  data: formData,
  headers: { 'Content-Type': 'multipart/form-data' },
})
.then(res => console.log(res.data))
.catch(error => console.error(error))
```

**成功响应** (201)：

```json
{
  "id": 2,
  "user": 2,
  "username": "testclient",
  "title": "设计一个企业官网",
  "type": "网站开发",
  "description": "需要一个响应式的企业官网...",
  "budget": "5000",
  "status": "pending",
  "attachment": null
}
```

> 字段说明见 [7.1 获取需求列表 - 字段说明](#71-获取需求列表)。

> **重要**：创建需求时，后端会**自动创建一个 `pending` 状态的订单**，关联到该需求。此时订单没有服务方（`provider` 为 `null`），等待服务方接单。

**失败响应** (400)：

```json
{
  "success": false,
  "message": "该字段是必填项。"
}
```

---

### 7.4 修改需求

```
PUT /api/needs/{id}/
```

**权限**：需求创建者 或 管理员

**请求体**（JSON，可部分提交）：同创建需求的字段

**axios 示例**：

```javascript
axios({
  method: 'put',
  url: `/api/needs/${needId}/`,
  data: {
    title: '修改后的标题',
    budget: '8000'
  },
})
.then(res => console.log(res.data))
.catch(error => console.error(error))
```

**成功响应** (200)：

```json
{
  "id": 1,
  "user": 2,
  "username": "testclient",
  "title": "修改后的标题",
  "type": "网站开发",
  "description": "需要一个响应式的企业官网...",
  "budget": "8000",
  "status": "pending",
  "attachment": null
  }
]
```

> 字段说明见 [7.1 获取需求列表 - 字段说明](#71-获取需求列表)。

**失败响应** (403)：

```json
{
  "success": false,
  "message": "无权限"
}
```

---

### 7.5 删除需求

```
DELETE /api/needs/{id}/
```

**权限**：需求创建者 或 管理员

**axios 示例**：

```javascript
axios({
  method: 'delete',
  url: `/api/needs/${needId}/`,
})
.then(res => console.log(res.data))
.catch(error => console.error(error))
```

**成功响应** (200)：

```json
{
  "success": true
}
```

---

## 八、接单接口

### 8.1 服务方接单

```
POST /api/needs/{id}/accept/
```

**权限**：服务方（`provider`）或管理员（`admin`）

**路径参数**：

| 参数 | 类型 | 说明 |
|------|------|------|
| `id` | int | 需求ID，必须是 `pending` 状态的需求 |

**请求体**：

```json
{
  "amount": "string, 可选, 接单金额（如 '5000'），不传则使用需求预算"
}
```

**axios 示例**：

```javascript
axios({
  method: 'post',
  url: `/api/needs/${needId}/accept/`,
  data: {
    amount: '5000',
  },
})
.then(res => {
  const order = res.data.order
})
.catch(error => console.error(error))
```

**成功响应** (200)：

```json
{
  "success": true,
  "order": {
    "id": 1,
    "need": 1,
    "need_title": "设计一个企业官网",
    "need_attachment": null,
    "need_attachment_url": null,
    "client": 2,
    "client_name": "testclient",
    "provider": 3,
    "provider_name": "testprovider",
    "title": "设计一个企业官网",
    "amount": "5000",
    "status": "in_progress",
    "progress": 0
  }
}
```

> **order 对象字段说明**：
>
> | 字段 | 类型 | 说明 |
> |------|------|------|
> | `id` | int | 订单ID |
> | `need` | int \| null | 关联需求ID |
> | `need_title` | string \| null | 关联需求标题（只读，后端自动填充） |
> | `need_attachment` | string \| null | 关联需求附件相对路径（只读），`null` 表示无附件 |
> | `need_attachment_url` | string \| null | 关联需求附件完整下载URL（只读），可直接用于 `<a href="">` 下载，`null` 表示无附件 |
> | `client` | int | 客户用户ID |
> | `client_name` | string | 客户用户名（只读，后端自动填充） |
> | `provider` | int \| null | 服务方用户ID |
> | `provider_name` | string \| null | 服务方用户名（只读，后端自动填充） |
> | `title` | string | 订单标题 |
> | `amount` | string | 订单金额，**string 类型** |
> | `status` | string | 订单状态：`pending`（待接单）/ `in_progress`（进行中）/ `completed`（待客户支付）/ `paid`（待客户评价）/ `reviewed`（已完成）/ `cancelled`（已取消） |
> | `progress` | int | 进度百分比（0-100） |

> **重要**：接单后，后端会自动完成以下操作：
> 1. 将需求状态设为 `matched`
> 2. **更新已存在的 `pending` 订单**（创建需求时已自动创建），设置 `provider` 为当前服务方，状态设为 `in_progress`
>
> 前端不需要额外调用创建订单的接口，直接使用返回的 `order` 对象跳转到订单详情页即可。

**失败响应** (400)：

```json
{
  "success": false,
  "message": "该需求不可接单"
}
```

> 需求状态不是 `pending` 时返回此错误（已被其他服务方接单）。

**失败响应** (403)：

```json
{
  "success": false,
  "message": "仅服务方可接单"
}
```

**失败响应** (404)：

```json
{
  "success": false,
  "message": "需求不存在"
}
```

---

## 九、订单接口

### 9.1 获取订单列表

```
GET /api/orders/
```

**权限**：需要登录

**数据范围**（后端自动过滤，前端不需要做额外处理）：
- **管理员**：可查看所有订单，支持按 `client`、`provider` 筛选
- **客户**：只能看到自己作为客户的订单
- **服务方**：只能看到自己作为服务方的订单

**查询参数**（拼在 URL 后面，例如 `?status=in_progress&search=官网`）：

| 参数 | 类型 | 说明 |
|------|------|------|
| `client` | int | 可选，按客户ID筛选（仅管理员可用） |
| `provider` | int | 可选，按服务方ID筛选（仅管理员可用） |
| `status` | string | 可选，按状态筛选，支持英文值（如 `pending`）和中文值（如 `待接单`） |
| `search` | string | 可选，按订单ID或需求标题模糊搜索 |

**axios 示例**：

```javascript
// 获取我能看到的订单
axios({
  method: 'get',
  url: '/api/orders/',
})
.then(res => console.log(res.data))
.catch(error => console.error(error))

// 模糊搜索：搜索订单ID或需求标题包含"官网"的订单
axios({
  method: 'get',
  url: '/api/orders/',
  params: { search: '官网' },
})
.then(res => console.log(res.data))
.catch(error => console.error(error))

// 状态筛选：只获取进行中的订单
axios({
  method: 'get',
  url: '/api/orders/',
  params: { status: 'in_progress' },
})
.then(res => console.log(res.data))
.catch(error => console.error(error))

// 组合筛选：搜索标题包含"官网"且状态为进行中的订单
axios({
  method: 'get',
  url: '/api/orders/',
  params: { search: '官网', status: 'in_progress' },
})
.then(res => console.log(res.data))
.catch(error => console.error(error))
```

**成功响应** (200)：

```json
[
  {
    "id": 1,
    "need": 1,
    "need_title": "设计一个企业官网",
    "need_attachment": "/media/attachments/xxx.pdf",
    "need_attachment_url": "http://127.0.0.1:8000/media/attachments/xxx.pdf",
    "client": 2,
    "client_name": "testclient",
    "provider": 3,
    "provider_name": "testprovider",
    "title": "设计一个企业官网",
    "amount": "4500",
    "status": "in_progress",
    "progress": 60
  }
]
```

> **字段说明**：
>
> | 字段 | 类型 | 说明 |
> |------|------|------|
> | `id` | int | 订单ID |
> | `need` | int \| null | 关联需求ID |
> | `need_title` | string \| null | 关联需求标题（只读，后端自动填充） |
> | `need_attachment` | string \| null | 关联需求附件相对路径（只读），`null` 表示无附件 |
> | `need_attachment_url` | string \| null | 关联需求附件完整下载URL（只读），可直接用于 `<a href="">` 下载，`null` 表示无附件 |
> | `client` | int | 客户用户ID |
> | `client_name` | string | 客户用户名（只读，后端自动填充） |
> | `provider` | int \| null | 服务方用户ID |
> | `provider_name` | string \| null | 服务方用户名（只读，后端自动填充） |
> | `title` | string | 订单标题 |
> | `amount` | string | 订单金额，**string 类型** |
> | `status` | string | 订单状态：`pending`（待接单）/ `in_progress`（进行中）/ `completed`（待客户支付）/ `paid`（待客户评价）/ `reviewed`（已完成）/ `cancelled`（已取消） |
> | `progress` | int | 进度百分比（0-100） |

---

### 9.2 获取订单详情

```
GET /api/orders/{id}/
```

**权限**：需要登录（必须是订单的客户、服务方或管理员，否则返回 403）

**axios 示例**：

```javascript
axios({
  method: 'get',
  url: `/api/orders/${orderId}/`,
})
.then(res => console.log(res.data))
.catch(error => console.error(error))
```

**成功响应** (200)：

```json
{
  "id": 1,
  "need": 1,
  "need_title": "设计一个企业官网",
  "need_attachment": null,
  "need_attachment_url": null,
  "client": 2,
  "client_name": "testclient",
  "provider": 3,
  "provider_name": "testprovider",
  "title": "设计一个企业官网",
  "amount": "4500",
  "status": "in_progress",
  "progress": 60
}
```

> 字段说明见 [9.1 获取订单列表 - 字段说明](#91-获取订单列表)。

**失败响应** (403)：

```json
{
  "success": false,
  "message": "无权限"
}
```

**失败响应** (404)：

```json
{
  "success": false,
  "message": "订单不存在"
}
```

---

### 9.3 创建订单

```
POST /api/orders/
```

**权限**：需要登录

> **说明**：正常业务流程中，订单是在"服务方接单"时自动创建的（见 8.1），不需要前端单独调用此接口。此接口主要用于管理员的特殊操作。

**请求体**：

```json
{
  "need": "int, 可选, 关联需求ID",
  "client": "int, 必填, 客户ID",
  "provider": "int, 可选, 服务方ID",
  "title": "string, 必填, 订单标题",
  "amount": "string, 必填, 订单金额",
  "status": "string, 可选, 默认 pending",
  "progress": "int, 可选, 默认 0"
}
```

**axios 示例**：

```javascript
axios({
  method: 'post',
  url: '/api/orders/',
  data: {
    client: 2,
    title: '手动创建的订单',
    amount: '3000'
  },
})
.then(res => console.log(res.data))
.catch(error => console.error(error))
```

**成功响应** (201)：

```json
{
  "id": 2,
  "need": null,
  "need_title": null,
  "need_attachment": null,
  "need_attachment_url": null,
  "client": 2,
  "client_name": "testclient",
  "provider": null,
  "provider_name": null,
  "title": "手动创建的订单",
  "amount": "3000",
  "status": "pending",
  "progress": 0
}
```

> 字段说明见 [9.1 获取订单列表 - 字段说明](#91-获取订单列表)。

---

### 9.4 修改订单

```
PUT /api/orders/{id}/
```

**权限**：需要登录（必须是订单的客户、服务方或管理员）

**请求体**（JSON，可部分提交）：

```json
{
  "status": "string, 可选, 新状态",
  "progress": "int, 可选, 进度百分比 0-100"
}
```

**常见用法**：

```javascript
// 服务方标记完成
axios({
  method: 'put',
  url: `/api/orders/${orderId}/`,
  data: { status: 'completed', progress: 100 },
})
.then(res => console.log(res.data))
.catch(error => console.error(error))

// 客户确认支付
axios({
  method: 'put',
  url: `/api/orders/${orderId}/`,
  data: { status: 'paid' },
})
.then(res => console.log(res.data))
.catch(error => console.error(error))

// 取消订单（仅 pending 和 in_progress 状态可取消）
axios({
  method: 'put',
  url: `/api/orders/${orderId}/`,
  data: { status: 'cancelled' },
})
.then(res => console.log(res.data))
.catch(error => console.error(error))
```

**成功响应** (200)：

```json
{
  "id": 1,
  "need": 1,
  "need_title": "设计一个企业官网",
  "need_attachment": null,
  "need_attachment_url": null,
  "client": 2,
  "client_name": "testclient",
  "provider": 3,
  "provider_name": "testprovider",
  "title": "设计一个企业官网",
  "amount": "4500",
  "status": "completed",
  "progress": 100
}
```

> 字段说明见 [9.1 获取订单列表 - 字段说明](#91-获取订单列表)。

**失败响应** (403)：

```json
{
  "success": false,
  "message": "无权限"
}
```

**失败响应** (404)：

```json
{
  "success": false,
  "message": "订单不存在"
}
```

> **订单状态流转**：
> ```
> pending（待接单）
>   ↓
> in_progress（进行中）
>   ↓ 服务方点击完成 → PUT { status: 'completed' }
> completed（待客户支付）
>   ↓ 客户点击支付 → PUT { status: 'paid' }
> paid（待客户评价）
>   ↓ 客户提交评价 → 通过评价接口自动完成
> reviewed（已完成）
> ```
>
> **可取消的订单状态**：仅 `pending`（待接单）和 `in_progress`（进行中）可以取消（设为 `cancelled`）。`completed`、`paid`、`reviewed` 状态的订单**不可取消**。

---

## 十、消息接口

### 10.1 获取消息列表

```
GET /api/messages/?order={orderId}
```

**权限**：需要登录（必须是订单的客户、服务方或管理员）

**查询参数**：

| 参数 | 类型 | 说明 |
|------|------|------|
| `order` | int | **必填**，订单ID |

> **注意**：`order` 参数是**必填**的。不传会返回 400 错误。只能查看自己参与订单的消息，否则返回 403。

**axios 示例**：

```javascript
// 获取订单ID=5 的所有消息
axios({
  method: 'get',
  url: '/api/messages/',
  params: { order: 5 },
})
.then(res => console.log(res.data))
.catch(error => console.error(error))
```

**成功响应** (200)：

```json
[
  {
    "id": 1,
    "order": 1,
    "sender": 2,
    "sender_name": "testclient",
    "sender_role": "client",
    "sender_avatar": "http://127.0.0.1:8000/media/avatars/photo.png",
    "text": "你好，请问进度如何？"
  },
  {
    "id": 2,
    "order": 1,
    "sender": 3,
    "sender_name": "testprovider",
    "sender_role": "provider",
    "sender_avatar": null,
    "text": "您好！目前进度60%。"
  }
]
```

> **字段说明**：
>
> | 字段 | 类型 | 说明 |
> |------|------|------|
> | `id` | int | 消息ID |
> | `order` | int | 关联订单ID |
> | `sender` | int | 发送者用户ID（创建时后端自动设置） |
> | `sender_name` | string | 发送者用户名（只读，后端自动填充） |
> | `sender_role` | string | 发送者角色（只读）：`client` / `provider` / `admin` |
> | `sender_avatar` | string \| null | 发送者头像完整URL（只读），可直接用于 `<img :src="">`，`null` 表示无头像 |
> | `text` | string | 消息内容 |
>
> 可用 `sender_role` 来区分消息气泡方向：当前用户的角色和 `sender_role` 相同时靠右显示，否则靠左显示

**失败响应** (400)：

```json
{
  "success": false,
  "message": "请指定订单ID"
}
```

**失败响应** (403)：

```json
{
  "success": false,
  "message": "无权限"
}
```

---

### 10.2 发送消息

```
POST /api/messages/
```

**权限**：需要登录（必须是订单的客户、服务方或管理员）

**请求体**：

```json
{
  "order": "int, 必填, 订单ID",
  "text": "string, 必填, 消息内容"
}
```

> **说明**：`sender` 由后端自动设置为当前登录用户，不需要前端传递。

**axios 示例**：

```javascript
axios({
  method: 'post',
  url: '/api/messages/',
  data: {
    order: orderId,
    text: '你好，请问进度如何？'
  },
})
.then(res => console.log(res.data))
.catch(error => console.error(error))
```

**成功响应** (201)：

```json
{
  "id": 3,
  "order": 1,
  "sender": 2,
  "sender_name": "testclient",
  "sender_role": "client",
  "text": "你好，请问进度如何？"
}
```

> 字段说明见 [10.1 获取消息列表 - 字段说明](#101-获取消息列表)。

---

## 十一、评价接口

### 11.1 获取评价列表

```
GET /api/reviews/
```

**权限**：需要登录

**数据范围**：
- **管理员**：可查看所有评价
- **客户/服务方**：只能查看与自己参与订单相关的评价

**查询参数**：

| 参数 | 类型 | 说明 |
|------|------|------|
| `order` | int | 可选，按订单ID筛选（必须是该订单的参与方，否则返回 403） |

**axios 示例**：

```javascript
// 获取订单ID=5 的评价
axios({
  method: 'get',
  url: '/api/reviews/',
  params: { order: 5 },
})
.then(res => console.log(res.data))
.catch(error => console.error(error))
```

**成功响应** (200)：

```json
[
  {
    "id": 1,
    "order": 1,
    "reviewer": 2,
    "rating": 5,
    "tags": "服务态度好,交付及时,沟通顺畅",
    "comment": "非常满意，服务很专业！"
  }
]
```

> **字段说明**：
>
> | 字段 | 类型 | 说明 |
> |------|------|------|
> | `id` | int | 评价ID |
> | `order` | int | 关联订单ID（一个订单只有一条评价） |
> | `reviewer` | int | 评价者用户ID（创建时后端自动设置） |
> | `rating` | int | 评分（1-5 的整数） |
> | `tags` | string | 评价标签，逗号分隔的字符串。前端显示时用 `tags.split(',')` 拆分为数组 |
> | `comment` | string | 文字评价，可为空字符串 |

**失败响应** (403)：

```json
{
  "success": false,
  "message": "无权限"
}
```

---

### 11.2 创建评价

```
POST /api/reviews/
```

**权限**：需要登录（必须是订单的客户、服务方或管理员）

**请求体**：

```json
{
  "order": "int, 必填, 订单ID",
  "rating": "int, 必填, 评分 1-5",
  "tags": "string, 可选, 逗号分隔的标签（如 '服务态度好,交付及时'）",
  "comment": "string, 可选, 文字评价"
}
```

**axios 示例**：

```javascript
axios({
  method: 'post',
  url: '/api/reviews/',
  data: {
    order: orderId,
    rating: 5,
    tags: '服务态度好,交付及时,沟通顺畅',
    comment: '非常满意，服务很专业！'
  },
})
.then(res => console.log(res.data))
.catch(error => console.error(error))
```

> **说明**：
> - `reviewer` 由后端自动设置为当前登录用户
> - 提交评价后，后端会**自动**完成以下操作：
>   1. 将订单状态设为 `reviewed`（已完成）
>   2. 重新计算服务方的平均评分
> - 前端不需要额外调用修改订单状态的接口

**成功响应** (201)：

```json
{
  "id": 1,
  "order": 1,
  "reviewer": 2,
  "rating": 5,
  "tags": "服务态度好,交付及时,沟通顺畅",
  "comment": "非常满意，服务很专业！"
}
```

> 字段说明见 [11.1 获取评价列表 - 字段说明](#111-获取评价列表)。

---

## 十二、WebSocket 实时通信

聊天功能使用 **WebSocket** 实现实时消息推送

### 什么是 WebSocket？

WebSocket 是一种**持久双向连接**协议：

- **HTTP**：客户端发请求 → 服务端返回响应 → 连接断开。每次都要重新建立连接
- **WebSocket**：客户端和服务端建立连接后，**保持连接不断开**，双方可以随时互相发送数据

这意味着：当一方发送消息时，后端可以**立即推送**给同一订单的其他参与者，对方**无需刷新或重新请求**就能看到新消息。

### 连接地址

```
ws://localhost:5173/ws/chat/{order_id}/
```

> **说明**：
> - `{order_id}` 是订单ID，例如 `ws://localhost:5173/ws/chat/5/`

### 连接条件

- 必须**已登录**（WebSocket 连接时浏览器会自动携带 Session Cookie）
- 必须是该订单的**客户、服务方或管理员**，否则连接会被拒绝

### 前端使用方式

#### 1. 安装依赖

后端需要额外安装两个 Python 包：

```bash
pip install channels daphne
```

- `channels`：让 Django 支持 WebSocket
- `daphne`：ASGI 服务器，同时处理 HTTP 和 WebSocket 请求

#### 2. 创建 WebSocket 连接

```javascript
// 连接 WebSocket
const ws = new WebSocket(`ws://localhost:5173/ws/chat/${orderId}/`)

// 连接成功
ws.onopen = () => {
  console.log('WebSocket 已连接')
}

// 收到消息（实时推送）
ws.onmessage = (event) => {
  const msg = JSON.parse(event.data)
  console.log('收到新消息:', msg)
}

// 连接断开
ws.onclose = () => {
  console.log('WebSocket 已断开')
}

// 发送消息
ws.send(JSON.stringify({ text: '你好' }))

// 断开连接（离开页面时调用）
ws.close()
```

### 收发数据格式

#### 发送消息（客户端 → 服务端）

```json
{
  "text": "你好，请问进度如何？"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `text` | string | 是 | 消息内容 |

#### 接收消息（服务端 → 客户端）

```json
{
  "id": 15,
  "order": 5,
  "sender": 2,
  "sender_name": "testclient",
  "sender_role": "client",
  "text": "你好，请问进度如何？"
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | int | 消息ID |
| `order` | int | 订单ID |
| `sender` | int | 发送者用户ID |
| `sender_name` | string | 发送者用户名 |
| `sender_role` | string | 发送者角色：`client` / `provider` / `admin` |
| `text` | string | 消息内容 |

### 工作原理

```
┌──────────┐  WebSocket连接   ┌──────────┐  WebSocket连接   ┌──────────┐
│  客户端A  │ ←──────────────→ │   后端    │ ←──────────────→ │  客户端B  │
│ (客户)    │                  │ (Django   │                  │ (服务方)  │
│          │                  │ Channels) │                  │          │
└──────────┘                  └─────┬─────┘                  └──────────┘
                                    │
                                    ↓
                              ┌──────────┐
                              │  数据库    │
                              │ (MySQL)   │
                              └──────────┘

1. 客户端A 发送消息 → WebSocket.send({text: "你好"})
2. 后端收到消息 → 保存到数据库 → 广播给同订单的所有在线用户
3. 客户端B 立即收到消息 → ws.onmessage 回调触发 → 页面更新
```

**关键点**：
- 每个订单有一个"聊天组"（`chat_order_{订单ID}`）
- 加入同一组的用户都能收到彼此的消息
- 消息同时保存到数据库，刷新页面后通过 HTTP API 加载历史消息

### Vite 代理配置

前端开发服务器需要增加 WebSocket 代理：

```javascript
// vite.config.js
export default defineConfig({
  server: {
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:8000',
        changeOrigin: true
      },
      '/media': {
        target: 'http://127.0.0.1:8000',
        changeOrigin: true
      },
      '/ws': {                              // ← 新增 WebSocket 代理
        target: 'ws://127.0.0.1:8000',
        ws: true,                           // ← 关键：启用 WebSocket 代理
      }
    }
  }
})
```

### 与 HTTP 消息接口的关系

| 功能 | 推荐方式 | 说明 |
|------|---------|------|
| 加载历史消息 | `GET /api/messages/?order={id}` | 页面加载时通过 HTTP 获取历史记录 |
| 发送新消息 | WebSocket `send()` | 实时发送，对方立即收到 |
| 接收新消息 | WebSocket `onmessage` | 后端主动推送，无需轮询 |

> **注意**：WebSocket 只负责**实时推送**，历史消息仍需通过 HTTP API 获取。因为 WebSocket 连接是后来建立的，之前的消息不会被推送过来。

---

## 十三、统计接口

### 12.1 获取工作台统计数据

```
GET /api/stats/
```

**权限**：需要登录

**axios 示例**：

```javascript
axios({
  method: 'get',
  url: '/api/stats/',
})
.then(res => {
  const stats = res.data
})
.catch(error => console.error(error))
```

**响应内容根据当前用户角色不同而不同**：

#### 客户端响应 (client)

```json
{
  "in_progress_orders": 2,
  "pending_needs": 3,
  "completed_orders": 5,
  "total_spent": 25000
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `in_progress_orders` | int | 进行中的订单数 |
| `pending_needs` | int | 待接单的需求数 |
| `completed_orders` | int | 已完成的订单数 |
| `total_spent` | int | 总支出金额（单位：元） |

#### 服务方响应 (provider)

```json
{
  "in_progress_orders": 3,
  "completed_orders": 12,
  "monthly_income": 18000,
  "avg_rating": 4.5
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `in_progress_orders` | int | 进行中的订单数 |
| `completed_orders` | int | 已完成的订单数 |
| `monthly_income` | int | 月收入（单位：元） |
| `avg_rating` | float | 平均评分 |

#### 管理员响应 (admin)

```json
{
  "total_users": 50,
  "total_orders": 120,
  "total_needs": 200,
  "total_revenue": 580000,
  "in_progress_orders": 15,
  "completed_orders": 80,
  "type_distribution": [
    { "name": "网站开发", "count": 45 },
    { "name": "UI/UX设计", "count": 32 }
  ],
  "status_distribution": [
    { "name": "进行中", "count": 15 },
    { "name": "待支付", "count": 20 },
    { "name": "已完成", "count": 80 }
  ]
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `total_users` | int | 用户总数 |
| `total_orders` | int | 订单总数 |
| `total_needs` | int | 需求总数 |
| `total_revenue` | int | 总收入金额（单位：元） |
| `in_progress_orders` | int | 进行中的订单数 |
| `completed_orders` | int | 已完成的订单数（包含 completed、paid、reviewed 状态） |
| `type_distribution` | array | 需求类型分布数据，用于"需求类型分布"饼图和"热门服务排行"柱状图 |
| `status_distribution` | array | 订单状态分布数据，用于"订单状态分布"饼图 |

> **type_distribution 数组元素**：
>
> | 字段 | 类型 | 说明 |
> |------|------|------|
> | `name` | string | 需求类型名称（如：网站开发、UI/UX设计、移动开发） |
> | `count` | int | 该类型的数量 |
>
> **status_distribution 数组元素**：
>
> | 字段 | 类型 | 说明 |
> |------|------|------|
> | `name` | string | 订单状态中文名（如：进行中、待支付、已完成） |
> | `count` | int | 该状态的数量 |

---

## 十三、数据模型参考

### User 用户

| 字段 | 类型 | 说明 |
|------|------|------|
| id | int | 主键，自动生成 |
| username | string | 用户名，可修改 |
| password | string | 密码（write_only，响应中不会返回） |
| email | string | 邮箱，可为空 |
| role | string | 角色：`client` / `provider` / `admin` |
| phone | string | 手机号，可为空 |
| avatar | string \| null | 头像URL，如 `/media/avatars/xxx.png`，无头像时为 `null` |
| bio | string | 个人简介 |
| skills | string | 专业技能 |
| rating | float | 评分（0-5），只读 |
| completed_orders | int | 完成订单数，只读 |
| is_active | bool | 是否启用 |

### Need 需求

| 字段 | 类型 | 说明 |
|------|------|------|
| id | int | 主键 |
| user | int | 发布者用户ID（创建时后端自动设置） |
| username | string | 发布者用户名（只读） |
| title | string | 需求标题 |
| type | string | 需求类型（如：网站开发、UI/UX设计） |
| description | string | 需求描述 |
| budget | string | 预算金额（**string 类型**，不是 number） |
| status | string | 状态：`pending` / `matched` / `draft` / `in_progress` / `completed` / `cancelled` |
| attachment | string \| null | 附件URL |

### Order 订单

| 字段 | 类型 | 说明 |
|------|------|------|
| id | int | 主键 |
| need | int \| null | 关联需求ID |
| need_title | string | 关联需求标题（只读） |
| need_attachment | string \| null | 关联需求附件相对路径（只读） |
| need_attachment_url | string \| null | 关联需求附件完整下载URL（只读），可直接用于 `<a href="">` 下载 |
| client | int | 客户用户ID |
| client_name | string | 客户用户名（只读） |
| provider | int \| null | 服务方用户ID |
| provider_name | string \| null | 服务方用户名（只读） |
| title | string | 订单标题 |
| amount | string | 订单金额（**string 类型**） |
| status | string | 订单状态：`pending`（待接单）/ `in_progress`（进行中）/ `completed`（待客户支付）/ `paid`（待客户评价）/ `reviewed`（已完成）/ `cancelled`（已取消） |
| progress | int | 进度百分比（0-100） |

### Message 消息

| 字段 | 类型 | 说明 |
|------|------|------|
| id | int | 主键 |
| order | int | 关联订单ID |
| sender | int | 发送者用户ID（创建时后端自动设置） |
| sender_name | string | 发送者用户名（只读） |
| sender_role | string | 发送者角色（只读）：`client` / `provider` / `admin` |
| text | string | 消息内容 |

### Review 评价

| 字段 | 类型 | 说明 |
|------|------|------|
| id | int | 主键 |
| order | int | 关联订单ID（一个订单只有一条评价） |
| reviewer | int | 评价者用户ID（创建时后端自动设置） |
| rating | int | 评分（1-5） |
| tags | string | 标签（逗号分隔） |
| comment | string | 评价内容 |

---

## 十四、订单状态说明与流转图

### 状态含义

| 状态值 | 中文名 | 说明 |
|--------|--------|------|
| `pending` | 待接单 | 订单已创建，等待服务方接单。此状态下订单没有服务方（`provider` 为 `null`） |
| `in_progress` | 进行中 | 服务方已接单，正在进行中 |
| `completed` | 待客户支付 | 服务方已完成工作，等待客户确认支付 |
| `paid` | 待客户评价 | 客户已支付，等待客户评价 |
| `reviewed` | 已完成 | 客户已评价，订单流程结束 |
| `cancelled` | 已取消 | 订单已取消，仅 `pending` 和 `in_progress` 状态可取消 |

### 状态流转图

```
┌──────────┐   客户创建需求时自动创建   ┌──────────────┐
│  pending  │ ───────────────────────→ │  in_progress  │
│  待接单   │   服务方接单时更新订单     │    进行中      │
└─────┬────┘                          └───────┬───────┘
      │ 可取消                               │ 可取消
      ↓                                     ↓
┌──────────┐                          ┌──────────────┐
│ cancelled │                          │   completed   │
│  已取消   │                          │  待客户支付    │
└──────────┘                          └───────┬───────┘
                                      │ 客户支付
                                      ↓
                              ┌──────────────┐
                              │     paid      │
                              │  待客户评价    │
                              └───────┬───────┘
                                      │ 客户评价
                                      ↓
                              ┌──────────────┐
                              │   reviewed    │
                              │    已完成      │
                              └──────────────┘

注意：仅 pending 和 in_progress 状态可取消
      completed、paid、reviewed 状态不可取消
```

---

## 十五、测试账号

| 用户名 | 密码 | 角色 |
|--------|------|------|
| admin | admin123 | 管理员 |
| testclient | client123 | 客户 |
| testprovider | provider123 | 服务方 |

---

## 十六、后端启动方式

### 环境要求

- Python 3.9+
- MySQL 5.7+ 或 8.0+

### 步骤

```bash
# 1. 确保已安装 MySQL，并创建数据库
mysql -u root -p
CREATE DATABASE taskflow CHARACTER SET utf8mb4;
CREATE USER 'taskflow'@'127.0.0.1' IDENTIFIED BY 'taskflow123';
GRANT ALL PRIVILEGES ON taskflow.* TO 'taskflow'@'127.0.0.1';
FLUSH PRIVILEGES;
exit

# 2. 安装 Python 依赖
pip install django djangorestframework django-cors-headers mysqlclient pillow channels daphne

# 3. 进入 backend 目录
cd backend

# 4. 执行数据库迁移（创建数据表）
python manage.py migrate

# 5. 创建测试数据（可选，二选一）
# 方式一（推荐，跨平台兼容）：
python manage.py init_data
# 方式二：
python manage.py shell -c "exec(open('init_test_data.py', encoding='utf-8').read())"

# 6. 启动开发服务器（使用 daphne，支持 HTTP + WebSocket）
daphne -p 8000 backend.asgi:application
```

后端运行在 `http://localhost:8000`，API 前缀为 `/api/`。

> **验证后端是否启动成功**：浏览器访问 `http://localhost:8000/api/auth/me/`，如果返回 `{"success":false,"message":"身份认证信息未提供。"}` 说明后端正常运行。

---

## 十七、前端开发注意事项

### 1. API 代理配置

前端开发服务器（Vite）需要配置代理，将 `/api` 和 `/media` 请求转发到后端：

```javascript
// vite.config.js
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  server: {
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:8000',
        changeOrigin: true
      },
      '/media': {
        target: 'http://127.0.0.1:8000',
        changeOrigin: true
      }
    }
  }
})
```

> **为什么需要代理？**
> - 前端运行在 `http://localhost:5173`（Vite 默认端口）
> - 后端运行在 `http://localhost:8000`
> - 如果前端直接请求 `/api/xxx`，浏览器会请求 `http://localhost:5173/api/xxx`，这个地址不存在
> - 配置代理后，Vite 会自动将 `/api/xxx` 的请求转发到 `http://localhost:8000/api/xxx`
> - 这样前端代码中只需要写 `/api/xxx`，不需要写完整的后端地址

### 2. 请求封装要点

- 所有请求必须配置 `withCredentials: true` 以携带 Cookie
- 普通请求设置 `Content-Type: application/json`，请求体直接传对象（axios 自动序列化）
- **文件上传请求**使用 `FormData` 对象，并设置 `Content-Type: multipart/form-data`
- 收到 401 响应时，跳转到登录页
- 建议封装统一的 axios 实例（见文档前面的示例）
- **注意**：axios 的响应数据在 `response.data` 中，不是直接就是数据对象

### 3. 路由权限控制

- 未登录用户访问任何页面应跳转到 `/login`
- 不同角色只能访问对应的路由前缀（`/client/*`、`/provider/*`、`/admin/*`）
- 登录后根据 `user.role` 跳转到对应首页
- 页面刷新时，从 `localStorage` 恢复用户信息，并调用 `GET /api/auth/me/` 验证登录状态

### 4. 文件/图片 URL 处理

- 后端返回的 `avatar` 和 `attachment` 字段是相对路径（如 `/media/avatars/xxx.png`）
- 在 `<img>` 或 `<a>` 标签中可以直接使用该路径（代理会转发到后端）
- 无文件时字段为 `null`，需要做判空处理

```html
<!-- 显示头像 -->
<img v-if="user.avatar" :src="user.avatar" />
<div v-else class="default-avatar"></div>

<!-- 下载附件 -->
<a v-if="order.need_attachment_url" :href="order.need_attachment_url" target="_blank">
  下载附件
</a>
```

### 5. 金额字段

- `budget` 和 `amount` 字段类型为 **string**，不是 number
- 显示时需要手动拼接 `¥` 符号：`¥{{ order.amount }}`

### 6. axios 错误处理模式

axios 在非 2xx 响应时会自动进入 `.catch()`，建议统一在 `.catch()` 中处理错误：

```javascript
axios({
  method: 'get',
  url: '/api/orders/',
})
.then(res => {
  // 成功处理
})
.catch(error => {
  if (error.response) {
    // 服务器返回了错误响应
    const status = error.response.status
    const data = error.response.data
    
    if (status === 401) {
      // 未登录，跳转登录页
      window.location.href = '/login'
    } else if (status === 403 || status === 404 || status === 400) {
      // 统一处理：data = { success: false, message: '...' }
      console.error(data.message)
    }
  } else {
    // 网络错误或请求未发出
    console.error('网络错误')
  }
})
```

---

## 十八、ECharts 图表使用教程

**官方文档：**`https://echarts.apache.org/examples/zh/index.html#chart-type-line`

本项目使用 **vue-echarts** 组件来制作图表（柱状图、折线图、饼图等）。

### 安装

```bash
# 在前端项目根目录下执行
npm install echarts vue-echarts
```

### 全局注册

在项目入口文件 `src/main.js` 中注册 ECharts 组件：

```javascript
import { createApp } from 'vue'
import App from './App.vue'
import ECharts from 'vue-echarts'
import 'echarts'

const app = createApp(App)
app.component('ECharts', ECharts)
app.mount('#app')
```

注册后，**所有组件中都可以直接使用 `<ECharts>` 标签**，不需要在每个组件中单独导入。

### 基本使用

`<ECharts>` 组件只需要一个 `option` 属性，图表的具体类型和样式完全由 `option` 的内容决定：

```html
<template>
  <!-- 具体是哪种图形，取决于 option 的内容 -->
  <ECharts class="chart" :option="option" />
</template>

<script setup>
import { computed } from 'vue'

const option = computed(() => ({
  // ECharts 配置项，决定图表类型和样式
}))
</script>

<style scoped>
/* 必须给 ECharts 组件设置宽高，否则不会显示 */
.chart { width: 100%; height: 300px; }
</style>
```

> **重要**：`<ECharts>` 组件**必须设置宽高**，否则图表不会显示。通常设置 `width: 100%` 和具体的 `height` 值。

### 常用图表类型

#### 柱状图（bar）

```javascript
const option = computed(() => ({
  tooltip: { trigger: 'axis' },                    // 鼠标悬浮提示
  grid: { left: 40, right: 20, top: 20, bottom: 30 },  // 图表边距
  xAxis: {
    type: 'category',                              // 类目轴（文字标签）
    data: ['1月', '2月', '3月', '4月', '5月', '6月'],  // X轴标签
  },
  yAxis: {
    type: 'value',                                 // 数值轴
  },
  series: [{
    type: 'bar',                                   // ← 柱状图
    data: [120, 200, 150, 80, 70, 110],            // 数据
    barWidth: '40%',                               // 柱子宽度
    itemStyle: {
      color: '#3B82F6',                            // 柱子颜色
      borderRadius: [4, 4, 0, 0],                 // 圆角
    }
  }]
}))
```

#### 折线图（line）

```javascript
const option = computed(() => ({
  tooltip: { trigger: 'axis' },
  grid: { left: 40, right: 20, top: 20, bottom: 30 },
  xAxis: {
    type: 'category',
    data: ['1月', '2月', '3月', '4月', '5月', '6月']
  },
  yAxis: {
    type: 'value'
  },
  series: [{
    type: 'line',                                  // ← 折线图
    data: [120, 200, 150, 80, 70, 110],
    smooth: true,                                  // 平滑曲线
    areaStyle: {                                   // 面积填充
      color: {
        type: 'linear', x: 0, y: 0, x2: 0, y2: 1,
        colorStops: [
          { offset: 0, color: 'rgba(59,130,246,0.2)' },   // 顶部颜色
          { offset: 1, color: 'rgba(59,130,246,0)' },     // 底部透明
        ]
      }
    },
    lineStyle: { color: '#3B82F6', width: 2 },    // 线条样式
    itemStyle: { color: '#3B82F6' },              // 数据点颜色
  }]
}))
```

#### 饼图（pie）

```javascript
const option = computed(() => ({
  tooltip: { trigger: 'item', formatter: '{b}: {c} ({d}%)' },
  legend: {                                       // 图例
    orient: 'vertical', right: 0, top: 'center'
  },
  series: [{
    type: 'pie',                                   // ← 饼图
    radius: ['50%', '70%'],                       // 环形图（内半径, 外半径）
    center: ['35%', '50%'],                       // 圆心位置
    label: { show: false },                        // 不显示标签
    data: [                                        // 数据：name + value
      { name: '网站开发', value: 45, itemStyle: { color: '#3B82F6' } },
      { name: 'UI/UX设计', value: 32, itemStyle: { color: '#F59E0B' } },
      { name: '移动开发', value: 28, itemStyle: { color: '#10B981' } }
    ]
  }]
}))
```

> **饼图 vs 环形图**：`radius: [内半径, 外半径]` 是环形图（Donut Chart），如 `['50%', '70%']`；`radius: '70%'` 是实心饼图。

### 结合后端数据

实际项目中，图表数据通常来自后端 API。使用 `computed` 让 `option` 响应式地根据数据变化：

```javascript
import { ref, computed, onMounted } from 'vue'

const typeDist = ref([])

const option = computed(() => ({
  tooltip: { trigger: 'axis' },
  xAxis: {
    type: 'category'
  },
  yAxis: { type: 'value' },
  series: [{
    type: 'bar'
  }]
}))

onMounted(() => {
  axios({
    method: 'get',
    url: '/api/stats/',
  })
  .then(res => {
    typeDist.value = res.data.type_distribution || []
  })
  .catch(error => console.error(error))
})
```

### option 配置项速查

| 配置项 | 说明 | 常用值 |
|--------|------|--------|
| `tooltip` | 鼠标悬浮提示 | `{ trigger: 'axis' }`（柱状/折线）、`{ trigger: 'item' }`（饼图） |
| `grid` | 图表区域边距 | `{ left: 40, right: 20, top: 20, bottom: 30 }` |
| `xAxis` | X轴 | `type: 'category'`（文字）或 `type: 'value'`（数值） |
| `yAxis` | Y轴 | `type: 'value'` 或 `type: 'category'` |
| `series` | 数据系列 | `type: 'bar'`/`'line'`/`'pie'`，`data: [数据]` |
| `legend` | 图例 | `{ orient: 'vertical', right: 0, top: 'center' }` |

> **更多图表类型和配置**，参考 [ECharts 官方文档](https://echarts.apache.org/zh/option.html)
