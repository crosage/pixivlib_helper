from django.shortcuts import render
from rest_framework.response import Response
from rest_framework.decorators import api_view


# Create your views here.

@api_view(['GET','POST'])
def hello_world(request):
    if request.method=="GET":
        return Response({"message": "get"})
    if request.method=='POST':
        return Response({"messgae":"post"})


@api_view(['POST'])
def hello(requset):
    return Response({"message": "hel_word"})
