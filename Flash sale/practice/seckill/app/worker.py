"""
秒杀订单消费者（后台 Worker）
功能：从 Redis 消息队列中取出秒杀订单，异步写入数据库
运行方式：python -m app.worker
"""
import asyncio
import json
from app.db.redis import redis_client
from app.db.session import AsyncSessionLocal
from app.models.order import Order
from app.crud.goods import goods_crud


async def process_order(message: dict):
    """处理单个订单消息：写入数据库 + 扣减数据库库存"""
    async with AsyncSessionLocal() as db:
        try:
            # 1. 创建订单
            order = Order(
                order_no=message["order_no"],
                user_id=message["user_id"],
                goods_id=message["goods_id"],
                order_price=message["order_price"],
                status=0  # 待支付
            )
            db.add(order)
            # 2. 同步扣减数据库库存
            await goods_crud.decrease_seckill_stock(db, message["goods_id"])
            await db.commit()
            print(f"[OK] 订单创建成功: {message['order_no']} | 用户 {message['user_id']} | {message['goods_name']}")
        except Exception as e:
            await db.rollback()
            print(f"[ERROR] 订单创建失败: {message['order_no']} | 错误: {e}")
            # 失败的消息重新放回队列
            await redis_client.lpush("seckill:orders:failed", json.dumps(message))


async def consume_orders():
    """持续消费订单队列"""
    print("[START] 订单消费者已启动，等待消息...")
    while True:
        try:
            # BRPOP：阻塞式弹出，超时5秒（避免完全卡死）
            result = await redis_client.brpop("seckill:orders", timeout=5)
            if result is None:
                # 超时，没有新消息，继续等
                continue
            # result = (key, value)
            _, message_str = result
            message = json.loads(message_str)
            await process_order(message)
        except Exception as e:
            print(f"[ERROR] 消费者异常: {e}")
            await asyncio.sleep(1)    # 出错等1秒再继续


async def main():
    """消费者入口"""
    # 验证 Redis 连接
    await redis_client.ping()
    print("[OK] Redis 连接成功")
    # 开始消费
    await consume_orders()

if __name__ == '__main__':
    asyncio.run(main())
