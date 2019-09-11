//
//  ViewController.m
//  ZSAssetOperator
//
//  Created by zishu on 9/11/19.
//  Copyright © 2019 zishu. All rights reserved.
//

#import <Photos/Photos.h>

#import "ViewController.h"

#import "ZSAssetOperator.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *imgV;
@property (nonatomic) NSArray <ZSAssetModel *> *albumArr;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self requestAuthorization];
}

- (void)requestAuthorization {
    PHAuthorizationStatus authorizationStatus = [PHPhotoLibrary authorizationStatus];
    // 已经允许
    if (authorizationStatus == PHAuthorizationStatusAuthorized) {
        
    }
    else {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            
            if (status == PHAuthorizationStatusAuthorized) {
                NSLog(@"用户已经授权");
            }
            else {
                NSLog(@"用户未授权");
            }
        }];
    }
}
- (IBAction)createAlbum:(id)sender {
    [[ZSAssetOperator sharedOperator] createAlbums:@"111"];
}

- (IBAction)saveFileToAlbum:(id)sender {
    
    for (int i = 0; i < 12; i++) {
        NSString *imgName = [NSString stringWithFormat:@"img%d.jpg", i];
        NSString *path = [[NSBundle mainBundle] pathForResource:imgName ofType:nil];
        UIImage *img = [UIImage imageWithContentsOfFile:path];
        [[ZSAssetOperator sharedOperator] saveImage:img completionHandler:^(BOOL success, NSError * _Nullable error) {
            if (!success) {
                NSLog(@"i: %d 失败: path : %@", i, path);
            }
            else {
                NSLog(@"成功存入 %@", imgName);
            }
        }];
    }
    
    NSString *vPath1 = [[NSBundle mainBundle] pathForResource:@"video1.mp4" ofType:nil];
    NSString *vPath2 = [[NSBundle mainBundle] pathForResource:@"video2.mp4" ofType:nil];
    [[ZSAssetOperator sharedOperator] saveVideoPath:vPath1 completionHandler:^(BOOL success, NSError * _Nullable error) {
        if (!success) {
            NSLog(@"失败: v1 err : %@", error);
        }
        else {
            NSLog(@"成功存入 v1");
        }
    }];
    
    [[ZSAssetOperator sharedOperator] saveVideoPath:vPath2 completionHandler:^(BOOL success, NSError * _Nullable error) {
        if (!success) {
            NSLog(@"失败: v2 err : %@", error);
        }
        else {
            NSLog(@"成功存入 v2");
        }
    }];
    
    
}

- (IBAction)getFileFromUserAlbum:(id)sender {
    self.albumArr = [[ZSAssetOperator sharedOperator] getImagesAndVideoFromFolder];

    //    self.imgV.image = self.albumArr.lastObject.image;
    
}

- (IBAction)delFile:(id)sender {
    ZSAssetModel *model = self.albumArr.firstObject;
    [[ZSAssetOperator sharedOperator] deleteFileWith:model.localIdentifier completionHandler:^(BOOL success, NSError * _Nonnull error) {
        if (success) {
            NSLog(@"删除成功");
        }
    }];
}

@end
