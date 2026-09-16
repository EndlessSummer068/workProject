from django.core.management.base import BaseCommand
from api.models import User, Need, Order, Message


class Command(BaseCommand):
    help = '初始化测试数据'

    def handle(self, *args, **options):
        self.stdout.write('开始创建测试数据...')

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

        need_web = Need.objects.filter(title='设计一个企业官网').first()
        if need_web and not Order.objects.filter(title='设计一个企业官网').exists():
            Order.objects.create(
                need=need_web,
                client=client,
                provider=None,
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
