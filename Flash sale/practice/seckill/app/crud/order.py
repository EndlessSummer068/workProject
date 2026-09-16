from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select,and_
from app.crud.base import CRUDBase
from app.models.order import Order


class OrderCRUD(CRUDBase[Order]):
    """
        订单CRUD 扩展用户相关查询
    """
    async def get_by_user(self,
                          db: AsyncSession,
                          user_id: int,
                          *,    # 这个星号代表后面的参数必须用"关键词"方式传 比如skip=0,避免传错位置
                          skip: int = 0,    # 跳过多少条 (分页用)
                          limit: int = 100  # 最多取100条
                          ) -> list[Order]:
        """查询制定用户的订单列表"""
        result = await db.execute(
            select(self.model)
            .where(self.model.user_id == user_id)    # 只查这个用户的订单
            .order_by(self.model.created_at.desc())   # 按照创建时间倒序 最新的排前面
            .offset(skip)   # 从第几条开始
            .limit(limit)   # 最多拿多少条
        )
        return result.scalars().all()  # scalars().all() 把结果转换成Order对象的列表

    async def get_active_by_user_goods(
            self,
            db: AsyncSession,
            user_id: int,
            goods_id: int
    ) -> Order | None:
        """查询用户对某商品是否有未取消的订单（防重复秒杀）"""
        result = await db.execute(
            select(self.model).where(
                and_(
                    self.model.user_id == user_id,
                    self.model.goods_id == goods_id,
                    self.model.status != 2  # 排除已取消
                )
            )
        )
        return result.scalar_one_or_none()


# 全局实例 方便其他地方直接用
order_crud = OrderCRUD(Order)
