# TaskFlow 后端从0开发教程

---

## 第一章 · 项目创建与环境配置

### 1.1 创建 Django 项目

```bash
mkdir backend && cd backend
pip install django djangorestframework django-cors-headers channels mysqlclient daphne
django-admin startproject backend .
python manage.py startapp api
```

项目目录结构：

```
backend/
├── backend/          # 项目配置目录
│   ├── __init__.py
│   ├── settings.py
│   ├── urls.py
│   ├── asgi.py
│   └── wsgi.py
├── api/              # 应用目录
│   ├── __init__.py
│   ├── models.py
│   ├── views.py
│   ├── serializers.py
│   ├── urls.py
│   ├── auth_backends.py
│   ├── consumers.py
│   ├── routing.py
│   ├── admin.py
│   └── management/
│       ├── __init__.py
│       └── commands/
│           ├── __init__.py
│           └── init_data.py
└── manage.py
```

### 1.2 配置 settings.py

```python
# backend/settings.py

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',       # DRF 框架
    'corsheaders',          # 跨域处理
    'channels',             # WebSocket 支持
    'api',                  # 我们的应用
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'corsheaders.middleware.CorsMiddleware',   # 跨域中间件，必须放在 CommonMiddleware 之前
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]
```

**关键配置说明：**

```python
# 自定义用户模型，必须在使用 User 模型之前设置
AUTH_USER_MODEL = 'api.User'

# ASGI 应用入口，WebSocket 必须通过 ASGI 而非 WSGI 运行
ASGI_APPLICATION = 'backend.asgi.application'

# Channel Layers 配置，开发环境用内存，生产环境需换 Redis
CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels.layers.InMemoryChannelLayer',
    },
}

# MySQL 数据库配置
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': 'taskflow',
        'USER': 'taskflow',
        'PASSWORD': 'taskflow123',
        'HOST': '127.0.0.1',
        'PORT': '3306',
        'OPTIONS': {
            'charset': 'utf8mb4',   # 支持 emoji 和中文
        },
    }
}

# 媒体文件（用户上传的头像、附件等）
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

# CORS 跨域配置（前后端分离开发时必须）
CORS_ALLOW_ALL_ORIGINS = True      # 允许所有域名跨域
CORS_ALLOW_CREDENTIALS = True       # 允许携带 Cookie（Session 认证需要）

# DRF 全局配置
REST_FRAMEWORK = {
    # 使用自定义的 Session 认证（禁用 CSRF）
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'api.auth_backends.CsrfExemptSessionAuthentication',
    ],
    # 默认允许所有访问，具体权限在视图中单独设置
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.AllowAny',
    ],
    # 使用自定义异常处理器，统一返回 {success, message} 格式
    'EXCEPTION_HANDLER': 'api.auth_backends.custom_exception_handler',
}

# 时区和语言
LANGUAGE_CODE = 'zh-hans'
TIME_ZONE = 'Asia/Shanghai'
```

### 1.3 创建 MySQL 数据库

```sql
CREATE DATABASE taskflow CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'taskflow'@'127.0.0.1' IDENTIFIED BY 'taskflow123';
GRANT ALL PRIVILEGES ON taskflow.* TO 'taskflow'@'127.0.0.1';
FLUSH PRIVILEGES;
```

---

## 第二章 · 自定义用户模型与认证

### 2.1 用户模型

Django 自带的 User 模型字段有限，需要扩展添加角色、头像等字段：

```python
# api/models.py
from django.db import models
from django.contrib.auth.models import AbstractUser


class User(AbstractUser):
    """自定义用户模型，扩展角色、头像等字段"""

    ROLE_CHOICES = [
        ('client', '客户'),
        ('provider', '服务方'),
        ('admin', '管理员'),
    ]
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='client')
    phone = models.CharField(max_length=20, blank=True, default='')
    avatar = models.ImageField(upload_to='avatars/', blank=True, null=True)  # 上传到 media/avatars/
    bio = models.TextField(blank=True, default='')                           # 个人简介
    skills = models.CharField(max_length=200, blank=True, default='')        # 技能标签
    rating = models.FloatField(default=0)                                    # 平均评分
    completed_orders = models.IntegerField(default=0)                        # 完成订单数
    created_at = models.DateTimeField(auto_now_add=True)                     # 注册时间

    class Meta:
        db_table = 'tf_user'   # 自定义表名，避免默认的 api_user
```

**要点：**
- 继承 `AbstractUser`，保留 Django 原有的 username、password、email 等字段
- `role` 字段区分三种角色
- `avatar` 使用 `ImageField`，上传到 `media/avatars/` 目录
- `db_table` 自定义表名，避免默认的 `api_user`

### 2.2 认证后端

项目使用 Session 认证，但需要禁用 CSRF（前后端分离场景）并自定义异常处理：

```python
# api/auth_backends.py
from rest_framework.authentication import SessionAuthentication
from rest_framework import exceptions
from rest_framework.permissions import IsAuthenticated as BaseIsAuthenticated


def custom_exception_handler(exc, context):
    """自定义异常处理器，将 DRF 默认的英文错误转为统一的 {success, message} 格式"""
    from rest_framework.views import exception_handler as drf_exception_handler
    response = drf_exception_handler(exc, context)
    if response is not None:
        # 处理认证相关异常（401）
        if isinstance(exc, (exceptions.NotAuthenticated, exceptions.AuthenticationFailed)):
            if isinstance(response.data, dict) and 'detail' in response.data:
                response.data = {'success': False, 'message': response.data['detail']}
        # 处理权限相关异常（403）
        elif isinstance(exc, exceptions.PermissionDenied):
            if isinstance(response.data, dict) and 'detail' in response.data:
                response.data = {'success': False, 'message': response.data['detail']}
    return response


class CsrfExemptSessionAuthentication(SessionAuthentication):
    """自定义 Session 认证，禁用 CSRF 检查（前后端分离时需要）"""

    def enforce_csrf(self, request):
        # 空实现，跳过 CSRF 检查
        return

    def authenticate_header(self, request):
        # 返回认证方式名称，浏览器弹出认证框时显示
        return 'Session'

    def authenticate(self, request):
        result = super().authenticate(request)
        # 额外检查：被禁用的用户不允许通过认证
        if result and not result[0].is_active:
            raise exceptions.AuthenticationFailed('用户已被禁用。')
        return result


class IsAuthenticated(BaseIsAuthenticated):
    """自定义权限类，未登录时抛出 401 而非 403"""

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            raise exceptions.NotAuthenticated('身份认证信息未提供。')
        return True
```

