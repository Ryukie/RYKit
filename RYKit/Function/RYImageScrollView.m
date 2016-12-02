//
//  RYImageScrollView.m
//  BigFan
//
//  Created by RongqingWang on 16/10/13.
//  Copyright © 2016年 QuanYan. All rights reserved.
//

#import "RYImageScrollView.h"
#import "RYImagePicker.h"

NSString * const RYAssetScrollViewDidTapNotification = @"RYAssetScrollViewDidTapNotification";
NSString * const RYAssetScrollViewPlayerWillPlayNotification = @"RYAssetScrollViewPlayerWillPlayNotification";
NSString * const RYAssetScrollViewPlayerWillPauseNotification = @"RYAssetScrollViewPlayerWillPauseNotification";

@interface RYImageScrollView ()<UIScrollViewDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, assign) BOOL didLoadPlayerItem;
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, assign) BOOL shouldUpdateConstraints;
@property (nonatomic, assign) BOOL didSetupConstraints;
@property (nonatomic, assign) CGFloat perspectiveZoomScale;
@property (nonatomic, strong) PHAsset *asset;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) UIActivityIndicatorView *activityView;

@end

@implementation RYImageScrollView

#pragma mark - init
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        _shouldUpdateConstraints = YES;
        self.allowsSelection = NO;
        self.showsVerticalScrollIndicator = NO;
        self.showsHorizontalScrollIndicator = NO;
        self.bouncesZoom = YES;
        self.decelerationRate = UIScrollViewDecelerationRateFast;
        self.delegate = self;
        
        [self setUpUI];
        [self addGestureRecognizers];
    }
    return self;
}

#pragma mark - set
- (void)setUpUI {
    self.backgroundColor = [UIColor blackColor];
    
    UIImageView *imageView = [UIImageView new];
    imageView.isAccessibilityElement    = YES;
    imageView.accessibilityTraits       = UIAccessibilityTraitImage;
    self.imageView = imageView;
    [self addSubview:self.imageView];
    
    UIActivityIndicatorView *activityView =
    [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.activityView = activityView;
    [self addSubview:self.activityView];
    
}

#pragma mark - Update auto layout constraints
- (void)updateConstraints {
    [self updateContentFrame];
    [super updateConstraints];
}

- (void)updateContentFrame {
    CGSize boundsSize = self.bounds.size;
    
    CGFloat w = self.zoomScale * self.asset.pixelWidth;
    CGFloat h = self.zoomScale * self.asset.pixelHeight;
    
    CGFloat dx = (boundsSize.width - w) / 2.0;
    CGFloat dy = (boundsSize.height - h) / 2.0;
    
    self.contentOffset = CGPointZero;
    self.imageView.frame = CGRectMake(dx, dy, w, h);
}

#pragma mark - Bind asset image
- (void)bind:(PHAsset *)asset image:(UIImage *)image requestInfo:(NSDictionary *)info {
    self.asset = asset;
    self.imageView.accessibilityLabel = asset.accessibilityLabel;
    
    BOOL isDegraded = [info[PHImageResultIsDegradedKey] boolValue];
    
    if (self.image == nil || !isDegraded) {
        BOOL zoom = (!self.image);
        self.image = image;
        self.imageView.image = image;
        
        [self setNeedsUpdateConstraints];
        [self updateConstraintsIfNeeded];
        [self updateZoomScalesAndZoom:zoom];
    }
}

#pragma mark - Gesture recognizers
- (void)addGestureRecognizers {
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapping:)];
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapping:)];
    
    [doubleTap setNumberOfTapsRequired:2.0];
    [singleTap requireGestureRecognizerToFail:doubleTap];
    
    [singleTap setDelegate:self];
    [doubleTap setDelegate:self];
    
    [self addGestureRecognizer:singleTap];
    [self addGestureRecognizer:doubleTap];
}

#pragma mark - Gesture recognizer delegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    return YES;
}


