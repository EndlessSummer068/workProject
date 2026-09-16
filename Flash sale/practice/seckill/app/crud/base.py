from typing import Generic, TypeVar, Type
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete
from sqlalchemy.orm import DeclarativeBase

ModeType = TypeVar("ModeType", bound=DeclarativeBase)


class CRUDBase(Generic[ModeType]):
    """
    通用CRUD  基类
    """
    def __init__(self, model: Type[ModeType]):
        self.model = model

    # 异步获取
    async def get(self, db: AsyncSession, id: int) -> ModeType | None:
        """根据id查询单个对象"""
        result = await db.execute(select(self.model).where(self.model.id == id))
        # 取一条结果没有就返回None 不会抛异常
        return result.scalar_one_or_none()

    async def get_multi(
            self,
            db: AsyncSession,
            *,
            skip: int = 0,
            limit: int = 100,
    ) -> list[ModeType]:
        """
        分页获取多个对象
        """
        result = await db.execute(select(self.model).offset(skip).limit(limit))
        return result.scalars().all()

    async def create(
            self,
            db: AsyncSession,
            *,
            obj_in: dict
        ) -> ModeType:
        """创建对象"""
        db_obj = self.model(**obj_in)
        db.add(db_obj)
        await db.commit()
        await db.refresh(db_obj)
        return db_obj

    async def update(
            self,
            db: AsyncSession,
            *,
            db_obj: ModeType,
            obj_in: dict
        ) -> ModeType:
        """更新对象"""
        for field, value in obj_in.items():
            if hasattr(db_obj, field):
                setattr(db_obj, field, value)
        db.add(db_obj)
        await db.commit()
        await db.refresh(db_obj)
        return db_obj

    async def delete(self, db: AsyncSession, *, id: int) -> ModeType | None:
        """删除对象"""
        # 先查后删
        db_obj = await self.get(db, id)
        if db_obj:
            await db.delete(db_obj)
            await db.commit()
        return db_obj
