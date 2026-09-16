from django.urls import path
from . import views

urlpatterns = [
    path('auth/register/', views.RegisterView.as_view(), name='register'),
    path('auth/login/', views.LoginView.as_view(), name='login'),
    path('auth/logout/', views.LogoutView.as_view(), name='logout'),
    path('auth/me/', views.CurrentUserView.as_view(), name='current-user'),
    path('auth/change-password/', views.ChangePasswordView.as_view(), name='change-password'),
    path('users/', views.UserListView.as_view(), name='user-list'),
    path('users/<int:pk>/', views.UserDetailView.as_view(), name='user-detail'),
    path('needs/', views.NeedListCreateView.as_view(), name='need-list'),
    path('needs/<int:pk>/', views.NeedDetailView.as_view(), name='need-detail'),
    path('needs/<int:pk>/accept/', views.NeedAcceptView.as_view(), name='need-accept'),
    path('orders/', views.OrderListCreateView.as_view(), name='order-list'),
    path('orders/<int:pk>/', views.OrderDetailView.as_view(), name='order-detail'),
    path('messages/', views.MessageListCreateView.as_view(), name='message-list'),
    path('reviews/', views.ReviewListCreateView.as_view(), name='review-list'),
    path('stats/', views.DashboardStatsView.as_view(), name='dashboard-stats'),
]
