# TaskFlow 后台管理系统（vueproject）

## 项目简介
基于 Django 与 Vue3 构建的服务订单匹配平台 TaskFlow，支持客户（client）、服务方（provider）、管理员（admin）三种角色，集成了需求发布、订单匹配、实时聊天与后台管理等功能。

## 技术栈
- 后端：Python、Django、Django REST Framework、django-cors-headers、Channels（WebSocket）
- 数据库：MySQL（`taskflow` 库，utf8mb4）
- 实时通信：Django Channels（`InMemoryChannelLayer`）
- 前端：Vue3、Vue Router、Pinia、Element Plus、Axios、ECharts / vue-echarts
- 构建：Vite、Prettier、Sass

## 功能说明
- 三角色体系：客户发布需求并支付订单、服务方浏览需求并接单完成、管理员管理用户与订单、查看统计
- 用户管理：自定义 User 模型，包含角色、头像、技能、评分、完成订单数；支持按角色/关键词搜索、权限控制（管理员或本人修改删除）
- 订单管理：Order 模型关联需求、客户、服务方，包含状态、金额、进度；管理员可查看全量订单，按客户/服务方/状态搜索
- 需求管理：Need 模型支持附件上传、状态流转、删除 proposal 关联
- 实时聊天：WebSocket ChatConsumer 按 `order_id` 加入 `chat_order_{order_id}` 频道，校验登录与订单权限，实现订单内会话
- 数据初始化：`init_data` 管理命令快速生成测试用户、需求、订单数据
- 前端管理页面：`/admin` 路由下提供 dashboard / users / orders / 订单详情 / 设置等页面

## 如何运行
1. 后端
   ```bash
   cd vueproject/vueproject/backend/backend
   python -m venv venv
   venv\Scripts\activate
   pip install djangorestframework django-cors-headers channels daphne mysqlclient
   # 配置 MySQL 连接（settings.py 中 DATABASES）
   python manage.py migrate
   python manage.py init_data           # 初始化测试数据
   python manage.py runserver 0.0.0.0:8000
   # WebSocket（生产用 daphne）：daphne -b 0.0.0.0 -p 8001 backend.asgi:application
   ```
2. 前端
   ```bash
   cd vueproject/vueproject/learn/Project/vue-project
   npm install
   npm run dev
   ```
3. 访问 `http://localhost:5173`，后端 API：`http://localhost:8000/api/`

## 关键文件
- Django 配置：[backend/backend/settings.py](file:///d:/pythonProject/vueproject/vueproject/backend/backend/backend/settings.py)
- 数据模型：[backend/api/models.py](file:///d:/pythonProject/vueproject/vueproject/backend/backend/api/models.py)
- 视图与权限：[backend/api/views.py](file:///d:/pythonProject/vueproject/vueproject/backend/backend/api/views.py)
- 路由：[backend/api/urls.py](file:///d:/pythonProject/vueproject/vueproject/backend/backend/api/urls.py)
- WebSocket 消费者：[backend/api/consumers.py](file:///d:/pythonProject/vueproject/vueproject/backend/backend/api/consumers.py)
- 数据初始化：[backend/api/management/commands/init_data.py](file:///d:/pythonProject/vueproject/vueproject/backend/backend/api/management/commands/init_data.py)
- 前端路由：[learn/Project/vue-project/src/router/index.js](file:///d:/pythonProject/vueproject/vueproject/learn/Project/vue-project/src/router/index.js)
- 前端配置：[learn/Project/vue-project/package.json](file:///d:/pythonProject/vueproject/vueproject/learn/Project/vue-project/package.json)
- 接口文档：[backend/API接口文档.md](file:///d:/pythonProject/vueproject/vueproject/backend/backend/API接口文档.md)
- 后端开发教程：[backend/TaskFlow后端开发教程.md](file:///d:/pythonProject/vueproject/vueproject/backend/backend/TaskFlow后端开发教程.md)
