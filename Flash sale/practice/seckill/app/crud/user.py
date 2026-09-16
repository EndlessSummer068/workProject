from sqlalchemy import select
from app.crud.base import CRUDBase
from app.models.user import User
from app.db.session import AsyncSession


class CRUDUser(CRUDBase[User]):
    """用户管理"""
    async def get_by_username(self, db: AsyncSession, username: str) -> User | None:
        """根据用户名查询用户"""
        stmt = select(User).where(User.username == username)
        result = await db.execute(stmt)
        return result.scalar_one_or_none()


user_crud = CRUDUser(User)

