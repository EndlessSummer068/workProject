from django.contrib import admin
from .models import User, Need, Order, Message, Review

admin.site.register(User)
admin.site.register(Need)
admin.site.register(Order)
admin.site.register(Message)
admin.site.register(Review)
