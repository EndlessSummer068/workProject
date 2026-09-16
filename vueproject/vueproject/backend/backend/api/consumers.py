import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from api.models import Order, Message, User


class ChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.order_id = self.scope['url_route']['kwargs']['order_id']
        self.group_name = f'chat_order_{self.order_id}'
        user = self.scope.get('user')
        if not user or not user.is_authenticated:
            await self.close()
            return
        if not await self._has_permission(user):
            await self.close()
            return
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def receive(self, text_data):
        user = self.scope.get('user')
        if not user or not user.is_authenticated:
            return
        data = json.loads(text_data)
        text = data.get('text', '').strip()
        if not text:
            return
        msg = await self._save_message(user, text)
        await self.channel_layer.group_send(self.group_name, {
            'type': 'chat_message',
            'message': msg,
        })

    async def chat_message(self, event):
        await self.send(text_data=json.dumps(event['message']))

    @database_sync_to_async
    def _has_permission(self, user):
        try:
            order = Order.objects.get(pk=self.order_id)
            return user.role == 'admin' or order.client == user or order.provider == user
        except Order.DoesNotExist:
            return False

    @database_sync_to_async
    def _save_message(self, user, text):
        msg = Message.objects.create(order_id=self.order_id, sender=user, text=text)
        avatar_url = None
        if user.avatar:
            scheme = 'https' if self.scope.get('scheme') == 'wss' else 'http'
            host = self.scope.get('server', ('127.0.0.1', 8000))
            port = host[1]
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
