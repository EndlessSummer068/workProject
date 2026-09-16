from fastapi import APIRouter, Query, Depends, HTTPException
from typing import List, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from app.schemas.goods import GoodsResponse, GoodsCreate
from app.core.response import success, ResponseModel
from app.db.session import get_db
from app.crud.goods import goods_crud

router = APIRouter(prefix="/goods", tags=["商品管理"])


@router.get("/list", response_model=ResponseModel[List[GoodsResponse]], summary="商品列表")
async def get_goods_list(
    # 页码参数，默认为1，限制最小值为1（ge=1）
    # 用于分页查询，表示要获取第几页的数据
    page: int = Query(1, ge=1, description="页码"),
    # 每页数量参数，默认为10，限制范围在1到100之间（ge=1, le=100）
    # 用于控制每页返回多少条商品记录
    size: int = Query(10, ge=1, le=100, description="每页数量"),
    # 可选搜索关键词，默认为None
    # 用于按商品名称、描述等字段进行模糊搜索
    keyword: Optional[str] = Query(None, description="搜索关键词"),
    db: AsyncSession = Depends(get_db)
):
    """
    获取商品列表，支持分页和搜索
    - **page**: 页码，从1开始
    - **size**: 每页数量，默认10，最大100
    - **keyword**: 按商品名称搜索
    """
    skip = (page - 1) * size
    goods_list = await goods_crud.get_multi(db, skip=skip, limit=size)

    return success(data=[GoodsResponse.model_validate(g) for g in goods_list])


@router.get("/{goods_id}", response_model=ResponseModel[GoodsResponse], summary="商品详情")
async def get_goods_detail(goods_id: int, db: AsyncSession = Depends(get_db)):
    """根据id获取商品详情"""
    goods = await goods_crud.get(db, goods_id)
    if not goods:
        raise HTTPException(status_code=404, detail="商品不存在")
    return success(data=GoodsResponse.model_validate(goods))


@router.post("/create", response_model=ResponseModel[GoodsResponse], summary="创建商品")
async def create_goods(goods: GoodsCreate, db: AsyncSession = Depends(get_db)):
    """创建商品"""
    db_goods = await goods_crud.create(db, obj_in=goods.model_dump())
    return success(data=GoodsResponse.model_validate(db_goods))
