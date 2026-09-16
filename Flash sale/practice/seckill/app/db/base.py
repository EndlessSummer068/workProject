from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from datetime import datetime
from sqlalchemy import func


class Base(DeclarativeBase):
    """Base模型 所有模型的积累"""
    pass


class BaseModel(Base):
    """带通用字段的抽象基类"""
    __abstract__ = True  # 抽象类，不会创建表

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    created_at: Mapped[datetime] = mapped_column(default=func.now())
    updated_at: Mapped[datetime] = mapped_column(default=func.now(), onupdate=func.now())

