from django.db import models
from rest_framework.response import Response
# Create your models here.

class MyResponse:

    def __init__(self):
        self.d={}
        self.d.update({"status":""})
        self.d.update({"msg":""})
    def put(self,newDict):
        self.d.update(newDict)

    def success(self):
        self.d.update({"status":0})
        return Response(self.d)

    def error(self,msg):
        self.d.update({"status":1})
        self.d.update({"msg":str(msg)})
        return Response(self.d,status=500)