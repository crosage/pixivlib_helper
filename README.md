# pixiv_helper

是为了更方便的查看图片

## 两种视图模式

![image](https://github.com/crosage/pixivlib_helper/assets/90540469/cf3fa858-69dc-4261-a6bb-0b31c0ee492a)

![image](https://github.com/crosage/pixivlib_helper/assets/90540469/e49b0d7e-be51-4b78-b57f-8ec4e0b0b630)

一个简单的搜索框

![image](https://github.com/crosage/pixivlib_helper/assets/90540469/e4e4d799-b7d8-408c-923b-37f8339aab5c)

## 设置页面

![屏幕截图 2023-12-02 160318](https://github.com/crosage/pixivlib_helper/assets/90540469/cedb4f3d-92e8-4b7c-83ec-ead4803cac5a)

![image](https://github.com/crosage/pixivlib_helper/assets/90540469/4740efc3-fd81-4f45-a423-b1a8155bd76a)


## 使用方式

类似这种的严格命名
(\d+)_p(\d+).(\w+)
![image](https://github.com/crosage/pixivlib_helper/assets/90540469/79ecad48-7bb4-4567-80a1-102064c0323c)

（或者自己改django里的匹配语句）
然后获取自己的refresh_token（后续会写前端，暂时怎么获取搜一下），之后再次刷新可以通过设置页面刷新，
获取到refresh_token accesstoken后点击爬取tag即可爬取（如果图片较多需要时间较长，后续也许会优化）

可以通过tag过滤想看的图片

## 计划

按照作者过滤
按照like数量过滤
多P查看