**要点：**
- `CsrfExemptSessionAuthentication`：禁用 CSRF 检查，同时保留 Session 认证
- `authenticate` 方法中检查 `is_active`，禁用用户无法登录
- `custom_exception_handler`：将 DRF 默认的英文错误信息转为统一的 `{success, message}` 格式
- `IsAuthenticated`：未登录时抛出 `NotAuthenticated` 异常而非返回 403

### 2.3 用户序列化器

```python
# api/serializers.py
from rest_framework import serializers
from .models import User, Need, Order, Message, Review


class UserSerializer(serializers.ModelSerializer):
    """用户序列化器，用于返回和修改用户信息"""

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'role', 'phone', 'avatar', 'bio', 'skills', 'rating', 'completed_orders', 'is_active']
        read_only_fields = ['id', 'rating', 'completed_orders']   # 评分和完成数由系统自动计算

    def to_representation(self, instance):
        """将头像相对路径转为完整 URL，前端可直接用于 <img :src="">"""
        data = super().to_representation(instance)
        request = self.context.get('request')
        if request and data.get('avatar') and not str(data['avatar']).startswith('http'):
            scheme = 'https' if request.is_secure() else 'http'
            host = request.get_host()
            data['avatar'] = f"{scheme}://{host}{data['avatar']}"
        return data


class RegisterSerializer(serializers.ModelSerializer):
    """注册专用序列化器，密码只写不读"""

    password = serializers.CharField(write_only=True, min_length=6)   # 密码不会在响应中返回

    class Meta:
        model = User
        fields = ['username', 'password', 'email', 'role', 'phone']

    def validate_role(self, value):
        """禁止通过注册接口创建管理员账号"""
        if value == 'admin':
            raise serializers.ValidationError('注册不支持管理员角色')
        return value

    def create(self, validated_data):
        """使用 create_user 自动对密码做哈希处理"""
        user = User.objects.create_user(
            username=validated_data['username'],
            password=validated_data['password'],
            email=validated_data.get('email', ''),
            role=validated_data.get('role', 'client'),
            phone=validated_data.get('phone', ''),
        )
        return user
```

**要点：**
- `UserSerializer.to_representation`：将头像的相对路径转为完整 URL，前端可直接使用
- `RegisterSerializer`：注册专用，密码只写不读（`write_only=True`），禁止注册管理员角色
- `create_user`：Django 内置方法，自动对密码做哈希处理

### 2.4 认证接口

```python
# api/views.py
from django.db import models                                       # 用于 Q 查询
from django.contrib.auth import authenticate, login, logout
from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from .auth_backends import IsAuthenticated
from .models import User, Need, Order, Message, Review
from .serializers import (
    UserSerializer, RegisterSerializer, NeedSerializer,
    OrderSerializer, MessageSerializer, ReviewSerializer
)


def error_response(message, status_code):
    """统一的错误响应格式"""
    return Response({'success': False, 'message': message}, status=status_code)


def first_error(errors):
    """从序列化器的 errors 字典中提取第一条错误信息"""
    for field_msgs in errors.values():
        if isinstance(field_msgs, list) and field_msgs:
            return str(field_msgs[0])
        return str(field_msgs)
    return '请求参数错误'


class RegisterView(APIView):
    permission_classes = [AllowAny]   # 注册不需要登录

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            login(request, user)   # 注册成功后自动登录，创建 Session
            return Response({
                'success': True,
                'user': UserSerializer(user, context={'request': request}).data
            }, status=status.HTTP_201_CREATED)
        return error_response(first_error(serializer.errors), status.HTTP_400_BAD_REQUEST)


class LoginView(APIView):
    permission_classes = [AllowAny]   # 登录不需要登录

    def post(self, request):
        username = request.data.get('username', '')
        password = request.data.get('password', '')
        user = authenticate(request, username=username, password=password)
        if user is not None and user.is_active:   # 验证用户名密码，且账号未被禁用
            login(request, user)                   # 创建 Session
            return Response({
                'success': True,
                'user': UserSerializer(user, context={'request': request}).data
            })
        return error_response('账号或密码错误', status.HTTP_401_UNAUTHORIZED)


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]   # 需要登录才能退出

    def post(self, request):
        logout(request)   # 清除 Session
        return Response({'success': True})


class CurrentUserView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """获取当前登录用户的信息"""
        return Response(UserSerializer(request.user, context={'request': request}).data)

    def put(self, request):
        """修改当前用户信息（头像、用户名等）"""
        serializer = UserSerializer(request.user, data=request.data, partial=True, context={'request': request})
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return error_response(first_error(serializer.errors), status.HTTP_400_BAD_REQUEST)


class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        """修改密码，修改后需要重新登录（set_password 会使旧 Session 失效）"""
        old_password = request.data.get('old_password', '')
        new_password = request.data.get('new_password', '')
        if not old_password or not new_password:
            return error_response('请填写完整信息', status.HTTP_400_BAD_REQUEST)
        if not request.user.check_password(old_password):   # 验证旧密码
            return error_response('当前密码错误', status.HTTP_400_BAD_REQUEST)
        if len(new_password) < 6:
            return error_response('新密码至少6位', status.HTTP_400_BAD_REQUEST)
        request.user.set_password(new_password)   # 设置新密码（自动哈希）
        request.user.save()
        login(request, request.user)               # 重新登录，刷新 Session
        return Response({'success': True, 'message': '密码修改成功'})
```

**要点：**
- 注册成功后自动调用 `login()` 创建 Session，前端无需再次登录
- `CurrentUserView.put`：`partial=True` 允许部分更新（只传需要修改的字段）
- `ChangePasswordView`：修改密码后需要重新 `login()`，因为 `set_password` 会使旧 Session 失效
- `error_response` / `first_error`：统一的错误响应格式

---

## 第三章 · 需求与订单模型

### 3.1 需求模型

