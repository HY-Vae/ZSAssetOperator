//
//  ZSAssetOperator.m
//  ZSAssetOperator
//
//  Created by zishu on 9/11/19.
//  Copyright © 2019 QMSJ. All rights reserved.
//

#import "ZSAssetOperator.h"

#import <Photos/Photos.h>

@interface ZSAssetOperator()

//@property (nonatomic, copy) NSString *plistName;
@property (nonatomic, copy) NSString *albumsName;


@property (nonatomic) NSMutableArray <ZSAssetModel *> *arrM;


@end


@implementation ZSAssetOperator

+ (instancetype)sharedOperator {
    static ZSAssetOperator *operator = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        operator = [[ZSAssetOperator alloc] init];
        operator.arrM = [NSMutableArray array];
    });
    return operator;
}

- (void)createAlbums:(NSString *)albumsName {
    if (albumsName.length == 0) {
        NSAssert(0, @"albumsName 不能为空");
    }
    self.albumsName = albumsName;
    if (![self isExistAlbums]) {
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            //添加HUD文件夹
            [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:self.albumsName];
            
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            if (success) {
                NSLog(@"创建相册文件夹成功!");
            } else {
                NSLog(@"创建相册文件夹失败: %@", error);
            }
        }];
    }
}

- (NSArray <ZSAssetModel *>*)getImagesAndVideoFromFolder {
    
    [self checkShouldCreateAlbums];
    
    [self.arrM removeAllObjects];
    
    //首先获取用户手动创建相册的集合
    PHFetchResult *collectonResuts = [PHCollectionList fetchTopLevelUserCollectionsWithOptions:nil];
    
    // 创建的相册
    __block PHAssetCollection *assetCollection;
    //对获取到集合进行遍历
    [collectonResuts enumerateObjectsUsingBlock:^(PHAssetCollection *obj, NSUInteger idx, BOOL *stop) {
        //albumsName是我们写入照片的相册
        if ([obj.localizedTitle isEqualToString:self.albumsName])  {
            assetCollection = obj;
            *stop = YES;
        }
    }];
    
    PHFetchResult *res = [PHAsset fetchAssetsInAssetCollection:assetCollection options:nil];
    [res enumerateObjectsUsingBlock:^(PHAsset   * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {

        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
//        NSLog(@"%d, idx: %lu", __LINE__, idx);
        [self getAssetWith:obj semaphore:sem];
         dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    }];
    
    // 用 dispatch_semaphore_t 来保证同步
    return self.arrM.copy;
}


- (void)getAssetWith:(PHAsset *)asset semaphore:(dispatch_semaphore_t)sem {
    
    if (asset.mediaType == PHAssetMediaTypeImage) {
        CGSize size = CGSizeMake(asset.pixelWidth, asset.pixelHeight);
        
        PHImageRequestOptions *imageOptions = [[PHImageRequestOptions alloc] init];
        imageOptions.synchronous = YES; //YES 一定是同步    NO不一定是异步
        imageOptions.resizeMode = PHImageRequestOptionsResizeModeExact;
        imageOptions.deliveryMode = PHImageRequestOptionsDeliveryModeOpportunistic;//imageOptions.synchronous = NO的情况下最终决定是否是异步

        [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:size contentMode:PHImageContentModeAspectFit options:imageOptions resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
            ZSAssetModel *model = [ZSAssetModel new];
            model.assetType = ZSAssetType_Photo;
            model.localIdentifier = asset.localIdentifier;
            model.image = result;
            
            [self->_arrM addObject:model];
            dispatch_semaphore_signal(sem);
        }];
    }
    else if (asset.mediaType == PHAssetMediaTypeVideo) {
        
        PHVideoRequestOptions *videoRequsetOptions = [[PHVideoRequestOptions alloc] init];
        videoRequsetOptions.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;
        videoRequsetOptions.networkAccessAllowed = false;
        
        [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:videoRequsetOptions resultHandler:^(AVAsset * _Nullable avasset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
            
            AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:avasset];
            gen.appliesPreferredTrackTransform = YES;
            CMTime time = CMTimeMakeWithSeconds(0.0, 600);
            NSError *error = nil;
            CMTime actualTime;
            CGImageRef image = [gen copyCGImageAtTime:time actualTime:&actualTime error:&error];
            UIImage *shotImage = [[UIImage alloc] initWithCGImage:image];
            CGImageRelease(image);
            
            ZSAssetModel *model = [ZSAssetModel new];
            model.assetType = ZSAssetType_Video;
            model.localIdentifier = asset.localIdentifier;
            model.image = shotImage;
            model.avAsset = avasset;
            [self->_arrM addObject:model];
            
            dispatch_semaphore_signal(sem);
        }];
    }
}

