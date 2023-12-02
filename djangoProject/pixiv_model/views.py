import random
import time

import json

from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework.views import APIView

from response.models import MyResponse
from .models import Lib, PixivToken
from .models import Tag
from .models import Image
from .serializers import LibSerializer, ImageSerializer,ImageWithTidSerializer
import re
import os
import pixivpy3

proxies = {
    "http": "http://127.0.0.1:7890",
    "https": "http://127.0.0.1:7890",
}




api = pixivpy3.AppPixivAPI(proxies=proxies)
api.set_auth(
    access_token=PixivToken.getAccessToken(),
    refresh_token=PixivToken.getRefreshToken()
)

class refresh_the_token(APIView):
    def get(self,request):
        pass
# Create your views here.
class LibInit(APIView):
    # 初始化已有的lib（往数据库）
    def get(self, request):
        response=MyResponse()
        try:
            libs = Lib.objects.all().order_by("-id")
            libs = LibSerializer(libs, many=True)
            # print(libs)
            for lib in libs.data:
                path = lib.get("path")
                print(path)

                images = os.listdir(path)
                images.sort()
                print(path)
                for image in images:
                    # print(image)
                    match = re.match(r"(\d+)_p(\d+).(\w+)", image)
                    if match:
                        pid = match.group(1)
                        page = match.group(2)
                        if Image.doExistImage(pid,page):
                            continue
                        resp = api.illust_detail(pid)
                        try:

                            tags = resp.illust.tags
                            author=resp.illust.user.name
                            if tags==[]:
                                print(resp)
                                print(f"{Image.doExistImage(pid)} {resp}")
                                print(1/0)
                            for _tag in tags:
                                tagName = _tag.get("name")
                                tag=Tag.saveTagWithoutRepeating(name=tagName)
                                _image,created=Image.objects.get_or_create(pid=pid,name=image,page=page,tid=tag,path=path,author=author)
                        except Exception as e:
                            tag=Tag.objects.get(id=2)
                            print(resp)
                            Image.objects.get_or_create(pid=pid,name=image,page=page,tid=tag,path=path)
                            print(f"{image}发生了一个错误：{e}")
                        time.sleep(1)
            response.success()
        except Exception as e:

            response.error(e)
        return Response(response.d)

    # 添加新的lib


from rest_framework.decorators import api_view


class LibView(APIView):
    def get(self, request):
        response = MyResponse()
        try:
            libs = Lib.objects.all()
            libs=LibSerializer(libs,many=True)
            print(libs.data)
            response.put({"libs": libs.data})
            return response.success()
        except Exception as e:
            return response.error(e)


    def post(self, request):
        response = MyResponse()
        try:
            map = json.loads(request.body)
            newLib = Lib(path=map.get("path"))
            newLib.save()
            return response.success()
        except Exception as e:
            return response.error(e)

class deleteAndUpdateLibById(APIView):
    # 删除lib
    def delete(self,request,id):
        response=MyResponse()
        try:
            Lib.objects.get(id=id).delete()
            return response.success()
        except Exception as e:
            return response.error(e)
    def post(self,request,id):
        response=MyResponse()
        try:
            map=json.loads(request.body)
            path=map["path"]
            record=Lib.objects.filter(id=id)
            record.update(path=path)
            return response.success()
        except Exception as e:
            return response.error(e)

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
            offset=map.get("offset",0)
            limit=map.get("limit",20)
            image_list=Image.filterTags(tags,offset=offset,limit=limit)
            response.put({"list":list(image_list)})
            response.success()
        except Exception as e:
            response.error(e)
        return Response(response.d)

class getImages(APIView):
    def post(self,request):
        response=MyResponse()
        try:
            map=json.loads(request.body)
            offset=map.get("offset",0)
            limit=map.get("limit",20)
            tag=map.get("tag",None)
            print(f"{offset} {tag} *********")
            if tag==None or tag==[]:
                image_list,pages=Image.getImages(limit,offset)
            else :
                image_list,pages=Image.filterTags(tags=tag,offset=offset,limit=limit)
            # print(image_list)
            # print(list(image_list))
            response.put({"images":list(image_list),"pages":pages})
            return response.success()
        except Exception as e:
            return response.error(e)
    def get(self):
        print("##############")
class getImageTagsByPid(APIView):
    def get(self,request,pid):
        response=MyResponse()
        try:
            image=Image.getImageTagsByPid(pid)
            response.put({"tags":image})
            return response.success()
        except Exception as e:
            return response.error(e)

class getAllTagsWithCount(APIView):
    def post(self,request):
        response=MyResponse()
        try:
            map=json.loads(request.body)
            offset=map.get("offset",0)
            limit=map.get("limit",20)
            tags = Tag.getAllTagsWithLimitAndOffset(offset=offset,limit=limit)
            response.put({"tags":list(tags)})
            return response.success()
        except Exception as e:
            return response.error(e)

class test(APIView):
    def get(self,request):
        response=MyResponse()
        print(Image.doExistImage(pid=104802501,page=0))