```python
# api/models.py（续）

class Need(models.Model):
    """需求模型，客户发布的需求信息"""

    STATUS_CHOICES = [
        ('pending', '待接单'),
        ('matched', '已匹配'),
        ('draft', '草稿'),
        ('in_progress', '进行中'),
        ('completed', '已完成'),
        ('cancelled', '已取消'),
    ]
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='needs')   # 需求发布者
    title = models.CharField(max_length=200)                                         # 需求标题
    type = models.CharField(max_length=50)                                           # 需求类型（网站开发、UI设计等）
    description = models.TextField(blank=True, default='')                           # 详细描述
    budget = models.CharField(max_length=50)                                         # 预算金额
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    attachment = models.FileField(upload_to='attachments/', blank=True, null=True)   # 附件
    created_at = models.DateTimeField(auto_now_add=True)                             # 创建时间
    updated_at = models.DateTimeField(auto_now=True)                                 # 更新时间

    class Meta:
        db_table = 'tf_need'
        ordering = ['-created_at']   # 默认按创建时间倒序
```

**要点：**
- `budget` 用 `CharField` 而非 `DecimalField`，因为前端传的是字符串
- `attachment` 用 `FileField`，上传到 `media/attachments/`
- `ordering = ['-created_at']` 默认按创建时间倒序

### 3.2 订单模型

```python
# api/models.py（续）

class Order(models.Model):
    """订单模型，关联需求、客户和服务方"""

    STATUS_CHOICES = [
        ('pending', '待接单'),
        ('in_progress', '进行中'),
        ('completed', '待客户支付'),
        ('paid', '已支付'),
        ('reviewed', '已完成'),
        ('cancelled', '已取消'),
    ]
    need = models.ForeignKey(Need, on_delete=models.SET_NULL, null=True, blank=True, related_name='orders')      # 关联需求
    client = models.ForeignKey(User, on_delete=models.CASCADE, related_name='client_orders')                      # 客户
    provider = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='provider_orders')  # 服务方
    title = models.CharField(max_length=200)               # 订单标题
    amount = models.CharField(max_length=50)                # 金额
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    progress = models.IntegerField(default=0)               # 进度百分比 0-100
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'tf_order'
        ordering = ['-created_at']
```

**要点：**
- `need` 使用 `SET_NULL`：需求被删除时订单不删除，只是断开关联
- `provider` 使用 `SET_NULL` + `null=True`：创建需求时自动创建的 pending 订单还没有服务方
- 订单状态流转：`pending → in_progress → completed → paid → reviewed`

**核心业务逻辑：创建需求时自动创建 pending 订单**

```
客户发布需求 → 自动创建 pending 订单（provider=null）
服务方接单 → 更新该订单（设置 provider，状态改为 in_progress）
```

这样客户在"我的订单"中能看到 pending 状态的订单，服务方接单后订单状态更新。

### 3.3 消息模型

```python
# api/models.py（续）

class Message(models.Model):
    """消息模型，订单内的沟通记录"""

    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='messages')   # 关联订单
    sender = models.ForeignKey(User, on_delete=models.CASCADE)                            # 发送者
    text = models.TextField()                                                              # 消息内容
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'tf_message'
        ordering = ['created_at']   # 按时间正序，聊天记录从旧到新
```

### 3.4 评价模型

```python
# api/models.py（续）

class Review(models.Model):
    """评价模型，客户对完成订单的评价"""

    order = models.OneToOneField(Order, on_delete=models.CASCADE, related_name='review')   # 一个订单只能有一条评价
    reviewer = models.ForeignKey(User, on_delete=models.CASCADE)                            # 评价者
    rating = models.IntegerField()                                                          # 评分 1-5
    tags = models.CharField(max_length=200, blank=True, default='')                         # 评价标签，逗号分隔
    comment = models.TextField(blank=True, default='')                                      # 评价内容
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'tf_review'
```

**要点：**
- `OneToOneField`：一个订单只能有一条评价
- `tags`：逗号分隔的字符串，如 `"质量好,交付及时,沟通顺畅"`

### 3.5 执行迁移

```bash
python manage.py makemigrations
python manage.py migrate
```

---

## 第四章 · 序列化器

### 4.1 需求序列化器

```python
# api/serializers.py（续）

class NeedSerializer(serializers.ModelSerializer):
    """需求序列化器，额外返回发布者用户名"""

    username = serializers.CharField(source='user.username', read_only=True)   # 从关联的 User 中取 username

    class Meta:
        model = Need
        fields = ['id', 'user', 'username', 'title', 'type', 'description', 'budget', 'status', 'attachment']
        read_only_fields = ['id', 'user']   # id 和 user 不允许前端修改
```

**要点：**
- `source='user.username'`：从关联的 User 对象中取 username 字段
- `read_only_fields`：id 和 user 不允许前端修改

### 4.2 订单序列化器

```python
# api/serializers.py（续）

class OrderSerializer(serializers.ModelSerializer):
    """订单序列化器，额外返回客户/服务方名称和需求附件"""

    client_name = serializers.CharField(source='client.username', read_only=True)
    provider_name = serializers.CharField(source='provider.username', read_only=True, default=None)   # provider 可能为空
    need_title = serializers.CharField(source='need.title', read_only=True, default=None)
    need_attachment = serializers.FileField(source='need.attachment', read_only=True, default=None)
    need_attachment_url = serializers.SerializerMethodField()   # 自定义方法生成完整 URL

    def get_need_attachment_url(self, obj):
        """将附件相对路径转为完整 URL"""
        if obj.need and obj.need.attachment:
            request = self.context.get('request')
            if request:
                scheme = 'https' if request.is_secure() else 'http'
                host = request.get_host()
                return f"{scheme}://{host}{obj.need.attachment.url}"
            return obj.need.attachment.url
        return None

    class Meta:
        model = Order
        fields = ['id', 'need', 'need_title', 'need_attachment', 'need_attachment_url', 'client', 'client_name', 'provider', 'provider_name', 'title', 'amount', 'status', 'progress']
        read_only_fields = ['id']
```

**要点：**
- `source='provider.username', default=None`：provider 可能为空（pending 订单），用 `default=None`
- `need_attachment_url`：用 `SerializerMethodField` 将附件路径转为完整 URL
- 序列化器中需要 `context={'request': request}` 才能获取 host 拼接 URL

