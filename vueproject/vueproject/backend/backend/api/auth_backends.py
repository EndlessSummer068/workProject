from rest_framework.authentication import SessionAuthentication
from rest_framework import exceptions
from rest_framework.permissions import IsAuthenticated as BaseIsAuthenticated


def custom_exception_handler(exc, context):
    from rest_framework.views import exception_handler as drf_exception_handler
    response = drf_exception_handler(exc, context)
    if response is not None:
        if isinstance(exc, (exceptions.NotAuthenticated, exceptions.AuthenticationFailed)):
            if isinstance(response.data, dict) and 'detail' in response.data:
                response.data = {'success': False, 'message': response.data['detail']}
        elif isinstance(exc, exceptions.PermissionDenied):
            if isinstance(response.data, dict) and 'detail' in response.data:
                response.data = {'success': False, 'message': response.data['detail']}
    return response


class CsrfExemptSessionAuthentication(SessionAuthentication):
    def enforce_csrf(self, request):
        return

    def authenticate_header(self, request):
        return 'Session'

    def authenticate(self, request):
        result = super().authenticate(request)
        if result and not result[0].is_active:
            raise exceptions.AuthenticationFailed('用户已被禁用。')
        return result


class IsAuthenticated(BaseIsAuthenticated):
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            raise exceptions.NotAuthenticated('身份认证信息未提供。')
        return True
