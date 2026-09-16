from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.schemas.user import UserCreate, UserResponse
from app.core.response import success, ResponseModel
from app.core.security import get_password_hash
from app.db.session import get_db
from app.crud.user import user_crud
from app.deps import get_current_user
from app.models.user import User

router = APIRouter(prefix="/users", tags=["用户管理"])


@router.post("/register", response_model=ResponseModel[UserResponse], summary="用户注册")
async def register(user_in: UserCreate, db: AsyncSession = Depends(get_db)):
    """用户注册"""
    # 1. 检查用户名是否已存在
    existing_user = await user_crud.get_by_username(db, username=user_in.username)
    if existing_user:
        raise HTTPException(status_code=400, detail="用户名已存在")

    # 2. 加密密码
    user_data = user_in.model_dump()
    user_data["password"] = get_password_hash(user_data["password"])

    # 3. 创建用户
    user = await user_crud.create(db, obj_in=user_data)
    return success(data=UserResponse.model_validate(user))


@router.get("/me", response_model=ResponseModel[UserResponse], summary="获取当前用户信息")
async def get_me(current_user: User = Depends(get_current_user)):
    """
    获取当前用户信息

    需要在请求头里带上 Authorization: Bearer <token>
    FastAPI 会自动：
    1. 从请求头提取 Token
    2. 调用 get_current_user 验证 Token
    3. 如果验证通过，current_user 就是登录的用户对象
    4. 如果验证失败，自动返回 401，不会执行到这里
    """
    return success(data=UserResponse.model_validate(current_user))
