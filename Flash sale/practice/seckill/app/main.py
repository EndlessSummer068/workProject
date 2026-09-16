from fastapi import FastAPI
from app.api.v1 import goods, user, auth, seckill
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from app.db.redis import redis_client


# 启动时开启，关闭时停止
@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理"""
    # 启动时：验证 Redis 连接 + 库存预热
    try:
        await redis_client.ping()
        print("[OK] Redis 连接成功")
    except Exception as e:
        print(f"[ERROR] Redis 连接失败: {e}")

    # 库存预热 把库存从mysql搬到redis
    from app.db.session import AsyncSessionLocal
    from app.db.redis import preheat_seckill_stock
    async with AsyncSessionLocal() as session:
        await preheat_seckill_stock(session)

    yield  # 应用运行中...

    # 关闭时：清理 Redis 连接, 防止泄露
    await redis_client.close()
    print("[OK] Redis 连接已关闭")

app = FastAPI(
    title="秒杀系统",
    description="高性能异步秒杀系统API",
    version="1.0.0",
    lifespan=lifespan  # 把上面的生命周期交给FastAPI
)

# 注册路由
app.include_router(goods.router, prefix="/api/v1")
app.include_router(user.router, prefix="/api/v1")
app.include_router(auth.router, prefix="/api/v1")
app.include_router(seckill.router, prefix="/api/v1")


@app.get("/")
async def root():
    return {"message": "Hello，秒杀系统！"}

# 添加 CORS 中间件
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:8080", "http://localhost:8081"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

