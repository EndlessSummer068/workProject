from datetime import timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.core.security import verify_password, create_access_token
from app.core.response import success, ResponseModel
from app.db.session import get_db
from app.crud.user import user_crud


router = APIRouter(prefix="/auth", tags=["认证管理"])

# OAuth2 密码流程的Token URL
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


@router.post("/login", summary="用户登录")
async def login(
        form_data: OAuth2PasswordRequestForm = Depends(),
        db: AsyncSession = Depends(get_db)
):
    """
    用户登录接口，使用 OAuth2 密码流程
    """
    # 1. 根据用户名查用户
    user = await user_crud.get_by_username(db, username=form_data.username)

    # 2. 合并验证：防止用户名枚举，同时兼容 OAuth2 规范
    if not user or not verify_password(form_data.password, user.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户名或密码错误",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # 3. 生成 JWT Token
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.username},
        expires_delta=access_token_expires
    )

    # 4. 重点修改：返回 OAuth2 标准格式（不加 success 外层封装）
    return {"access_token": access_token, "token_type": "bearer"}

"""
重点解释：
    OAuth2PasswordRequestForm ：FastAPI 封装的登录表单模型，自动解析 username 和 password
    OAuth2PasswordBearer(tokenUrl=...) ：告诉 FastAPI 去哪里获取 Token，Swagger 文档会自动显示登录按钮
    返回格式必须是 {"access_token": "...", "token_type": "bearer"} ，这是 OAuth2 标准
    headers={"WWW-Authenticate": "Bearer"} ：HTTP 401 的标准响应头
"注意这里有两个 Depends() ：
    Depends(OAuth2PasswordRequestForm) ：解析表单数据
    Depends(get_db) ：注入数据库会话
FastAPI 会自动按顺序处理这些依赖。"
"""