### 4.3 消息序列化器

```python
# api/serializers.py（续）

class MessageSerializer(serializers.ModelSerializer):
    """消息序列化器，额外返回发送者名称、角色和头像"""

    sender_name = serializers.CharField(source='sender.username', read_only=True)
    sender_role = serializers.CharField(source='sender.role', read_only=True)
    sender_avatar = serializers.SerializerMethodField()   # 自定义方法生成完整头像 URL

    def get_sender_avatar(self, obj):
        """将发送者头像相对路径转为完整 URL"""
        request = self.context.get('request')
        if obj.sender.avatar:
            if request and not str(obj.sender.avatar.url).startswith('http'):
                scheme = 'https' if request.is_secure() else 'http'
                host = request.get_host()
                return f"{scheme}://{host}{obj.sender.avatar.url}"
            return obj.sender.avatar.url
        return None

    class Meta:
        model = Message
        fields = ['id', 'order', 'sender', 'sender_name', 'sender_role', 'sender_avatar', 'text']
        read_only_fields = ['id', 'sender']   # sender 由后端自动设置
```

### 4.4 评价序列化器

```python
# api/serializers.py（续）

class ReviewSerializer(serializers.ModelSerializer):
    """评价序列化器"""

    class Meta:
        model = Review
        fields = ['id', 'order', 'reviewer', 'rating', 'tags', 'comment']
        read_only_fields = ['id', 'reviewer']   # reviewer 由后端自动设置
```

---

## 第五章 · 视图与接口

### 5.1 用户管理接口

```python
# api/views.py（续）

class UserListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """获取用户列表（仅管理员），支持角色筛选和模糊搜索"""
        if request.user.role != 'admin':
            return error_response('无权限', status.HTTP_403_FORBIDDEN)
        users = User.objects.all()
        # 按角色筛选
        role = request.query_params.get('role')
        if role:
            users = users.filter(role=role)
        # 按用户名模糊搜索
        search = request.query_params.get('search')
        if search:
            users = users.filter(username__icontains=search)
        serializer = UserSerializer(users, many=True, context={'request': request})
        return Response(serializer.data)


class UserDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        """获取单个用户详情"""
        try:
            user = User.objects.get(pk=pk)
            return Response(UserSerializer(user, context={'request': request}).data)
        except User.DoesNotExist:
            return error_response('用户不存在', status.HTTP_404_NOT_FOUND)

    def put(self, request, pk):
        """修改用户信息（管理员可修改任何用户，普通用户只能修改自己）"""
        if request.user.role != 'admin' and request.user.id != pk:
            return error_response('无权限', status.HTTP_403_FORBIDDEN)
        try:
            user = User.objects.get(pk=pk)
            serializer = UserSerializer(user, data=request.data, partial=True, context={'request': request})
            if serializer.is_valid():
                serializer.save()
                return Response(serializer.data)
            return error_response(first_error(serializer.errors), status.HTTP_400_BAD_REQUEST)
        except User.DoesNotExist:
            return error_response('用户不存在', status.HTTP_404_NOT_FOUND)

    def delete(self, request, pk):
        """删除用户（仅管理员）"""
        if request.user.role != 'admin':
            return error_response('无权限', status.HTTP_403_FORBIDDEN)
        try:
            user = User.objects.get(pk=pk)
            user.delete()
            return Response({'success': True})
        except User.DoesNotExist:
            return error_response('用户不存在', status.HTTP_404_NOT_FOUND)
```

### 5.2 需求接口

```python
# api/views.py（续）

class NeedListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """获取需求列表，支持状态、用户、类型筛选"""
        needs = Need.objects.all()
        status_filter = request.query_params.get('status')
        if status_filter:
            needs = needs.filter(status=status_filter)
        user_id = request.query_params.get('user')
        if user_id:
            needs = needs.filter(user_id=user_id)
        need_type = request.query_params.get('type')
        if need_type:
            needs = needs.filter(type=need_type)
        serializer = NeedSerializer(needs, many=True)
        return Response(serializer.data)

    def post(self, request):
        """创建需求，同时自动创建一个 pending 状态的订单"""
        serializer = NeedSerializer(data=request.data)
        if serializer.is_valid():
            need = serializer.save(user=request.user)   # 保存需求，设置发布者为当前用户
            # 核心逻辑：创建需求时自动创建 pending 订单
            Order.objects.create(
                need=need,
                client=request.user,
                title=need.title,
                amount=str(need.budget) if need.budget else '0',
                status='pending',     # 待接单状态
                progress=0,
            )
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return error_response(first_error(serializer.errors), status.HTTP_400_BAD_REQUEST)


class NeedDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        """获取需求详情"""
        try:
            need = Need.objects.get(pk=pk)
            return Response(NeedSerializer(need).data)
        except Need.DoesNotExist:
            return error_response('需求不存在', status.HTTP_404_NOT_FOUND)

    def put(self, request, pk):
        """修改需求（仅创建者或管理员）"""
        try:
            need = Need.objects.get(pk=pk)
            if need.user != request.user and request.user.role != 'admin':
                return error_response('无权限', status.HTTP_403_FORBIDDEN)
            serializer = NeedSerializer(need, data=request.data, partial=True)
            if serializer.is_valid():
                serializer.save()
                return Response(serializer.data)
            return error_response(first_error(serializer.errors), status.HTTP_400_BAD_REQUEST)
        except Need.DoesNotExist:
            return error_response('需求不存在', status.HTTP_404_NOT_FOUND)

    def delete(self, request, pk):
        """删除需求（仅创建者或管理员）"""
        try:
            need = Need.objects.get(pk=pk)
            if need.user != request.user and request.user.role != 'admin':
                return error_response('无权限', status.HTTP_403_FORBIDDEN)
            need.delete()
            return Response({'success': True})
        except Need.DoesNotExist:
            return error_response('需求不存在', status.HTTP_404_NOT_FOUND)
```

### 5.3 接单接口

