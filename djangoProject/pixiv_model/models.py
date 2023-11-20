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

    @classmethod
    def getAllTagsWithLimitAndOffset(cls,offset,limit):
        tags=Tag.objects.all().order_by("name").values_list("name",flat=True)
        page_size=limit
        page=offset/limit+1
        paginator=Paginator(tags,page_size)
        tag_list=paginator.page(page)
        return tag_list

class Image(models.Model):
    id = models.IntegerField(primary_key=True)
    pid = models.IntegerField()
    page = models.IntegerField()
    author=models.CharField(max_length=100,default="unknown author")
    tid = models.ForeignKey(Tag, on_delete=models.CASCADE)
    name=models.CharField(max_length=100)
    path=models.CharField(max_length=100,default="D:\\bot\\awesomebot\\mylibrary")

    @classmethod
    def doExistImage(cls,pid,page):
        image=Image.objects.filter(pid=pid,page=page)
        return image.exists()

    @classmethod
    def getImageTagsByPid(cls,pid):
        tids=Image.objects.filter(pid=pid).values_list("tid",flat=True)
        tags=Tag.objects.filter(id__in=tids).values_list("name",flat=True)
        return tags

    @classmethod
    def getImages(cls,limit,offset):
        # print("11111111111")
        # print(Image.objects.values("pid","page").order_by("-pid"))
        # print("22222222222")
        # print(Image.objects.values("pid","page").order_by("-pid").distinct())
        image_list=Image.objects.values("pid","page","name","path","author").distinct().order_by("-pid")
        page_size=limit
        page=offset/limit+1
        # print(image_list)
        paginator=Paginator(image_list,page_size)
        # print(paginator.page(1))
        image_list=paginator.page(page)
        return image_list,paginator.num_pages
    @classmethod
    def filterTags(cls,tags,limit,offset):
        print(tags)
        id_list = Tag.objects.filter(name__in=tags).values_list('id', flat=True)
        q = Q()
        for tag in id_list:
            q |= Q(tid__id=tag)
        image_list = (
            Image.objects.filter(q)
            .values("pid","page","name","path","author")
            .order_by("-pid")
            .annotate(count=Count('pid'))
            .filter(count=len(id_list))
        )
        # print(image_list)
        page_size=limit
        page=offset/limit+1
        paginator=Paginator(image_list,page_size)
        image_list=paginator.page(page)
        return image_list,paginator.num_pages



class Lib(models.Model):
    id = models.IntegerField(primary_key=True)
    path = models.CharField(max_length=100)

class PixivToken(models.Model):
    def updateRefreshToken(self,refreshToken):
        self.refresh_token=refreshToken
        self.save()
    def updateAccessToken(self,accessToken):
        self.access_token=accessToken
        self.save()
    id=models.IntegerField(primary_key=True)
    refresh_token=models.CharField(max_length=100)
    access_token=models.CharField(max_length=100)