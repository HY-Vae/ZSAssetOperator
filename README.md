# ZSAssetOperator
操作系统相册, 创建相册, 存图片/视频到系统相册, 从自定义的相册里删除视频/图片

在存文件 和 读取文件的时候, 加了 ```dispatch_semaphore_t```, 以防止顺序错乱.

只有简单的创建相册/存文件/读取文件, 至于展示数据的ui, 我没有上传, 毕竟需求都不一样, 需要什么样子的, 最好自己写;

> 毕竟, 数据源都有了, 想咋展示还不随意吗?
