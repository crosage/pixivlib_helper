import random
import time

import json

from django.db.models import Q, Count
from rest_framework.response import Response
from rest_framework.views import APIView

from response.models import MyResponse
from .models import Lib
from .models import Tag
from .models import Image
from .serializers import LibSerializer
import re
import os
import pixivpy3

proxies = {
    "http": "http://127.0.0.1:7890",
    "https": "http://127.0.0.1:7890",
}
api = pixivpy3.AppPixivAPI(proxies=proxies)
api.set_auth(refresh_token="your cookie",
             access_token="your cookie")


# Create your views here.
class initLib(APIView):
    # 初始化已有的lib（往数据库）
    def get(self, request):
        response=MyResponse()
        try:
            libs = Lib.objects.all()
            libs = LibSerializer(libs, many=True)
            for lib in libs.data:
                path = lib.get("path")
                images = os.listdir(path)
                #random.shuffle(images)
                for image in images:
                    print(image)
                    match = re.match(r"(\d+)_p(\d+).(\w+)", image)
                    if match:
                        pid = match.group(1)
                        page = match.group(2)
                        if Image.doExistImage(pid):
                            continue
                        try:
                            resp = api.illust_detail(pid)
                            tags = resp.illust.tags
                            for _tag in tags:
                                tagName = _tag.get("name")
                                tag=Tag.saveTagWithoutRepeating(name=tagName)
                                _image,created=Image.objects.get_or_create(pid=pid,name=image,page=page,tid=tag)
                        except Exception as e:
                            print(f"{image}发生了一个错误：{e}")
                        time.sleep(1)
            response.success()
        except Exception as e:
            response.error(e)
        return Response(response.d)

    # 添加新的lib
    def post(self, request):
        response = MyResponse()
        try :
            map=json.loads(request.body)
            newLib = Lib(path=map.get("path"))
            newLib.save()
            response.success()
        except Exception as e:
            response.error(e)
        return Response(response.d)
    def delete(self,request):
        # TODO
        pass


class changeAllImage(APIView):
    def get(self,request):
        images=Image.objects.all()
        images.update(path="D:\\bot\\awesomebot\\mylibrary")

class changeImageByPid(APIView):
    def get(self,request):
        # TODO
        pass

class filterTags(APIView):
    def post(self,request):
        response=MyResponse()
        try :
            map=json.loads(request.body)
            tags=map.get("tag")
            id_list = Tag.objects.filter(name__in=tags).values_list('id',flat=True)
            q=Q()
            for tag in id_list:
                q|=Q(tid__id=tag)
            image_list=Image.objects.filter(q).values_list('name').annotate(count=Count('pid')).filter(count=len(id_list)).values_list('name', flat=True)
            response.put({"list":list(image_list)})
            #print(Image.objects.filter(q).values_list('pid').annotate(count=Count('pid')).filter(count=len(id_list)))
            response.success()
        except Exception as e:
            response.error(e)
        return Response(response.d)