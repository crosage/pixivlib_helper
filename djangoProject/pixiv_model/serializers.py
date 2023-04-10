from rest_framework import serializers
from .models import *

class TagSerializer(serializers.ModelSerializer):
    class Meta:
        model=Tag
        fields="__all__"

class ImageSerializer(serializers.ModelSerializer):
    class Meta:
        model=Image
        fields="__all__"

class LibSerializer(serializers.ModelSerializer):
    class Meta:
        model=Lib
        fields="__all__"