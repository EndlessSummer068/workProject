from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class UserBase(BaseModel):
    username: str = Field(..., min_length=1, max_length=50, description="用户名")
    email: Optional[str] = Field(None, description="邮箱")


class UserCreate(UserBase):
    password: str = Field(..., min_length=6, max_length=50, description="密码")


class UserResponse(UserBase):
    id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