```python
# api/views.py（续）

class NeedAcceptView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        """服务方接单，更新已存在的 pending 订单为 in_progress"""
        try:
            need = Need.objects.get(pk=pk)
        except Need.DoesNotExist:
            return error_response('需求不存在', status.HTTP_404_NOT_FOUND)
        # 只有待接单的需求才能接单
        if need.status != 'pending':
            return error_response('该需求不可接单', status.HTTP_400_BAD_REQUEST)
        # 只有服务方和管理员可以接单
        if request.user.role not in ('provider', 'admin'):
            return error_response('仅服务方可接单', status.HTTP_403_FORBIDDEN)
        amount = request.data.get('amount', need.budget)
        # 核心逻辑：get_or_create 避免重复创建订单
        # 如果该 need 已有订单（创建需求时自动创建的），则更新它
        # 如果没有订单（兼容旧数据），则创建新订单
        order, created = Order.objects.get_or_create(
            need=need,
            defaults={
                'client': need.user,
                'provider': request.user,
                'title': need.title,
                'amount': str(amount),
                'status': 'in_progress',
                'progress': 0,
            },
        )
        if not created:
            # 订单已存在，更新服务方和状态
            order.provider = request.user
            order.amount = str(amount)
            order.status = 'in_progress'
            order.save()
        # 将需求状态设为已匹配
        need.status = 'matched'
        need.save()
        return Response({
            'success': True,
            'order': OrderSerializer(order, context={'request': request}).data
        })
```

**核心逻辑 — `get_or_create`：**

```python
order, created = Order.objects.get_or_create(
    need=need,
    defaults={...},
)
if not created:
    order.provider = request.user
    order.status = 'in_progress'
    order.save()
```

- 如果该 need 已有订单（创建需求时自动创建的 pending 订单），则更新它
- 如果没有订单（兼容旧数据），则创建新订单
- 这样避免了重复创建订单的问题

### 5.4 订单接口

```python
# api/views.py（续）

class OrderListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """获取订单列表，管理员看全部，普通用户只看自己的"""
        orders = Order.objects.all()
        if request.user.role == 'admin':
            # 管理员可按客户/服务方筛选
            client_id = request.query_params.get('client')
            if client_id:
                orders = orders.filter(client_id=client_id)
            provider_id = request.query_params.get('provider')
            if provider_id:
                orders = orders.filter(provider_id=provider_id)
        else:
            # 普通用户只能看到自己作为客户或服务方的订单
            orders = orders.filter(
                models.Q(client=request.user) | models.Q(provider=request.user)
            )
        # 状态筛选（支持中文值，如"进行中"）
        status_filter = request.query_params.get('status')
        if status_filter:
            status_map = dict(Order.STATUS_CHOICES)
            reverse_map = {v: k for k, v in status_map.items()}   # 中文→英文映射
            status_value = reverse_map.get(status_filter, status_filter)
            orders = orders.filter(status=status_value)
        # 模糊搜索（按订单ID或需求标题）
        search = request.query_params.get('search')
        if search:
            orders = orders.filter(
                models.Q(id__icontains=search) | models.Q(need__title__icontains=search)
            )
        serializer = OrderSerializer(orders.order_by('-id'), many=True, context={'request': request})
        return Response(serializer.data)

    def post(self, request):
        """创建订单（一般不直接调用，由创建需求或接单时自动创建）"""
        serializer = OrderSerializer(data=request.data, context={'request': request})
        if serializer.is_valid():
            order = serializer.save()
            # 如果关联的需求还是 pending 状态，自动改为 matched
            if order.need and order.need.status == 'pending':
                order.need.status = 'matched'
                order.need.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return error_response(first_error(serializer.errors), status.HTTP_400_BAD_REQUEST)
```

**要点：**
- 管理员可看所有订单，普通用户只能看自己作为客户或服务方的订单
- `models.Q` 实现 OR 查询：`Q(client=user) | Q(provider=user)`
- 状态筛选支持中文值（如"进行中"），通过 `reverse_map` 转换为英文键值

### 5.5 订单详情接口

```python
# api/views.py（续）

class OrderDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        """获取订单详情（仅订单相关方可访问）"""
        try:
            order = Order.objects.get(pk=pk)
            if request.user.role != 'admin' and order.client != request.user and order.provider != request.user:
                return error_response('无权限', status.HTTP_403_FORBIDDEN)
            return Response(OrderSerializer(order, context={'request': request}).data)
        except Order.DoesNotExist:
            return error_response('订单不存在', status.HTTP_404_NOT_FOUND)

    def put(self, request, pk):
        """修改订单（更新状态、进度等）"""
        try:
            order = Order.objects.get(pk=pk)
            if request.user.role != 'admin' and order.client != request.user and order.provider != request.user:
                return error_response('无权限', status.HTTP_403_FORBIDDEN)
            serializer = OrderSerializer(order, data=request.data, partial=True, context={'request': request})
            if serializer.is_valid():
                old_status = order.status
                serializer.save()
                # 订单变为 reviewed 时，自动增加服务方的完成订单计数
                if old_status != 'reviewed' and request.data.get('status') == 'reviewed' and order.provider:
                    order.provider.completed_orders += 1
                    order.provider.save()
                return Response(serializer.data)
            return error_response(first_error(serializer.errors), status.HTTP_400_BAD_REQUEST)
        except Order.DoesNotExist:
            return error_response('订单不存在', status.HTTP_404_NOT_FOUND)
```

**要点：**
- 权限检查：管理员、订单的客户、订单的服务方才能访问
- 订单状态变为 `reviewed` 时，自动增加服务方的 `completed_orders` 计数

### 5.6 消息接口

```python
# api/views.py（续）

class MessageListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """获取指定订单的消息记录"""
        order_id = request.query_params.get('order')
        if not order_id:
            return error_response('请指定订单ID', status.HTTP_400_BAD_REQUEST)
        # 验证订单存在且用户有权限
        try:
            order = Order.objects.get(pk=order_id)
            if request.user.role != 'admin' and order.client != request.user and order.provider != request.user:
                return error_response('无权限', status.HTTP_403_FORBIDDEN)
        except Order.DoesNotExist:
            return error_response('订单不存在', status.HTTP_404_NOT_FOUND)
        messages = Message.objects.filter(order_id=order_id)
        serializer = MessageSerializer(messages, many=True, context={'request': request})
        return Response(serializer.data)

    def post(self, request):
        """发送消息（HTTP 方式，WebSocket 是另一种方式）"""
        order_id = request.data.get('order')
        if order_id:
            try:
                order = Order.objects.get(pk=order_id)
                if request.user.role != 'admin' and order.client != request.user and order.provider != request.user:
                    return error_response('无权限', status.HTTP_403_FORBIDDEN)
            except Order.DoesNotExist:
                return error_response('订单不存在', status.HTTP_404_NOT_FOUND)
        serializer = MessageSerializer(data=request.data, context={'request': request})
        if serializer.is_valid():
            serializer.save(sender=request.user)   # 发送者设为当前用户
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return error_response(first_error(serializer.errors), status.HTTP_400_BAD_REQUEST)
```

