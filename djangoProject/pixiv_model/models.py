from django.db import models


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

class Lib(models.Model):
    id = models.IntegerField(primary_key=True)
    path = models.CharField(max_length=100)
