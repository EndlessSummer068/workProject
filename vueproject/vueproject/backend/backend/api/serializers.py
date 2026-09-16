from rest_framework import serializers
from .models import User, Need, Order, Message, Review


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'role', 'phone', 'avatar', 'bio', 'skills', 'rating', 'completed_orders', 'is_active']
        read_only_fields = ['id', 'rating', 'completed_orders']

    def to_representation(self, instance):
        data = super().to_representation(instance)
        request = self.context.get('request')
        if request and data.get('avatar') and not str(data['avatar']).startswith('http'):
            scheme = 'https' if request.is_secure() else 'http'
            host = request.get_host()
            data['avatar'] = f"{scheme}://{host}{data['avatar']}"
        return data


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6)

    class Meta:
        model = User
        fields = ['username', 'password', 'email', 'role', 'phone']

    def validate_role(self, value):
        if value == 'admin':
            raise serializers.ValidationError('注册不支持管理员角色')
        return value

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data['username'],
            password=validated_data['password'],
            email=validated_data.get('email', ''),
            role=validated_data.get('role', 'client'),
            phone=validated_data.get('phone', ''),
        )
        return user


class NeedSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)

    class Meta:
        model = Need
        fields = ['id', 'user', 'username', 'title', 'type', 'description', 'budget', 'status', 'attachment']
        read_only_fields = ['id', 'user']


class OrderSerializer(serializers.ModelSerializer):
    client_name = serializers.CharField(source='client.username', read_only=True)
    provider_name = serializers.CharField(source='provider.username', read_only=True, default=None)
    need_title = serializers.CharField(source='need.title', read_only=True, default=None)
    need_attachment = serializers.FileField(source='need.attachment', read_only=True, default=None)
    need_attachment_url = serializers.SerializerMethodField()

    def get_need_attachment_url(self, obj):
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


class MessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.CharField(source='sender.username', read_only=True)
    sender_role = serializers.CharField(source='sender.role', read_only=True)
    sender_avatar = serializers.SerializerMethodField()

    def get_sender_avatar(self, obj):
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
        read_only_fields = ['id', 'sender']


class ReviewSerializer(serializers.ModelSerializer):
    class Meta:
        model = Review
        fields = ['id', 'order', 'reviewer', 'rating', 'tags', 'comment']
        read_only_fields = ['id', 'reviewer']