### 5.7 评价接口

```python
# api/views.py（续）

class ReviewListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """获取评价列表，可按订单筛选"""
        reviews = Review.objects.all()
        order_id = request.query_params.get('order')
        if order_id:
            # 按订单筛选，需验证权限
            try:
                order = Order.objects.get(pk=order_id)
                if request.user.role != 'admin' and order.client != request.user and order.provider != request.user:
                    return error_response('无权限', status.HTTP_403_FORBIDDEN)
            except Order.DoesNotExist:
                return error_response('订单不存在', status.HTTP_404_NOT_FOUND)
            reviews = reviews.filter(order_id=order_id)
        elif request.user.role != 'admin':
            # 非管理员不指定订单时，只能看自己相关订单的评价
            reviews = reviews.filter(
                models.Q(order__client=request.user) | models.Q(order__provider=request.user)
            )
        serializer = ReviewSerializer(reviews, many=True)
        return Response(serializer.data)

    def post(self, request):
        """创建评价，同时更新订单状态和服务方评分"""
        order_id = request.data.get('order')
        if order_id:
            try:
                order = Order.objects.get(pk=order_id)
                if request.user.role != 'admin' and order.client != request.user and order.provider != request.user:
                    return error_response('无权限', status.HTTP_403_FORBIDDEN)
            except Order.DoesNotExist:
                return error_response('订单不存在', status.HTTP_404_NOT_FOUND)
        serializer = ReviewSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save(reviewer=request.user)
            # 评价创建后，自动将订单状态改为 reviewed
            order = serializer.instance.order
            order.status = 'reviewed'
            order.save(update_fields=['status', 'updated_at'])
            # 重新计算服务方的平均评分
            provider = order.provider
            if provider:
                all_reviews = Review.objects.filter(order__provider=provider)
                avg_rating = sum(r.rating for r in all_reviews) / all_reviews.count()
                provider.rating = round(avg_rating, 1)
                provider.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return error_response(first_error(serializer.errors), status.HTTP_400_BAD_REQUEST)
```

**要点：**
- 创建评价后自动将订单状态改为 `reviewed`
- 自动计算服务方的平均评分

### 5.8 统计接口

```python
# api/views.py（续）

class DashboardStatsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """根据用户角色返回不同的统计数据"""
        user = request.user
        if user.role == 'client':
            # 客户统计：进行中订单数、待接单需求数、已完成订单数、总消费
            client_orders = Order.objects.filter(client=user)
            client_needs = Need.objects.filter(user=user)
            stats = {
                'in_progress_orders': client_orders.filter(status='in_progress').count(),
                'pending_needs': client_needs.filter(status='pending').count(),
                'completed_orders': client_orders.filter(status__in=['completed', 'paid', 'reviewed']).count(),
                'total_spent': sum(int(o.amount.replace(',', '')) for o in client_orders.filter(status__in=['paid', 'completed', 'reviewed']) if o.amount),
            }
        elif user.role == 'provider':
            # 服务方统计：进行中订单数、已完成订单数、月收入、平均评分
            provider_orders = Order.objects.filter(provider=user)
            stats = {
                'in_progress_orders': provider_orders.filter(status='in_progress').count(),
                'completed_orders': provider_orders.filter(status__in=['completed', 'paid', 'reviewed']).count(),
                'monthly_income': sum(int(o.amount.replace(',', '')) for o in provider_orders.filter(status__in=['completed', 'paid', 'reviewed']) if o.amount),
                'avg_rating': user.rating,
            }
        elif user.role == 'admin':
            # 管理员统计：总用户数、总订单数、总收入、需求类型分布、订单状态分布
            from django.db.models import Count
            all_orders = Order.objects.all()
            all_needs = Need.objects.all()
            all_users = User.objects.all()
            completed_orders = all_orders.filter(status__in=['completed', 'paid', 'reviewed'])
            revenue = 0
            for o in completed_orders:
                try:
                    revenue += int(str(o.amount).replace(',', ''))
                except (ValueError, TypeError):
                    pass
            # 按需求类型分组计数
            type_counts = list(all_needs.values('type').annotate(count=Count('id')).order_by('-count'))
            # 按订单状态分组计数
            status_counts = list(all_orders.values('status').annotate(count=Count('id')).order_by('-count'))
            stats = {
                'total_users': all_users.count(),
                'total_orders': all_orders.count(),
                'total_needs': all_needs.count(),
                'total_revenue': revenue,
                'in_progress_orders': all_orders.filter(status='in_progress').count(),
                'completed_orders': completed_orders.count(),
                'type_distribution': [{'name': t['type'] or '其他', 'count': t['count']} for t in type_counts],
                'status_distribution': [{'name': dict(Order.STATUS_CHOICES).get(s['status'], s['status']), 'count': s['count']} for s in status_counts],
            }
        else:
            stats = {}
        return Response(stats)
```

**要点：**
- 根据角色返回不同的统计数据
- 管理员使用 `annotate` + `Count` 做聚合统计
- `values('type').annotate(count=Count('id'))` 按类型分组计数

---

## 第六章 · URL 路由

### 6.1 应用路由

