from django.core.paginator import Paginator
from django.db import models
from django.db.models import Q, Count

# Create your models here.

class Tag(models.Model):
    id = models.IntegerField(primary_key=True)
    name = models.CharField(max_length=100)
    translate_name=models.CharField(max_length=100)
    @classmethod
    def saveTagWithoutRepeating(cls,name):
        tag=None
        try :
            tag=Tag.objects.get(name=name)
        except:
            tag=Tag(name=name)
            tag.save()
            tag=Tag.objects.get(name=name)
        return tag


class Image(models.Model):
    id = models.IntegerField(primary_key=True)
    pid = models.IntegerField()
    page = models.IntegerField()
    tid = models.ForeignKey(Tag, on_delete=models.CASCADE)
    name=models.CharField(max_length=100)
    path=models.CharField(max_length=100,default="D:\\bot\\awesomebot\\mylibrary")

    @classmethod
    def doExistImage(cls,pid):
        image=Image.objects.filter(pid=pid)
        return image.exists()

    @classmethod
    def getImageTagsByPid(cls,pid):
        tids=Image.objects.filter(pid=pid).values_list("tid",flat=True)
        tags=Tag.objects.filter(id__in=tids).values_list("name",flat=True)
        return tags

    @classmethod
    def getImages(cls,limit,offset):
        image_list=Image.objects.values("pid","page","name","path").distinct().order_by("-pid")
        page_size=limit
        page=offset/limit+1
#        print(image_list)
        paginator=Paginator(image_list,page_size)
        #print(paginator.page(1))
        image_list=paginator.page(page)
        return image_list
    @classmethod
    def filterTags(cls,tags,limit,offset):
        id_list = Tag.objects.filter(name__in=tags).values_list('id', flat=True)
        q = Q()
        for tag in id_list:
            q |= Q(tid__id=tag)
        image_list = Image.objects.filter(q).values("pid","page","name","path").order_by("-pid").annotate(count=Count('pid')).filter(
            count=len(id_list))
        page_size=limit
        page=offset/limit+1
        paginator=Paginator(image_list,page_size)
        image_list=paginator.page(page)
        return image_list



class Lib(models.Model):
    id = models.IntegerField(primary_key=True)
    path = models.CharField(max_length=100)
