from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from app.crud.base import CRUDBase
from app.models.goods import Goods


class CRUDGoods(CRUDBase[Goods]):
    """商品 CRUD，扩展秒杀相关方法"""

    async def decrease_seckill_stock(self, db: AsyncSession, goods_id: int) -> bool:
        """
        扣减秒杀库存（带行锁，防超卖）

        核心逻辑：
        UPDATE goods SET seckill_stock = seckill_stock - 1
        WHERE id = ? AND seckill_stock > 0

        只有一行会被更新，利用数据库行级锁保证不会超卖
        返回 True 表示扣减成功，False 表示库存不足
        """
        stmt = (
            update(Goods)
            .where(Goods.id == goods_id, Goods.seckill_stock > 0)
            .values(seckill_stock=Goods.seckill_stock - 1)
        )
        result = await db.execute(stmt)
        return result.rowcount > 0  # rowcount > 0 说明确实扣减了一行

    # 归还秒杀库存，取消订单，把秒杀库存还回去，否则库存会越来越少
    async def increase_seckill_stock(self, db: AsyncSession, goods_id: int) -> bool:
        """
        归还秒杀库存（取消订单时调用）

        UPDATE goods SET seckill_stock = seckill_stock + 1
        WHERE id = ?
        归还不需要判断 seckill_stock > 0 库存大于0
        """
        stmt = (
            update(Goods)
            .where(Goods.id == goods_id)
            .values(seckill_stock=Goods.seckill_stock + 1)
        )
        result = await db.execute(stmt)
        return result.rowcount > 0


goods_crud = CRUDGoods(Goods)
