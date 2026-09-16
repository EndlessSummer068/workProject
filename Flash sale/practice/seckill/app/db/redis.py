import redis.asyncio as aioredis
from app.core.config import settings
from sqlalchemy import select
from app.models.goods import Goods


# 创建 Redis 异步连接池
redis_client: aioredis.Redis = aioredis.from_url(
    settings.REDIS_URL,
    encoding="utf-8",
    # decode_responses=True 很重要，不加的话 Redis 返回的都是 bytes（如 b'10' ），加了之后
    # 直接返回字符串 '10' ，省得到处 decode。
    decode_responses=True  # 自动将 bytes 解码为字符串
)


async def get_redis() -> aioredis.Redis:
    """依赖注入用的 Redis 客户端"""
    return redis_client


async def preheat_seckill_stock(db_session):
    """
    库存预热：把数据库中所有秒杀商品的库存加载到 Redis
    Redis 数据结构：
    - seckill:stock:{goods_id} → 秒杀库存数量（String类型）
    """
    from datetime import datetime
    now = datetime.now()

    # 查询所有正在秒杀的商品
    result = await db_session.execute(
        select(Goods).where(
            Goods.seckill_price.isnot(None),   # 有秒杀价
            Goods.seckill_stock > 0,    # 有库存
        )
    )
    goods_list = result.scalars().all()

    count = 0
    for goods in goods_list:
        key = f"seckill:stock:{goods.id}"
        await redis_client.set(key, goods.seckill_stock)
        count += 1

    print(f"[OK] 库存预热完成，已加载 {count} 个商品到 Redis")
    return count
