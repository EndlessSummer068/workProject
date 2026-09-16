from typing import Generic, TypeVar, Optional
from pydantic import BaseModel

T = TypeVar("T")

class ResponseModel(BaseModel, Generic[T]):
    """统一响应式格式"""
    code: int
    message: str = "success"
    data: Optional[T] =  None

def success(data= None, message= "success"):
    """成功响应"""
    return ResponseModel(code=200, message=message, data=data)

def error(code= 400, message= "error"):
    """失败响应"""
    return ResponseModel(code=code, message=message, data=None)