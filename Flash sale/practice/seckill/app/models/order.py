from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import String, DECIMAL, Integer, ForeignKey
from app.db.base import BaseModel


class Order(BaseModel):
    """订单表"""
    __tablename__ = "orders"

    order_no: Mapped[str] = mapped_column(
        String(20), unique=True, index=True, nullable=False, comment="订单编号"
    )
    # 这个订单是谁下的 用外键指向users表的ID 以后能反查 这个人买了啥
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id"), nullable=False, comment="用户ID"
    )
    # 买的是哪个商品? 外键指向 goods表的ID
    goods_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("goods.id"), nullable=False, comment="商品ID"
    )
    # 订单价格 (冗余存一个价格 , 防止商品改价后 订单价格也跟着变)
    # 比如: 用户今天 5999下单的 总不能明天商品改价到8999 他的订单也变8999吧
    order_price: Mapped[float] = mapped_column(
        DECIMAL(10, 2), nullable=False, comment="下单价格（秒杀价）"
    )
    # 用一个数字代表订单状态
    status: Mapped[int] = mapped_column(
        Integer, default=0, comment="订单状态: 0待支付 1已支付 2已取消"
    )
