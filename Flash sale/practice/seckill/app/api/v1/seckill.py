import json
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.response import success, ResponseModel
from app.db.redis import redis_client
from app.db.session import get_db
from app.deps import get_current_user
from app.models.user import User
from app.models.goods import Goods
from app.models.order import Order
from app.crud.goods import goods_crud
from app.crud.order import order_crud
from app.schemas.order import SeckillResult, OrderWithGoodsResponse
import random
import string

router = APIRouter(prefix="/seckill", tags=['秒杀'])


def generate_order_no() -> str:
    """生成随机订单号：SK + 8位大写字母数字"""
    chars = string.ascii_uppercase + string.digits
    return 'SK' + ''.join(random.choices(chars, k=8))


# 秒杀下单接口
@router.post("/{goods_id}", response_model=ResponseModel[SeckillResult], summary="秒杀下单")
async def seckill_order(
        goods_id: int,
        current_user: User = Depends(get_current_user),
        db: AsyncSession = Depends(get_db)
):
    """
    秒杀下单接口
    业务流程：
    1. 检查商品是否存在
    2. 检查秒杀是否在进行中
    3. 扣减秒杀库存（原子操作，防超卖）
    4. 创建订单

     优化点：
    1. Redis Set 防重复秒杀（替代查数据库订单表）
    2. Redis DECR 原子扣库存（替代 UPDATE SQL）
    3. 消息队列异步创建订单（替代同步写数据库）
    """
    # 1.基础校验：商品是否存在、是否参与秒杀、是否在秒杀时间内
    goods = await goods_crud.get(db, id=goods_id)
    if not goods:
        raise HTTPException(status_code=404, detail="商品不存在")

    # 没设秒杀价 → 不参与秒杀
    if goods.seckill_price is None:
        raise HTTPException(status_code=400, detail="该商品不参与秒杀")

    # 检查秒杀是否在进行中
    now = datetime.now()

    # 秒杀未开始
    if goods.seckill_start and now < goods.seckill_start:
        raise HTTPException(status_code=400, detail="秒杀尚未开始")

    # 秒杀已结束
    if goods.seckill_end and now > goods.seckill_end:
        raise HTTPException(status_code=400, detail="秒杀已结束")

    # 2. Redis 防重复秒杀：用 Set 记录 "谁抢过了"
    bought_key = f"seckill:bought:{goods_id}"   # 每个商品一个集合  里面装买过的用户ID
    already_bought = await redis_client.sismember(bought_key, str(current_user.id))
    if already_bought:
        raise HTTPException(status_code=400, detail="您已秒杀过该商品，不能重复秒杀")

    # 3.Redis 原子扣库存
    stock_key = f"seckill:stock:{goods_id}"
    stock = await redis_client.decr(stock_key)  # 库存减一，返回减完之后的值
    if stock < 0:
        # 库存不足，把扣掉的加回去
        await redis_client.incr(stock_key)   # 库存加一
        raise HTTPException(status_code=400, detail="手慢了，秒杀商品已售罄")

    # 4. 标记用户已购买（加入 Set）用户下次再抢会被第二步拦截
    await redis_client.sadd(bought_key, str(current_user.id))

    # 5. 发送消息到队列，异步创建订单
    order_no = generate_order_no()
    message = {
        "order_no": order_no,
        "user_id": current_user.id,
        "goods_id": goods_id,
        "goods_name": goods.name,
        "order_price": float(goods.seckill_price),
    }
    await redis_client.lpush("seckill:orders", json.dumps(message))

    # 6. 立即返回秒杀成功
    return success(data=SeckillResult(
        order_id=0,  # 订单还在队列中，异步创建后才有真正的 ID
        goods_name=goods.name,
        order_price=float(goods.seckill_price),
        message="秒杀成功！订单正在处理中，请稍后查看。"
    ))

# 状态映射
STATUS_MAP = {
    0: '待支付',
    1: '已支付',
    2: '已取消'
}


# 查询当前登录用户的订单列表
@router.get("/my-orders", response_model=ResponseModel[list[OrderWithGoodsResponse]], summary="我的订单")
async def get_my_orders(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    orders = await order_crud.get_by_user(db, user_id=current_user.id)

    # 拼装响应数据，把商品名和状态文字带上
    result = []
    for order in orders:
        # 查商品名
        goods = await goods_crud.get(db, id=order.goods_id)
        goods_name = goods.name if goods else "商品已下架"

        result.append(OrderWithGoodsResponse(
            id=order.id,
            order_no=order.order_no,
            user_id=order.user_id,
            goods_id=order.goods_id,
            goods_name=goods_name,
            order_price=float(order.order_price),
            status=order.status,
            status_text=STATUS_MAP.get(order.status, "未知"),
            created_at=order.created_at,
            updated_at=order.updated_at,
        ))

    return success(data=result)


# 取消订单接口
@router.put("/{order_id}/cancel", response_model=ResponseModel[OrderWithGoodsResponse], summary="取消订单")
async def cancel_order(
        order_id: int,
        current_user: User = Depends(get_current_user),
        db: AsyncSession = Depends(get_db)
):
    """
    取消订单并归还库存
    业务流程：
    1. 查订单，确认存在且属于当前用户
     2. 确认订单状态是"待支付"才能取消
    3. 修改订单状态为"已取消"
    4. 归还秒杀库存
    """
    # 1. 查订单
    order = await order_crud.get(db, id=order_id)
    if not order:
        raise HTTPException(status_code=404, detail="订单不存在")
    if order.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权操作此订单")

    # 2.只有"待支付"才能取消
    if order.status != 0:
        raise HTTPException(status_code=400, detail="只有待支付的订单才能取消")

    # 3. 更新订单状态为"已取消"
    order.status = 2
    await db.commit()
    await db.refresh(order)

    # 4. 归还库存：Redis + 数据库双写
    stock_key = f"seckill:stock:{order.goods_id}"
    bought_key = f"seckill:bought:{order.goods_id}"
    await redis_client.incr(stock_key)
    # Redis 库存 +1
    await redis_client.srem(bought_key, str(current_user.id))  # 移除购买记录
    await goods_crud.increase_seckill_stock(db, order.goods_id)  # 数据库库存 +1
    await db.commit()

    # 拼装响应
    goods = await goods_crud.get(db, id=order.goods_id)
    goods_name = goods.name if goods else "商品已删除"

    return success(data=OrderWithGoodsResponse(
        id=order.id,
        user_id=order.user_id,
        order_no=order.order_no,
        goods_id=order.goods_id,
        goods_name=goods_name,
        order_price=float(order.order_price),
        status=order.status,
        status_text="已取消",
        created_at=order.created_at,
        updated_at=order.updated_at,
    ))
