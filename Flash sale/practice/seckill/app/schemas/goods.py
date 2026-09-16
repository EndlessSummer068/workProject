from pydantic import BaseModel, Field
from typing import Optional
from decimal import Decimal
from datetime import datetime


class GoodsBase(BaseModel):
    """商品基础模型"""
    name: str = Field(..., min_length=1, max_length=100, description="商品名称")
    description: Optional[str] = Field(None, max_length=500, description="商品描述")
    price: Decimal = Field(..., gt=0, description="商品价格")
    stock: int = Field(..., ge=0, description="库存数量")


class GoodsCreate(GoodsBase):
    """商品创建模型"""
    #  秒杀字段可选，创建时不一定要设
    seckill_price: Optional[Decimal] = Field(None, gt=0, description="秒杀价格")
    seckill_stock: int = Field(0, ge=0, description="秒杀库存数量")
    seckill_start: Optional[datetime] = Field(None, description="秒杀开始时间")
    seckill_end: Optional[datetime] = Field(None, description="秒杀结束时间")


class GoodsResponse(GoodsBase):
    """接口返回用"""
    id: int                        # 数据库自增主键
    seckill_price: Optional[Decimal] = None
    seckill_stock: int = 0
    seckill_start: Optional[datetime] = None
    seckill_end: Optional[datetime] = None
    created_at: datetime           # 记录创建时间，数据库自动填充
    updated_at: datetime           # 记录更新时间，数据库自动维护

    class Config:
        from_attributes = True  # 允许从 SQLAlchemy 对象读取属性（V1 叫 orm_mode）


class GoodsListParams(BaseModel):
    """商品列表参数模型"""
    page: int = Field(1, ge=1, description="页码")
    size: int = Field(10, ge=1, le=100, description="每页数量")
    keyword: Optional[str] = Field(None, description="搜索关键词")
