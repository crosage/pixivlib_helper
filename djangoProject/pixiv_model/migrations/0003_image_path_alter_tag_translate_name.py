# Generated by Django 4.1.7 on 2023-04-10 11:05

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('pixiv_model', '0002_tag_translate_name'),
    ]

    operations = [
        migrations.AddField(
            model_name='image',
            name='path',
            field=models.CharField(default='D:\x08ot\x07wesomebot\\mylibrary', max_length=100),
        ),
        migrations.AlterField(
            model_name='tag',
            name='translate_name',
            field=models.CharField(max_length=100),
        ),
    ]
