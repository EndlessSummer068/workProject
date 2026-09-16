# 秒杀系统（Flash Sale）

## 项目简介
基于 FastAPI 与 Vue2 构建的高性能异步秒杀系统，采用 Redis 原子扣减库存 + 异步队列落库的方案，支撑高并发场景下的秒杀下单、订单管理与库存管理。

## 技术栈
- 后端：Python、FastAPI、Uvicorn、SQLAlchemy(asyncio)、aiomysql、Alembic、Redis(hiredis)
- 鉴权：python-jose(JWT)、passlib(bcrypt)、python-multipart
- 前端：Vue2、Vue Router、Element UI、Axios
- 数据库：MySQL（持久化）、Redis（库存预热与原子扣减）

## 功能说明
- 商品管理：维护普通价格/库存以及秒杀价、秒杀库存、秒杀起止时间
- 秒杀下单：校验秒杀时间、重复购买，使用 Redis `DECR` 原子扣库存，扣减成功后将订单写入 `seckill:orders` 队列
- 异步落库：后台 worker 从 Redis 队列消费消息，异步写入数据库并同步扣减数据库库存，失败时回滚重新入队
- 订单管理：查询当前用户秒杀订单列表、取消订单，取消时通过 Redis 与数据库双写归还库存
- 库存预热：应用启动时从 MySQL 拉取参与秒杀的商品，将 `seckill:stock:{goods_id}` 写入 Redis
- 用户与鉴权：用户注册登录、JWT Token 鉴权、密码 bcrypt 加密
- 跨域支持：CORS 中间件放行前端 8080/8081 端口

## 如何运行
1. 后端
   ```bash
   cd "Flash sale/practice/seckill"
   python -m venv venv
   venv\Scripts\activate
   pip install -r requirements.txt
   # 配置 MySQL 与 Redis 连接（.env）
   alembic upgrade head        # 执行数据库迁移
   uvicorn app.main:app --reload --port 8000
   python -m app.worker        # 启动异步订单消费进程
   ```
2. 前端
   ```bash
   cd "Flash sale/practice/fontend/frontend"
   npm install
   npm run serve
   ```
3. 访问 `http://localhost:8080`，后端 API 文档：`http://localhost:8000/docs`

## 关键文件
- 后端入口：[app/main.py](file:///d:/pythonProject/Flash%20sale/practice/seckill/app/main.py)
- 秒杀下单接口：[app/api/v1/seckill.py](file:///d:/pythonProject/Flash%20sale/practice/seckill/app/api/v1/seckill.py)
- 库存预热：[app/db/redis.py](file:///d:/pythonProject/Flash%20sale/practice/seckill/app/db/redis.py)
- 异步订单消费：[app/worker.py](file:///d:/pythonProject/Flash%20sale/practice/seckill/app/worker.py)
- 商品模型：[app/models/goods.py](file:///d:/pythonProject/Flash%20sale/practice/seckill/app/models/goods.py)
- 前端配置：[fontend/frontend/package.json](file:///d:/pythonProject/Flash%20sale/practice/fontend/frontend/package.json)