```python
# api/urls.py
from django.urls import path
from . import views

urlpatterns = [
    # 认证相关
    path('auth/register/', views.RegisterView.as_view(), name='register'),
    path('auth/login/', views.LoginView.as_view(), name='login'),
    path('auth/logout/', views.LogoutView.as_view(), name='logout'),
    path('auth/me/', views.CurrentUserView.as_view(), name='current-user'),
    path('auth/change-password/', views.ChangePasswordView.as_view(), name='change-password'),
    # 用户管理
    path('users/', views.UserListView.as_view(), name='user-list'),
    path('users/<int:pk>/', views.UserDetailView.as_view(), name='user-detail'),
    # 需求管理
    path('needs/', views.NeedListCreateView.as_view(), name='need-list'),
    path('needs/<int:pk>/', views.NeedDetailView.as_view(), name='need-detail'),
    path('needs/<int:pk>/accept/', views.NeedAcceptView.as_view(), name='need-accept'),
    # 订单管理
    path('orders/', views.OrderListCreateView.as_view(), name='order-list'),
    path('orders/<int:pk>/', views.OrderDetailView.as_view(), name='order-detail'),
    # 消息和评价
    path('messages/', views.MessageListCreateView.as_view(), name='message-list'),
    path('reviews/', views.ReviewListCreateView.as_view(), name='review-list'),
    # 统计
    path('stats/', views.DashboardStatsView.as_view(), name='dashboard-stats'),
]
```

### 6.2 项目路由

```python
# backend/urls.py
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),       # Django Admin 后台
    path('api/', include('api.urls')),      # API 接口
]

# 开发环境下自动处理媒体文件请求
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
```

**要点：**
- `static()` 仅在 DEBUG 模式下生效，生产环境需要 Nginx 等处理媒体文件

---

## 第七章 · WebSocket 实时聊天

### 7.1 安装与配置

```bash
pip install channels
```

```python
# backend/settings.py
INSTALLED_APPS = [
    ...
    'channels',             # WebSocket 支持
]

ASGI_APPLICATION = 'backend.asgi.application'   # 使用 ASGI 而非 WSGI

CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels.layers.InMemoryChannelLayer',   # 开发环境用内存
    },
}
```

### 7.2 ASGI 配置

```python
# backend/asgi.py
import os
from django.core.asgi import get_asgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')

# 必须先调用 get_asgi_application，再导入 channels 相关模块
django_asgi_app = get_asgi_application()

from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack
from api.routing import websocket_urlpatterns

application = ProtocolTypeRouter({
    'http': django_asgi_app,                    # HTTP 请求走 Django
    'websocket': AuthMiddlewareStack(            # WebSocket 请求走 Channels
        URLRouter(websocket_urlpatterns)
    ),
})
```

**要点：**
- `get_asgi_application()` 必须在导入 channels 之前调用
- `AuthMiddlewareStack` 将 Django Session 认证应用到 WebSocket
- `ProtocolTypeRouter` 根据协议类型分发到 HTTP 或 WebSocket

### 7.3 WebSocket 路由

```python
# api/routing.py
from django.urls import re_path
from .consumers import ChatConsumer

websocket_urlpatterns = [
    re_path(r'ws/chat/(?P<order_id>\d+)/$', ChatConsumer.as_asgi()),   # 使用 re_path 支持正则
]
```

### 7.4 WebSocket Consumer

```python
# api/consumers.py
import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from api.models import Order, Message, User


class ChatConsumer(AsyncWebsocketConsumer):
    """WebSocket 聊天消费者，处理订单内的实时通信"""

    async def connect(self):
        """客户端连接时调用，验证身份和权限"""
        self.order_id = self.scope['url_route']['kwargs']['order_id']
        self.group_name = f'chat_order_{self.order_id}'   # 每个订单一个聊天组
        user = self.scope.get('user')
        # 未登录则拒绝连接
        if not user or not user.is_authenticated:
            await self.close()
            return
        # 无权限则拒绝连接
        if not await self._has_permission(user):
            await self.close()
            return
        # 加入聊天组
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()   # 接受连接

    async def disconnect(self, close_code):
        """客户端断开时调用，离开聊天组"""
        await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def receive(self, text_data):
        """收到客户端消息时调用，保存并广播"""
        user = self.scope.get('user')
        if not user or not user.is_authenticated:
            return
        data = json.loads(text_data)
        text = data.get('text', '').strip()
        if not text:
            return
        # 保存消息到数据库
        msg = await self._save_message(user, text)
        # 广播给同组的所有人
        await self.channel_layer.group_send(self.group_name, {
            'type': 'chat_message',    # 对应下面的 chat_message 方法
            'message': msg,
        })

    async def chat_message(self, event):
        """收到组内广播后发送给当前客户端"""
        await self.send(text_data=json.dumps(event['message']))

    @database_sync_to_async
    def _has_permission(self, user):
        """检查用户是否有权访问该订单的聊天（同步数据库操作需包装）"""
        try:
            order = Order.objects.get(pk=self.order_id)
            return user.role == 'admin' or order.client == user or order.provider == user
        except Order.DoesNotExist:
            return False

    @database_sync_to_async
    def _save_message(self, user, text):
        """保存消息到数据库并返回消息数据（同步数据库操作需包装）"""
        msg = Message.objects.create(order_id=self.order_id, sender=user, text=text)
        # 拼接头像完整 URL
        avatar_url = None
        if user.avatar:
            scheme = 'https' if self.scope.get('scheme') == 'wss' else 'http'
            host = self.scope.get('server', ('127.0.0.1', 8000))
            port = host[1]
            # 标准端口不显示端口号
            if (scheme == 'http' and port == 80) or (scheme == 'https' and port == 443):
                base = f"{scheme}://{host[0]}"
            else:
                base = f"{scheme}://{host[0]}:{port}"
            avatar_url = f"{base}{user.avatar.url}"
        return {
            'id': msg.id,
            'order': self.order_id,
            'sender': user.id,
            'sender_name': user.username,
            'sender_role': user.role,
            'sender_avatar': avatar_url,
            'text': text,
        }
```

**要点：**
- `connect`：验证用户身份和权限，加入订单聊天组
- `receive`：接收消息，保存到数据库，广播给同组所有人
- `chat_message`：收到组内广播后发送给客户端
- `@database_sync_to_async`：在异步 Consumer 中执行同步的数据库操作
- `group_send` + `group_add`：Channel Layers 实现同订单多人聊天

---

## 第八章 · Admin 后台与测试数据

### 8.1 Admin 注册

```python
# api/admin.py
from django.contrib import admin
from .models import User, Need, Order, Message, Review

admin.site.register(User)
admin.site.register(Need)
admin.site.register(Order)
admin.site.register(Message)
admin.site.register(Review)
```

