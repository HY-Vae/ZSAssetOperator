# ZSAssetOperator
操作系统相册, 创建相册, 存图片/视频到系统相册, 从自定义的相册里删除视频/图片

在存文件 和 读取文件的时候, 加了 ```dispatch_semaphore_t```, 以防止顺序错乱.