#pragma mark - Handle tappings
- (void)handleTapping:(UITapGestureRecognizer *)recognizer {
    [[NSNotificationCenter defaultCenter] postNotificationName:RYAssetScrollViewDidTapNotification object:recognizer];
    
    if (recognizer.numberOfTapsRequired == 2) {
        if (self.cellModel.asset.mediaType == PHAssetMediaTypeVideo) {
            
        } else {
            [self zoomWithGestureRecognizer:recognizer];
        }
    } else if(recognizer.numberOfTapsRequired == 1) {
        if (self.cellModel.asset.mediaType == PHAssetMediaTypeVideo) {//如果是视频就播放
            if (self.playerLayer && self.player) {
                if (self.isPlaying == NO) {//self.player.timeControlStatus 这个属性只有iOS10有
                    [self.player play];
                } else {
                    self.isPlaying = NO;
                    [self.player pause];
                }
            } else {
                [[PHImageManager defaultManager] requestAVAssetForVideo:self.cellModel.asset
                                                                options:nil
                                                          resultHandler:^(AVAsset *avAsset, AVAudioMix *audioMix, NSDictionary *info) {
                                                              dispatch_async(dispatch_get_main_queue(), ^{
                                                                  CALayer *viewLayer = self.layer;
                                                                  
                                                                  // Create an AVPlayerItem for the AVAsset.
                                                                  AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:avAsset];
                                                                  playerItem.audioMix = audioMix;
                                                                  
                                                                  // Create an AVPlayer with the AVPlayerItem.
                                                                  AVPlayer *player = [AVPlayer playerWithPlayerItem:playerItem];
                                                                  player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
                                                                  
                                                                  // Create an AVPlayerLayer with the AVPlayer.
                                                                  AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:player];
                                                                  
                                                                  // Configure the AVPlayerLayer and add it to the view.
                                                                  playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
                                                                  playerLayer.frame = CGRectMake(0, 0, viewLayer.bounds.size.width, viewLayer.bounds.size.height);
                                                                  
                                                                  [viewLayer addSublayer:playerLayer];
                                                                  [player play];
                                                                  self.isPlaying = YES;
                                                                  
                                                                  // Store a reference to the player layer we added to the view.
                                                                  self.playerLayer = playerLayer;
                                                                  self.player = player;
                                                              });
                                                          }];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:kRYImagePickerOneClick object:self userInfo:@{
                                                                                                                     @"isVideo":@1
                                                                                                                     }];
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:kRYImagePickerOneClick object:self userInfo:nil];
        }
    }
}

#pragma mark - Scroll view delegate
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.imageView;
}

- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view {
    self.shouldUpdateConstraints = YES;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    [self setScrollEnabled:(self.zoomScale != self.perspectiveZoomScale)];
    
    if (self.shouldUpdateConstraints) {
        [self setNeedsUpdateConstraints];
        [self updateConstraintsIfNeeded];
    }
}

#pragma mark - Zoom with gesture recognizer
- (void)zoomWithGestureRecognizer:(UITapGestureRecognizer *)recognizer {
    if (self.minimumZoomScale == self.maximumZoomScale)
        return;
    
    if ([self canPerspectiveZoom]) {
        if ((self.zoomScale >= self.minimumZoomScale && self.zoomScale < self.perspectiveZoomScale) ||
            (self.zoomScale <= self.maximumZoomScale && self.zoomScale > self.perspectiveZoomScale))
            [self zoomToPerspectiveZoomScaleAnimated:YES];
        else
            [self zoomToMaximumZoomScaleWithGestureRecognizer:recognizer];
        
        return;
    }
    
    //某些分辨率的图片   放大后双击还原出现异常   通过改变减小精度来确保没问题
    /**
     放大状态到缩小状态时的比例...
     (lldb) po self.zoomScale
     0.7961538461538461
     (lldb) po self.maximumZoomScale
     0.79615384615384621
     */
    if ((float)self.zoomScale < (float)self.maximumZoomScale)
        [self zoomToMaximumZoomScaleWithGestureRecognizer:recognizer];
    else
        [self zoomToMinimumZoomScaleAnimated:YES];
}

