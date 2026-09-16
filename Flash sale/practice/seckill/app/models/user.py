from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import String
from app.db.base import BaseModel


class User(BaseModel):
    """用户表"""
    __tablename__ = "users"
    username: Mapped[str] = mapped_column(String(50), unique=True, nullable=False, comment="用户名")
    password: Mapped[str] = mapped_column(String(255), nullable=False, comment="密码（加密后）")
    email: Mapped[str | None] = mapped_column(String(100), comment="邮箱")
