"""djangoProject URL Configuration

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/4.1/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path
from utils.views import *
from pixiv_model.views import *

urlpatterns = [
    path("admin/", admin.site.urls),
    #初始化仓库
    path("api/lib/init",LibInit.as_view()),
    #获取仓库列表与新增仓库
    path("api/lib",LibView.as_view()),
    #删除仓库与更新仓库
    path("api/lib/<id>",deleteAndUpdateLibById.as_view()),
    #获取tag
    path("api/tag",getAllTagsWithCount.as_view()),
    #获取图片
    path("api/image",getImages.as_view()),
    #获取图片tag
    path("api/image/<int:pid>",getImageTagsByPid.as_view()),

    path("api/test",test.as_view()),
    #刷新token
    path("api/utils/login/{refresh_token}",refreshToken.as_view()),
    #获取token
    path("/api/utils/login",getRefreshToken.as_view()),
    path("/api/utils/delete_multi"),
]
