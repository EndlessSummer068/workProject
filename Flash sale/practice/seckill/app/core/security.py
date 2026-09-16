from passlib.context import CryptContext
from datetime import datetime, timedelta, timezone
from typing import Optional
from jose import JWTError, jwt
from app.core.config import settings
from fastapi import HTTPException, status
# 安装：pip install passlib[bcrypt]==1.7.4 bcrypt==4.0.1
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """验证密码"""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """加密密码
    注意：bcrypt 算法最大支持 72 字节，超长的密码会被截断。
    这里用 [:72] 显式截断，避免新版 bcrypt（4.1+）抛异常。
    """
    return pwd_context.hash(password[:72])


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """生成 JWT Token
    Args:
    data: 要编码到 Token 里的数据，比如 {"sub": "用户名"}
    expires_delta: 过期时间，不传则使用配置里的默认值
    Returns:
    编码后的 JWT 字符串
    """
    to_encode = data.copy()

    # 计算过期时间
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)

    # 把过期时间加入payload
    to_encode.update({"exp": expire})

    # 用秘钥签名，生成token
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt


def verify_token(token: str):
    """验证 JWT Token
    Args:
    token: 要验证的 JWT Token 客户传来的
    Returns:
    验证通过则返回 payload（字典），失败返回None
    """
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        return payload
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="无效或过期的认证令牌",
            headers={"WWW-Authenticate": "Bearer"},
        )


"""
重点解释：
jwt.encode() ：把字典数据编码成 JWT 字符串，同时用 SECRET_KEY 签名
jwt.decode() ：验证签名并解码，如果签名不对或已过期，抛 JWTError
"sub" ：JWT 标准字段，表示 "subject"（主体），通常存用户标识
"exp" ：JWT 标准字段，表示过期时间（expiration）
datetime.now(timezone.utc) ：Python 3.11+ 推荐写法，带 UTC 时区
"""