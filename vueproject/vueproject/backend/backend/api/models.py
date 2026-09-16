from django.db import models
from django.contrib.auth.models import AbstractUser


class User(AbstractUser):
    ROLE_CHOICES = [
        ('client', '客户'),
        ('provider', '服务方'),
        ('admin', '管理员'),
    ]
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='client')
    phone = models.CharField(max_length=20, blank=True, default='')
    avatar = models.ImageField(upload_to='avatars/', blank=True, null=True)
    bio = models.TextField(blank=True, default='')
    skills = models.CharField(max_length=200, blank=True, default='')
    rating = models.FloatField(default=0)
    completed_orders = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'tf_user'


class Need(models.Model):
    STATUS_CHOICES = [
        ('pending', '待接单'),
        ('matched', '已匹配'),
        ('draft', '草稿'),
        ('in_progress', '进行中'),
        ('completed', '已完成'),
        ('cancelled', '已取消'),
    ]
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='needs')
    title = models.CharField(max_length=200)
    type = models.CharField(max_length=50)
    description = models.TextField(blank=True, default='')
    budget = models.CharField(max_length=50)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    attachment = models.FileField(upload_to='attachments/', blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'tf_need'
        ordering = ['-created_at']


class Order(models.Model):
    STATUS_CHOICES = [
        ('pending', '待接单'),
        ('in_progress', '进行中'),
        ('completed', '待客户支付'),
        ('paid', '已支付'),
        ('reviewed', '已完成'),
        ('cancelled', '已取消'),
    ]
    need = models.ForeignKey(Need, on_delete=models.SET_NULL, null=True, blank=True, related_name='orders')
    client = models.ForeignKey(User, on_delete=models.CASCADE, related_name='client_orders')
    provider = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='provider_orders')
    title = models.CharField(max_length=200)
    amount = models.CharField(max_length=50)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    progress = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'tf_order'
        ordering = ['-created_at']


class Message(models.Model):
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='messages')
    sender = models.ForeignKey(User, on_delete=models.CASCADE)
    text = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'tf_message'
        ordering = ['created_at']


class Review(models.Model):
    order = models.OneToOneField(Order, on_delete=models.CASCADE, related_name='review')
    reviewer = models.ForeignKey(User, on_delete=models.CASCADE)
    rating = models.IntegerField()
    tags = models.CharField(max_length=200, blank=True, default='')
    comment = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'tf_review'
