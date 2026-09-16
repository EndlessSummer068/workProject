from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import String, Text, DECIMAL, Integer, DateTime
from datetime import datetime
from app.db.base import BaseModel


class Goods(BaseModel):
    """商品表"""
    __tablename__ = "goods"

    # 基础信息字段
    name: Mapped[str] = mapped_column(String(100), nullable=False, comment="商品名称")
    description: Mapped[str | None] = mapped_column(Text, comment="商品描述")
    price: Mapped[float] = mapped_column(DECIMAL(10, 2), nullable=False, comment="商品价格")
    stock: Mapped[int] = mapped_column(Integer, default=0, comment="库存数量")

    # 秒杀相关字段
    seckill_price: Mapped[float | None] = mapped_column(
        DECIMAL(10, 2), nullable=True, comment="秒杀价格（为空表示不参与秒杀）"
    )

    # 秒杀库存
    seckill_stock: Mapped[int] = mapped_column(
        Integer, default=0, comment="秒杀库存数量"
    )

    # 秒杀开始时间:没到点不让抢
    seckill_start: Mapped[datetime] = mapped_column(
        DateTime, nullable=True, comment="秒杀开始时间"
    )

    # 秒杀结束时间:过点了也不让抢
    seckill_end: Mapped[datetime] = mapped_column(
        DateTime, nullable=True, comment="秒杀结束时间"
    )