- (CGRect)zoomRectWithScale:(CGFloat)scale withCenter:(CGPoint)center {
    center = [self.imageView convertPoint:center fromView:self];
    
    CGRect zoomRect;
    
    zoomRect.size.height = self.imageView.frame.size.height / scale;
    zoomRect.size.width  = self.imageView.frame.size.width  / scale;
    
    zoomRect.origin.x    = center.x - ((zoomRect.size.width / 2.0));
    zoomRect.origin.y    = center.y - ((zoomRect.size.height / 2.0));
    
    return zoomRect;
}

#pragma mark - Zoom
- (void)zoomToInitialScale {
    if ([self canPerspectiveZoom]) {
        [self zoomToPerspectiveZoomScaleAnimated:NO];
    }
    else {
        [self zoomToMinimumZoomScaleAnimated:NO];
    }
}

- (void)zoomToMinimumZoomScaleAnimated:(BOOL)animated {
    [self setZoomScale:self.minimumZoomScale animated:animated];
}

- (void)zoomToMaximumZoomScaleWithGestureRecognizer:(UITapGestureRecognizer *)recognizer {
    CGRect zoomRect = [self zoomRectWithScale:self.maximumZoomScale withCenter:[recognizer locationInView:recognizer.view]];
    
    self.shouldUpdateConstraints = NO;
    
    [UIView animateWithDuration:0.3 animations:^{
        [self zoomToRect:zoomRect animated:NO];
        
        CGRect frame = self.imageView.frame;
        frame.origin.x = 0;
        frame.origin.y = 0;
        
        self.imageView.frame = frame;
    }];
}

#pragma mark - Perspective zoom
- (BOOL)canPerspectiveZoom {
    CGSize assetSize    = [self assetSize];
    CGSize boundsSize   = self.bounds.size;
    
    CGFloat assetRatio  = assetSize.width / assetSize.height;
    CGFloat boundsRatio = boundsSize.width / boundsSize.height;
    
    // can perform perspective zoom when the difference of aspect ratios is smaller than 20%
    return (fabs( (assetRatio - boundsRatio) / boundsRatio ) < 0.2f);
}

- (void)zoomToPerspectiveZoomScaleAnimated:(BOOL)animated; {
    CGRect zoomRect = [self zoomRectWithScale:self.perspectiveZoomScale];
    [self zoomToRect:zoomRect animated:animated];
}

- (CGRect)zoomRectWithScale:(CGFloat)scale {
    CGSize targetSize;
    targetSize.width    = self.bounds.size.width / scale;
    targetSize.height   = self.bounds.size.height / scale;
    
    CGPoint targetOrigin;
    targetOrigin.x      = (self.asset.pixelWidth - targetSize.width) / 2.0;
    targetOrigin.y      = (self.asset.pixelHeight - targetSize.height) / 2.0;
    
    CGRect zoomRect;
    zoomRect.origin = targetOrigin;
    zoomRect.size   = targetSize;
    
    return zoomRect;
}

#pragma mark - Upate zoom scales
- (void)updateZoomScalesAndZoom:(BOOL)zoom {
    if (!self.asset)
        return;
    
    CGSize assetSize    = [self assetSize];
    CGSize boundsSize   = self.bounds.size;
    
    CGFloat xScale = boundsSize.width / assetSize.width;    //scale needed to perfectly fit the image width-wise
    CGFloat yScale = boundsSize.height / assetSize.height;  //scale needed to perfectly fit the image height-wise
    
    CGFloat minScale = MIN(xScale, yScale);
    CGFloat maxScale = 3.0 * minScale;
    
    self.minimumZoomScale = minScale;
    self.maximumZoomScale = maxScale;
    
    // update perspective zoom scale
    self.perspectiveZoomScale = (boundsSize.width > boundsSize.height) ? xScale : yScale;
    
    if (zoom)
        [self zoomToInitialScale];
}


#pragma mark - asset size
- (CGSize)assetSize {
    return CGSizeMake(self.asset.pixelWidth, self.asset.pixelHeight);
}

@end