- (void)saveImage:(UIImage *)img  completionHandler:(nullable void(^)(BOOL success, NSError *__nullable error))completionHandler {
    [self checkShouldCreateAlbums];
    if (img == nil) {
        if (completionHandler) {
            NSError *err = [NSError errorWithDomain:@"ZSAssetOperator" code:-999 userInfo:@{NSLocalizedDescriptionKey : @"图片不能为空"}];
            completionHandler(NO, err);
        }
        return;
    }
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [self _saveFile:YES image:img videoPath:nil semaphore:sem  completionHandler:completionHandler];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
}

- (void)saveVideoPath:(NSString *)videoPath completionHandler:(nullable void(^)(BOOL success, NSError *__nullable error))completionHandler {
    [self checkShouldCreateAlbums];
    if (videoPath == nil) {
        if (completionHandler) {
            NSError *err = [NSError errorWithDomain:@"ZSAssetOperator" code:-999 userInfo:@{NSLocalizedDescriptionKey : @"视频路径不能为空"}];
            completionHandler(NO, err);
        }
        return;
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:videoPath] == NO) {
        if (completionHandler) {
            NSError *err = [NSError errorWithDomain:@"ZSAssetOperator" code:-999 userInfo:@{NSLocalizedDescriptionKey : @"该路径下的文件不存在"}];
            completionHandler(NO, err);
        }
        return;
    }
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [self _saveFile:NO image:nil videoPath:videoPath semaphore:sem completionHandler:completionHandler];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
}

- (void)deleteFileWith:(NSString *)localIdentifier completionHandler:(void(^)(BOOL success, NSError *error))completionHandler {
    [self checkShouldCreateAlbums];
    PHFetchResult *collectonResuts = [PHCollectionList fetchTopLevelUserCollectionsWithOptions:nil];
    [collectonResuts enumerateObjectsUsingBlock:^(PHAssetCollection *assetCollection, NSUInteger idx, BOOL *collectionStop) {
        if ([assetCollection.localizedTitle isEqualToString:self->_albumsName])  {
            *collectionStop = YES;
            PHFetchResult *assetResult = [PHAsset fetchAssetsInAssetCollection:assetCollection options:[PHFetchOptions new]];
            [assetResult enumerateObjectsUsingBlock:^(PHAsset *asset, NSUInteger idx, BOOL *assetStop) {
                if ([localIdentifier isEqualToString:asset.localIdentifier]) {
                    *assetStop = YES;
                    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                        [PHAssetChangeRequest deleteAssets:@[asset]];
                    } completionHandler:^(BOOL success, NSError *error) {
                        if (completionHandler != nil) {
                            completionHandler(success, error);
                        }
                    }];
                }
            }];
        }
    }];
}

- (void)_saveFile:(BOOL)isImage image:(UIImage *)img videoPath:(NSString *)videoPath semaphore:(dispatch_semaphore_t)sem completionHandler:(nullable void(^)(BOOL success, NSError *__nullable error))completionHandler {
    //首先获取相册的集合
    PHFetchResult *collectonResuts = [PHCollectionList fetchTopLevelUserCollectionsWithOptions:nil];
    //对获取到集合进行遍历
    [collectonResuts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        PHAssetCollection *assetCollection = obj;
        //Camera Roll是我们写入照片的相册
        if ([assetCollection.localizedTitle isEqualToString:self->_albumsName])  {
            *stop = YES;
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                //请求创建一个Asset
                PHAssetChangeRequest *assetRequest;
                if (isImage) {
                    assetRequest = [PHAssetChangeRequest creationRequestForAssetFromImage:img];
                }
                else {
                    NSURL *url = [NSURL fileURLWithPath:videoPath];
                    assetRequest = [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
                }
                //请求编辑相册
                PHAssetCollectionChangeRequest *collectonRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:assetCollection];
                //为Asset创建一个占位符，放到相册编辑请求中
                PHObjectPlaceholder *placeHolder = [assetRequest placeholderForCreatedAsset];
                //相册中添加照片 或者 视频
                [collectonRequest addAssets:@[placeHolder]];
                
            } completionHandler:^(BOOL success, NSError *error) {
                dispatch_semaphore_signal(sem);
                if (completionHandler != nil) {
                    completionHandler(success, error);
                }
            }];
        }
    }];
}

- (void)checkShouldCreateAlbums {
    NSAssert([self isExistAlbums], @"请先调用 -createAlbums: 创建相册");
}

- (BOOL)isExistAlbums {
    //首先获取用户手动创建相册的集合
    PHFetchResult *collectonResuts = [PHCollectionList fetchTopLevelUserCollectionsWithOptions:nil];
    
    __block BOOL isExisted = NO;
    //对获取到集合进行遍历
    [collectonResuts enumerateObjectsUsingBlock:^(PHAssetCollection *assetCollection, NSUInteger idx, BOOL *stop) {
        //albumsName是我们写入照片的相册
        if ([assetCollection.localizedTitle isEqualToString:self->_albumsName])  {
            isExisted = YES;
            *stop = YES;
            NSLog(@"%@ 已经存在", self->_albumsName);
        }
    }];
    
    return isExisted;
}

@end
