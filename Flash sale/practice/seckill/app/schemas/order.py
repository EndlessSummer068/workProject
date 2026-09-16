from pydantic import BaseModel
from datetime import datetime
from typing import Optional


class OrderResponse(BaseModel):
    """订单响应"""
    # 这是把整个订单返回给前端的格式，字段和数据表对应
    id: int
    order_no: str  # 订单编号，如 SK3F8A2B1
    user_id: int
    goods_id: int
    order_price: float
    status: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class OrderWithGoodsResponse(BaseModel):
    """订单响应（带商品名称）"""
    id: int
    order_no: str     # 订单编号
    user_id: int
    goods_id: int
    goods_name: str   # 商品名称，前端展示用
    order_price: float
    status: int
    status_text: str  # 状态文字：待支付/已支付/已取消
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class SeckillResult(BaseModel):
    """秒杀结果"""
    # 秒杀成功后专门返回，只给前端他需要几个关键信息，不用把整条订单都丢过去
    order_id: int
    goods_name: str
    order_price: float
    message: str  # 给用户看的提示语，比如“秒杀成功”

