from pydantic_settings import BaseSettings
from functools import lru_cache


# BaseSettings 是pydantic 提供的配置的管理基类
class Settings(BaseSettings):
    """应用配置"""
    # 数据库
    SQLALCHEMY_DATABASE_URL: str = "mysql+aiomysql://root:123456@localhost:3306/seckill?charset=utf8mb4"
    DATABASE_URL: str = SQLALCHEMY_DATABASE_URL  # 新增

    # Redis配置
    REDIS_URL: str = "redis://localhost:6379/0"

    # 其他配置
    DEBUG: bool = False   # 生产环境必须关闭，否则终端会打印大量 SQL 日志
 
    # JWT 配置
    SECRET_KEY: str = "your-secret-key-here-change-it-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # Token 有效期：24小时

    class Config:
        env_file = ".env"


# 带缓存 不用每次都去读取数据库
@lru_cache()
def get_settings():
    return Settings()


settings = get_settings()


"""
SECRET_KEY 是 JWT 签名的密钥，生产环境一定要改，而且要足够复杂。泄露了这个密钥，别人
就能伪造 Token。
ALGORITHM 用 HS256 （HMAC + SHA256），这是 JWT 最常用的签名算法。
ACCESS_TOKEN_EXPIRE_MINUTES 设成 24 小时，教学方便。生产环境建议 15 分钟，配合
Refresh Token 使用。
"""