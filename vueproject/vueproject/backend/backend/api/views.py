from django.db import models
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
    return Response({'success': False, 'message': message}, status=status_code)


def first_error(errors):
    for field_msgs in errors.values():
        if isinstance(field_msgs, list) and field_msgs:
            return str(field_msgs[0])
        return str(field_msgs)
    return '请求参数错误'


class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            login(request, user)
            return Response({
            'success': True,
            'user': UserSerializer(user, context={'request': request}).data
        }, status=status.HTTP_201_CREATED)
        return error_response(first_error(serializer.errors), status.HTTP_400_BAD_REQUEST)


class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        username = request.data.get('username', '')
        password = request.data.get('password', '')
        user = authenticate(request, username=username, password=password)
        if user is not None and user.is_active:
            login(request, user)
            return Response({
                'success': True,
                'user': UserSerializer(user, context={'request': request}).data
            })
        return error_response('账号或密码错误', status.HTTP_401_UNAUTHORIZED)


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        logout(request)
        return Response({'success': True})


class CurrentUserView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(UserSerializer(request.user, context={'request': request}).data)

    def put(self, request):
        serializer = UserSerializer(request.user, data=request.data, partial=True, context={'request': request})
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return error_response(first_error(serializer.errors), status.HTTP_400_BAD_REQUEST)


class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        old_password = request.data.get('old_password', '')
        new_password = request.data.get('new_password', '')
        if not old_password or not new_password:
            return error_response('请填写完整信息', status.HTTP_400_BAD_REQUEST)
        if not request.user.check_password(old_password):
            return error_response('当前密码错误', status.HTTP_400_BAD_REQUEST)
        if len(new_password) < 6:
            return error_response('新密码至少6位', status.HTTP_400_BAD_REQUEST)
        request.user.set_password(new_password)
        request.user.save()
        login(request, request.user)
        return Response({'success': True, 'message': '密码修改成功'})


class UserListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.role != 'admin':
            return error_response('无权限', status.HTTP_403_FORBIDDEN)
        users = User.objects.all()
        role = request.query_params.get('role')
        if role:
            users = users.filter(role=role)
        search = request.query_params.get('search')
        if search:
            users = users.filter(username__icontains=search)
        serializer = UserSerializer(users, many=True, context={'request': request})
        return Response(serializer.data)


class UserDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        try:
            user = User.objects.get(pk=pk)
            return Response(UserSerializer(user, context={'request': request}).data)
        except User.DoesNotExist:
            return error_response('用户不存在', status.HTTP_404_NOT_FOUND)

    def put(self, request, pk):
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
        if request.user.role != 'admin':
            return error_response('无权限', status.HTTP_403_FORBIDDEN)
        try:
            user = User.objects.get(pk=pk)
            user.delete()
            return Response({'success': True})
        except User.DoesNotExist:
            return error_response('用户不存在', status.HTTP_404_NOT_FOUND)


class NeedListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
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
        serializer = NeedSerializer(data=request.data)
        if serializer.is_valid():
            need = serializer.save(user=request.user)
            Order.objects.create(
                need=need,
                client=request.user,
                title=need.title,
                amount=str(need.budget) if need.budget else '0',
                status='pending',
                progress=0,
            )
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return error_response(first_error(serializer.errors), status.HTTP_400_BAD_REQUEST)


class NeedDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        try:
            need = Need.objects.get(pk=pk)
            return Response(NeedSerializer(need).data)
        except Need.DoesNotExist:
            return error_response('需求不存在', status.HTTP_404_NOT_FOUND)

    def put(self, request, pk):
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
        try:
            need = Need.objects.get(pk=pk)
            if need.user != request.user and request.user.role != 'admin':
                return error_response('无权限', status.HTTP_403_FORBIDDEN)
            need.delete()
            return Response({'success': True})
        except Need.DoesNotExist:
            return error_response('需求不存在', status.HTTP_404_NOT_FOUND)


class NeedAcceptView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            need = Need.objects.get(pk=pk)
        except Need.DoesNotExist:
            return error_response('需求不存在', status.HTTP_404_NOT_FOUND)
        if need.status != 'pending':
            return error_response('该需求不可接单', status.HTTP_400_BAD_REQUEST)
        if request.user.role not in ('provider', 'admin'):
            return error_response('仅服务方可接单', status.HTTP_403_FORBIDDEN)
        amount = request.data.get('amount', need.budget)
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
            order.provider = request.user
            order.amount = str(amount)
            order.status = 'in_progress'
            order.save()
        need.status = 'matched'
        need.save()
        return Response({
            'success': True,
            'order': OrderSerializer(order, context={'request': request}).data
        })


class OrderListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        orders = Order.objects.all()
        if request.user.role == 'admin':
            client_id = request.query_params.get('client')
            if client_id:
                orders = orders.filter(client_id=client_id)
            provider_id = request.query_params.get('provider')
            if provider_id:
                orders = orders.filter(provider_id=provider_id)
        else:
            orders = orders.filter(
                models.Q(client=request.user) | models.Q(provider=request.user)
            )
        status_filter = request.query_params.get('status')
        if status_filter:
            status_map = dict(Order.STATUS_CHOICES)
            reverse_map = {v: k for k, v in status_map.items()}
            status_value = reverse_map.get(status_filter, status_filter)
            orders = orders.filter(status=status_value)
        search = request.query_params.get('search')
        if search:
            orders = orders.filter(
                models.Q(id__icontains=search) | models.Q(need__title__icontains=search)
            )
        serializer = OrderSerializer(orders.order_by('-id'), many=True, context={'request': request})
        return Response(serializer.data)

    def post(self, request):
        serializer = OrderSerializer(data=request.data, context={'request': request})
        if serializer.is_valid():
            order = serializer.save()
            if order.need and order.need.status == 'pending':
                order.need.status = 'matched'
                order.need.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return error_response(first_error(serializer.errors), status.HTTP_400_BAD_REQUEST)


class OrderDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
            if request.user.role != 'admin' and order.client != request.user and order.provider != request.user:
                return error_response('无权限', status.HTTP_403_FORBIDDEN)
            return Response(OrderSerializer(order, context={'request': request}).data)
        except Order.DoesNotExist:
            return error_response('订单不存在', status.HTTP_404_NOT_FOUND)

    def put(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
            if request.user.role != 'admin' and order.client != request.user and order.provider != request.user:
                return error_response('无权限', status.HTTP_403_FORBIDDEN)
            serializer = OrderSerializer(order, data=request.data, partial=True, context={'request': request})
            if serializer.is_valid():
                old_status = order.status
                serializer.save()
                if old_status != 'reviewed' and request.data.get('status') == 'reviewed' and order.provider:
                    order.provider.completed_orders += 1
                    order.provider.save()
                return Response(serializer.data)
            return error_response(first_error(serializer.errors), status.HTTP_400_BAD_REQUEST)
        except Order.DoesNotExist:
            return error_response('订单不存在', status.HTTP_404_NOT_FOUND)


class MessageListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        order_id = request.query_params.get('order')
        if not order_id:
            return error_response('请指定订单ID', status.HTTP_400_BAD_REQUEST)
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
            serializer.save(sender=request.user)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return error_response(first_error(serializer.errors), status.HTTP_400_BAD_REQUEST)


class ReviewListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        reviews = Review.objects.all()
        order_id = request.query_params.get('order')
        if order_id:
            try:
                order = Order.objects.get(pk=order_id)
                if request.user.role != 'admin' and order.client != request.user and order.provider != request.user:
                    return error_response('无权限', status.HTTP_403_FORBIDDEN)
            except Order.DoesNotExist:
                return error_response('订单不存在', status.HTTP_404_NOT_FOUND)
            reviews = reviews.filter(order_id=order_id)
        elif request.user.role != 'admin':
            reviews = reviews.filter(
                models.Q(order__client=request.user) | models.Q(order__provider=request.user)
            )
        serializer = ReviewSerializer(reviews, many=True)
        return Response(serializer.data)

    def post(self, request):
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
            order = serializer.instance.order
            order.status = 'reviewed'
            order.save(update_fields=['status', 'updated_at'])
            provider = order.provider
            if provider:
                all_reviews = Review.objects.filter(order__provider=provider)
                avg_rating = sum(r.rating for r in all_reviews) / all_reviews.count()
                provider.rating = round(avg_rating, 1)
                provider.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return error_response(first_error(serializer.errors), status.HTTP_400_BAD_REQUEST)


class DashboardStatsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.role == 'client':
            client_orders = Order.objects.filter(client=user)
            client_needs = Need.objects.filter(user=user)
            stats = {
                'in_progress_orders': client_orders.filter(status='in_progress').count(),
                'pending_needs': client_needs.filter(status='pending').count(),
                'completed_orders': client_orders.filter(status__in=['completed', 'paid', 'reviewed']).count(),
                'total_spent': sum(int(o.amount.replace(',', '')) for o in client_orders.filter(status__in=['paid', 'completed', 'reviewed']) if o.amount),
            }
        elif user.role == 'provider':
            provider_orders = Order.objects.filter(provider=user)
            stats = {
                'in_progress_orders': provider_orders.filter(status='in_progress').count(),
                'completed_orders': provider_orders.filter(status__in=['completed', 'paid', 'reviewed']).count(),
                'monthly_income': sum(int(o.amount.replace(',', '')) for o in provider_orders.filter(status__in=['completed', 'paid', 'reviewed']) if o.amount),
                'avg_rating': user.rating,
            }
        elif user.role == 'admin':
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
            type_counts = list(all_needs.values('type').annotate(count=Count('id')).order_by('-count'))
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
