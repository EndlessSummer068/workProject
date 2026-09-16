from fastapi import Depends, HTTPException, status, Request
from fastapi.security import OAuth2PasswordBearer as _OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.security import verify_token
from app.db.session import get_db
from app.crud.user import user_crud


# 自定义 OAuth2PasswordBearer，让无 Token 时的错误信息变成中文
# 默认情况下，请求没带 Token 时，FastAPI 会返回英文 "Not authenticated"
# 通过继承并重写 __call__ 方法，我们可以把错误信息改成中文
class OAuth2PasswordBearer(_OAuth2PasswordBearer):
    async def __call__(self, request: Request) -> str:
        """重写 __call__ 方法"""
        try:
            return await super().__call__(request)
        except HTTPException:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="无效的认证凭据",
                headers={"WWW-Authenticate": "Bearer"},
            )


# 告诉 FastAPI：Token 从哪个地址获取
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
):
    """
    依赖注入函数：获取当前登录用户
    用法：在路由函数参数里写 `user = Depends(get_current_user)`
    如果用户没登录或 Token 无效，会自动返回 401
    这个函数做了三件事：
    1. 从请求头里提取 Token
    2. 验证 Token 是否有效
    3. 查数据库确认用户存在
    任何一步失败 → 抛 401 异常
    """
    # 定义 401 异常，后面复用
    # headers={"WWW-Authenticate": "Bearer"} 是 HTTP 标准响应头，
    # 告诉客户端："你需要用 Bearer Token 方式重新认证"
    # 规范要求：返回 401 时必须带这个头，否则不符合 OAuth2 标准
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="无效的认证凭据",
        headers={"WWW-Authenticate": "Bearer"},
    )

    # 1. 验证 Token 是否有效
    # verify_token() 会解码并验证签名，失败返回 None
    payload = verify_token(token)
    if payload is None:
        raise credentials_exception

    # 2. 从 Payload 里取用户名
    # "sub" 是 JWT 标准字段，表示 subject（主体）
    username = payload.get("sub")
    if username is None:
        raise credentials_exception

    # 3. 查数据库确认用户存在
    # Token 有效不代表用户没被删除，所以还要查一次数据库
    user = await user_crud.get_by_username(db, username=username)
    if user is None:
        raise credentials_exception

    # 全部成功，返回用户对象
    return user

"""
" get_current_user 是一个依赖函数，它自己也有依赖： token 和 db 。FastAPI 会自动帮你们一层层解析。

这个函数做了三件事：验 Token → 取用户名 → 查数据库。任何一步失败都返回 401。

注意：即使 Token 有效，我们也要查一次数据库确认用户没被删除。这是安全最佳实践。"
"""
