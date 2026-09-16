from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from app.core.config import settings

# 创建异步引擎
engine = create_async_engine(
    settings.SQLALCHEMY_DATABASE_URL,
    echo=settings.DEBUG,  # 打印sql语句 调试时很有用
    pool_size=10,  # 数据库并发链接
    max_overflow=20,  # 抗瞬时流量
)
# 创建会话工厂
AsyncSessionLocal = async_sessionmaker(
    engine,  # 心脏
    class_=AsyncSession,  # 产品类型 负责具体的await操作
    expire_on_commit=False,  # 对象依然保留内存的数据 假设设置为True 相当于是一个事务SELECT查询
    autoflush=False,  # 完全由你自己掌控事务节奏 在秒杀优势中 防止复杂的扣库存逻辑中 因为中途的刷新导致锁表
)


async def get_db():
    """依赖注入用的数据库会话生成器"""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()

            