### 8.2 测试数据初始化命令

```python
# api/management/commands/init_data.py
from django.core.management.base import BaseCommand
from api.models import User, Need, Order, Message


class Command(BaseCommand):
    help = '初始化测试数据'

    def handle(self, *args, **options):
        self.stdout.write('开始创建测试数据...')

        # 创建三个测试用户
        users_data = [
            ('admin', 'admin123', 'admin', 'admin@taskflow.com'),
            ('testclient', 'client123', 'client', ''),
            ('testprovider', 'provider123', 'provider', ''),
        ]

        for username, password, role, email in users_data:
            if not User.objects.filter(username=username).exists():
                user = User.objects.create_user(username=username, password=password, role=role, email=email)
                self.stdout.write(f'  创建用户: {username} ({role})')
            else:
                self.stdout.write(f'  用户已存在: {username}')

        client = User.objects.get(username='testclient')
        provider = User.objects.get(username='testprovider')

        # 创建三条测试需求
        needs_data = [
            {
                'title': '设计一个企业官网',
                'type': '网站开发',
                'description': '需要一个响应式的企业官网，包含首页、关于我们、产品展示、联系方式等页面。',
                'budget': '5000',
                'status': 'pending',
            },
            {
                'title': '开发一个微信小程序',
                'type': '小程序开发',
                'description': '需要一个电商类微信小程序，支持商品浏览、购物车、下单支付等功能。',
                'budget': '8000',
                'status': 'pending',
            },
            {
                'title': 'UI界面设计',
                'type': 'UI/UX设计',
                'description': '需要为一个移动端App设计UI界面，包含20个左右的页面。',
                'budget': '3000',
                'status': 'matched',
            },
        ]

        for need_data in needs_data:
            if not Need.objects.filter(title=need_data['title']).exists():
                Need.objects.create(user=client, **need_data)
                self.stdout.write(f'  创建需求: {need_data["title"]}')

        # 为已匹配的需求创建 in_progress 订单和消息
        need_ui = Need.objects.filter(title='UI界面设计').first()
        if need_ui and not Order.objects.filter(title='UI界面设计').exists():
            order = Order.objects.create(
                need=need_ui,
                client=client,
                provider=provider,
                title='UI界面设计',
                amount='3000',
                status='in_progress',
                progress=60,
            )
            self.stdout.write('  创建订单: UI界面设计 (in_progress)')

            Message.objects.create(order=order, sender=client, text='你好，请问设计进度如何？')
            Message.objects.create(order=order, sender=provider, text='您好！目前进度60%，预计本周内完成。')
            self.stdout.write('  创建沟通记录: 2条')

        # 为待接单的需求创建 pending 订单
        need_web = Need.objects.filter(title='设计一个企业官网').first()
        if need_web and not Order.objects.filter(title='设计一个企业官网').exists():
            Order.objects.create(
                need=need_web,
                client=client,
                provider=None,       # 待接单，没有服务方
                title='设计一个企业官网',
                amount='5000',
                status='pending',
                progress=0,
            )
            self.stdout.write('  创建订单: 设计一个企业官网 (pending)')

        self.stdout.write(self.style.SUCCESS('\n测试数据创建完成！'))
        self.stdout.write('\n测试账号：')
        self.stdout.write('  管理员: admin / admin123')
        self.stdout.write('  客户: testclient / client123')
        self.stdout.write('  服务方: testprovider / provider123')
```

**使用方式：**

```bash
python manage.py init_data
```

---

## 第九章 · 启动与验证

### 9.1 启动服务

```bash
# 执行迁移
python manage.py makemigrations
python manage.py migrate

# 创建测试数据
python manage.py init_data

# 启动服务（使用 daphne 支持 WebSocket，不能用 python manage.py runserver）
daphne -p 8000 backend.asgi:application
```

### 9.2 验证接口

```bash
# 登录获取 Session
curl -X POST http://127.0.0.1:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' \
  -c cookies.txt

# 获取用户列表
curl http://127.0.0.1:8000/api/users/ -b cookies.txt

# 获取订单列表
curl http://127.0.0.1:8000/api/orders/ -b cookies.txt

# 获取统计数据
curl http://127.0.0.1:8000/api/stats/ -b cookies.txt
```

---

## 附录 · 完整接口清单

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| POST | /api/auth/register/ | 注册 | 无需登录 |
| POST | /api/auth/login/ | 登录 | 无需登录 |
| POST | /api/auth/logout/ | 退出 | 需登录 |
| GET | /api/auth/me/ | 获取当前用户 | 需登录 |
| PUT | /api/auth/me/ | 修改当前用户 | 需登录 |
| POST | /api/auth/change-password/ | 修改密码 | 需登录 |
| GET | /api/users/ | 用户列表 | 管理员 |
| GET | /api/users/{id}/ | 用户详情 | 需登录 |
| PUT | /api/users/{id}/ | 修改用户 | 管理员/本人 |
| DELETE | /api/users/{id}/ | 删除用户 | 管理员 |
| GET | /api/needs/ | 需求列表 | 需登录 |
| POST | /api/needs/ | 创建需求 | 需登录 |
| GET | /api/needs/{id}/ | 需求详情 | 需登录 |
| PUT | /api/needs/{id}/ | 修改需求 | 需求创建者/管理员 |
| DELETE | /api/needs/{id}/ | 删除需求 | 需求创建者/管理员 |
| POST | /api/needs/{id}/accept/ | 接单 | 服务方/管理员 |
| GET | /api/orders/ | 订单列表 | 需登录 |
| POST | /api/orders/ | 创建订单 | 需登录 |
| GET | /api/orders/{id}/ | 订单详情 | 订单相关方 |
| PUT | /api/orders/{id}/ | 修改订单 | 订单相关方 |
| GET | /api/messages/?order={id} | 消息列表 | 订单相关方 |
| POST | /api/messages/ | 发送消息 | 订单相关方 |
| GET | /api/reviews/?order={id} | 评价列表 | 需登录 |
| POST | /api/reviews/ | 创建评价 | 需登录 |
| GET | /api/stats/ | 统计数据 | 需登录 |
| WS | /ws/chat/{order_id}/ | 实时聊天 | 订单相关方 |
