#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <AVFoundation/AVFoundation.h>

// 抖音类的前向声明
@class AWEAwemeModel, AWEVideoModel, AWEImageAlbumImageModel, AWEURLModel;
@class AWEPlayInteractionViewController;
@class PipContainerView;

// 抖音相关接口声明
@interface AWEAwemeModel : NSObject
@property (nonatomic, assign) NSInteger awemeType;
@property (nonatomic, assign) NSInteger currentImageIndex;
@property (nonatomic, strong) NSArray *albumImages;
@property (nonatomic, strong) AWEVideoModel *video;
- (NSString *)awemeId;
- (NSString *)awemeID;
@end

@interface AWEVideoModel : NSObject
@property (nonatomic, strong) AWEURLModel *playURL;
@property (nonatomic, strong) AWEURLModel *h264URL;
@property (nonatomic, strong) AWEURLModel *coverURL;
@end

@interface AWEURLModel : NSObject
@property (nonatomic, strong) NSArray<NSString *> *originURLList;
@end

@interface AWEImageAlbumImageModel : NSObject
@property (nonatomic, strong) NSArray<NSString *> *urlList;
@end

@interface AWEPlayInteractionViewController : UIViewController
@property (nonatomic, strong) AWEAwemeModel *awemeModel;
@end

// PIP管理器
@interface PIPManager : NSObject
+ (instancetype)sharedManager;
@property (nonatomic, strong) PipContainerView *currentPipContainer;
@property (nonatomic, strong) UIButton *pipButton;
@property (nonatomic, weak) AWEAwemeModel *currentAwemeModel;
@property (nonatomic, strong) NSTimer *fadeTimer;
- (void)showPipButtonForAwemeModel:(AWEAwemeModel *)awemeModel;
- (void)hidePipButton;
- (void)handlePipButtonTapped;
- (void)showPipButtonWithFullOpacity;
- (void)fadeToLowOpacity;
@end

// Toast管理器
@interface ToastManager : NSObject
+ (void)showToast:(NSString *)message;
+ (void)showToast:(NSString *)message duration:(NSTimeInterval)duration;
@end

@implementation ToastManager

+ (void)showToast:(NSString *)message {
    [self showToast:message duration:2.0];
}

+ (void)showToast:(NSString *)message duration:(NSTimeInterval)duration {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        if (!keyWindow) {
            keyWindow = [UIApplication sharedApplication].windows.firstObject;
        }
        
        if (!keyWindow || !message.length) return;
        for (UIView *subview in keyWindow.subviews) {
            if (subview.tag == 999888) {
                [subview removeFromSuperview];
            }
        }
        
        UILabel *toastLabel = [[UILabel alloc] init];
        toastLabel.text = message;
        toastLabel.textColor = [UIColor whiteColor];
        toastLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
        toastLabel.textAlignment = NSTextAlignmentCenter;
        toastLabel.font = [UIFont systemFontOfSize:16];
        toastLabel.layer.cornerRadius = 8;
        toastLabel.clipsToBounds = YES;
        toastLabel.numberOfLines = 0;
        toastLabel.tag = 999888;
        
        CGSize textSize = [message boundingRectWithSize:CGSizeMake(keyWindow.bounds.size.width - 80, CGFLOAT_MAX)
                                               options:NSStringDrawingUsesLineFragmentOrigin
                                            attributes:@{NSFontAttributeName: toastLabel.font}
                                               context:nil].size;
        
        CGFloat width = MIN(textSize.width + 40, keyWindow.bounds.size.width - 40);
        CGFloat height = textSize.height + 20;
        
        toastLabel.frame = CGRectMake((keyWindow.bounds.size.width - width) / 2,
                                      keyWindow.bounds.size.height / 2 - height / 2,
                                      width, height);
        
        [keyWindow addSubview:toastLabel];
        
        toastLabel.alpha = 0;
        [UIView animateWithDuration:0.3 animations:^{
            toastLabel.alpha = 1.0;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.3 delay:duration options:UIViewAnimationOptionCurveEaseInOut animations:^{
                toastLabel.alpha = 0;
            } completion:^(BOOL finished) {
                [toastLabel removeFromSuperview];
            }];
        }];
    });
}

@end

@interface PipContainerView : UIView <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIView *mediaDecorationLayer;
@property (nonatomic, strong) UIView *contentContainerLayer;
@property (nonatomic, strong) UIView *danmakuContainerLayer;
@property (nonatomic, strong) UIView *diggAnimationContainer;
@property (nonatomic, strong) UIView *operationContainerLayer;
@property (nonatomic, strong) UIView *floatContainerLayer;
@property (nonatomic, strong) UIView *keyboardContainerLayer;
@property (nonatomic, strong) UIButton *soundButton;
@property (nonatomic, weak) UIView *originalParentView;
@property (nonatomic, assign) CGRect originalFrame;
@property (nonatomic, weak) UIView *playerView;
@property (nonatomic, strong) AWEAwemeModel *awemeModel;
@property (nonatomic, strong) AVPlayer *pipPlayer;
@property (nonatomic, strong) AVPlayerLayer *pipPlayerLayer;
@property (nonatomic, assign) BOOL isPlayingInPip;
- (NSString *)getAwemeId;
- (void)setupPipPlayerWithAwemeModel:(AWEAwemeModel *)awemeModel;
- (void)updatePipPlayerWithAwemeModel:(AWEAwemeModel *)awemeModel;
- (void)_closeAndStopPip;
@end

@implementation PIPManager

+ (instancetype)sharedManager {
    static PIPManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[PIPManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    if (self = [super init]) {
        [self setupPipButton];
    }
    return self;
}

- (void)setupPipButton {
    self.pipButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.pipButton.frame = CGRectMake(0, 0, 44, 44);
    self.pipButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
    self.pipButton.layer.cornerRadius = 22;
    // 移除边框
    // self.pipButton.layer.borderWidth = 2;
    // self.pipButton.layer.borderColor = [UIColor whiteColor].CGColor;
    
    if (@available(iOS 13.0, *)) {
        UIImage *pipImage = [UIImage systemImageNamed:@"pip.enter"];
        [self.pipButton setImage:pipImage forState:UIControlStateNormal];
        self.pipButton.tintColor = [UIColor whiteColor];
    } else {
        [self.pipButton setTitle:@"PiP" forState:UIControlStateNormal];
        [self.pipButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.pipButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    }
    
    [self.pipButton addTarget:self action:@selector(handlePipButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    self.pipButton.layer.shadowColor = [UIColor blackColor].CGColor;
    self.pipButton.layer.shadowOffset = CGSizeMake(0, 2);
    self.pipButton.layer.shadowOpacity = 0.3;
    self.pipButton.layer.shadowRadius = 4;
    
    self.pipButton.hidden = YES;
}

// 显示完全不透明的按钮
- (void)showPipButtonWithFullOpacity {
    [self.fadeTimer invalidate];
    self.fadeTimer = nil;
    
    [UIView animateWithDuration:0.3 animations:^{
        self.pipButton.alpha = 1.0;
    }];
    
    // 3秒后淡化
    self.fadeTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                      target:self
                                                    selector:@selector(fadeToLowOpacity)
                                                    userInfo:nil
                                                     repeats:NO];
}

// 淡化到低透明度
- (void)fadeToLowOpacity {
    [UIView animateWithDuration:0.5 animations:^{
        self.pipButton.alpha = 0.3; // 变暗但不隐藏
    }];
}

- (void)showPipButtonForAwemeModel:(AWEAwemeModel *)awemeModel {
    NSLog(@"showPipButtonForAwemeModel 被调用，awemeModel: %@", awemeModel);
    
    // 检查视频模型和类型是否有效
    if (!awemeModel) {
        NSLog(@"awemeModel 为空");
        [self hidePipButton];
        return;
    }
    
    NSLog(@"awemeModel.awemeType: %ld", (long)awemeModel.awemeType);
    
    if (awemeModel.awemeType != 0 && awemeModel.awemeType != 2 && awemeModel.awemeType != 68) {
        NSLog(@"不支持的视频类型: %ld", (long)awemeModel.awemeType);
        [self hidePipButton];
        return;
    }
    
    // 确保每次都更新为当前视频模型
    self.currentAwemeModel = awemeModel;
    
    // 确保在主窗口上显示
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) {
        keyWindow = [UIApplication sharedApplication].windows.firstObject;
    }
    
    if (!keyWindow) {
        NSLog(@"未找到主窗口");
        return;
    }
    
    NSLog(@"准备显示PIP按钮");
    
    // 如果按钮已在视图中，则显示完全不透明
    if (self.pipButton.superview == keyWindow) {
        NSLog(@"PIP按钮已在视图中，重置为完全不透明");
        [self showPipButtonWithFullOpacity];
        return;
    }
    
    [self.pipButton removeFromSuperview];
    
    CGFloat safeAreaTop = 0;
    CGFloat safeAreaRight = 0;
    
    if (@available(iOS 11.0, *)) {
        safeAreaTop = keyWindow.safeAreaInsets.top;
        safeAreaRight = keyWindow.safeAreaInsets.right;
    }
    
    CGFloat buttonX = keyWindow.bounds.size.width - 44 - 20 - safeAreaRight;
    CGFloat buttonY = safeAreaTop + 60;
    
    self.pipButton.frame = CGRectMake(buttonX, buttonY, 44, 44);
    self.pipButton.hidden = NO;
    
    [keyWindow addSubview:self.pipButton];
    
    NSLog(@"PIP按钮已添加到窗口，位置: %@", NSStringFromCGRect(self.pipButton.frame));
    
    self.pipButton.alpha = 0;
    self.pipButton.transform = CGAffineTransformMakeScale(0.5, 0.5);
    
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.pipButton.alpha = 1.0;
        self.pipButton.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        NSLog(@"PIP按钮显示动画完成");
        // 显示完成后开始淡化计时器
        [self showPipButtonWithFullOpacity];
    }];
}

- (void)hidePipButton {
    // 停止淡化定时器
    [self.fadeTimer invalidate];
    self.fadeTimer = nil;
    
    // 只有当按钮在视图上时才执行移除操作
    if (self.pipButton.superview) {
        [self.pipButton removeFromSuperview];
    }
    self.pipButton.hidden = YES;
    self.currentAwemeModel = nil;
}

- (void)handlePipButtonTapped {
    if (!self.currentAwemeModel) {
        [ToastManager showToast:@"视频信息获取失败"];
        return;
    }
    
    NSLog(@"处理PIP按钮点击，当前视频ID: %@", [self.currentAwemeModel respondsToSelector:@selector(awemeId)] ? [self.currentAwemeModel awemeId] : @"未知");
    
    // 点击后立即隐藏按钮
    if (!self.currentPipContainer || !self.currentPipContainer.superview) {
        // 没有小窗时，创建小窗并隐藏PIP按钮
        self.pipButton.hidden = YES;
    }
    
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) {
        keyWindow = [UIApplication sharedApplication].windows.firstObject;
    }
    
    if (!keyWindow) {
        [ToastManager showToast:@"错误：未找到主窗口"];
        return;
    }
    
    // 如果已有小窗，则更新内容，而不是创建新的
    if (self.currentPipContainer && self.currentPipContainer.superview) {
        NSLog(@"更新现有PIP容器内容");
        [self.currentPipContainer updatePipPlayerWithAwemeModel:self.currentAwemeModel];
        return;
    }
    
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    CGFloat safeAreaTop = 0;
    if (@available(iOS 11.0, *)) {
        safeAreaTop = keyWindow.safeAreaInsets.top;
    }
    
    CGFloat pipWidth = 160;
    CGFloat pipHeight = 284;
    CGFloat margin = 20;
    
    CGFloat pipX = screenBounds.size.width - pipWidth - margin;
    CGFloat pipY = safeAreaTop + 20;
    
    PipContainerView *pipContainer = [[PipContainerView alloc] initWithFrame:CGRectMake(pipX, pipY, pipWidth, pipHeight)];
    
    [pipContainer setupPipPlayerWithAwemeModel:self.currentAwemeModel];
    
    self.currentPipContainer = pipContainer;
    
    [keyWindow addSubview:pipContainer];
    
    pipContainer.alpha = 0;
    pipContainer.transform = CGAffineTransformMakeScale(0.3, 0.3);
    
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
        pipContainer.alpha = 1.0;
        pipContainer.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end

@implementation PipContainerView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        self.layer.cornerRadius = 12;
        self.clipsToBounds = YES;
        self.isPlayingInPip = NO;
        
        self.mediaDecorationLayer = [[UIView alloc] initWithFrame:self.bounds];
        self.mediaDecorationLayer.backgroundColor = [UIColor blackColor];
        self.mediaDecorationLayer.layer.cornerRadius = 12;
        [self addSubview:self.mediaDecorationLayer];
        
        self.contentContainerLayer = [[UIView alloc] initWithFrame:self.bounds];
        self.contentContainerLayer.layer.cornerRadius = 12;
        self.contentContainerLayer.clipsToBounds = YES;
        [self addSubview:self.contentContainerLayer];
        
        self.danmakuContainerLayer = [[UIView alloc] initWithFrame:self.bounds];
        [self addSubview:self.danmakuContainerLayer];
        
        self.diggAnimationContainer = [[UIView alloc] initWithFrame:self.bounds];
        [self addSubview:self.diggAnimationContainer];
        
        self.operationContainerLayer = [[UIView alloc] initWithFrame:self.bounds];
        [self addSubview:self.operationContainerLayer];
        
        self.floatContainerLayer = [[UIView alloc] initWithFrame:self.bounds];
        [self addSubview:self.floatContainerLayer];
        
        self.keyboardContainerLayer = [[UIView alloc] initWithFrame:self.bounds];
        [self addSubview:self.keyboardContainerLayer];
        
        UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        closeButton.frame = CGRectMake(8, 8, 28, 28);
        closeButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
        closeButton.layer.cornerRadius = 14;
        [closeButton setTitle:@"×" forState:UIControlStateNormal];
        [closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        closeButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
        closeButton.tag = 9998;
        [closeButton addTarget:self action:@selector(_closeAndStopPip) forControlEvents:UIControlEventTouchUpInside];
        
        closeButton.layer.borderWidth = 1.0;
        closeButton.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3].CGColor;
        [self addSubview:closeButton];
        
        UIButton *soundButton = [UIButton buttonWithType:UIButtonTypeCustom];
        soundButton.frame = CGRectMake(self.bounds.size.width - 36, 8, 28, 28);
        soundButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
        soundButton.layer.cornerRadius = 14;
        
        if (@available(iOS 13.0, *)) {
            UIImage *mutedImage = [UIImage systemImageNamed:@"speaker.slash.fill"];
            [soundButton setImage:mutedImage forState:UIControlStateNormal];
            soundButton.tintColor = [UIColor whiteColor];
        } else {
            [soundButton setTitle:@"🔇" forState:UIControlStateNormal];
            soundButton.titleLabel.font = [UIFont systemFontOfSize:14];
        }
        
        soundButton.layer.borderWidth = 1.0;
        soundButton.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3].CGColor;
        
        soundButton.accessibilityLabel = @"切换声音";
        soundButton.tag = 9997;
        
        [soundButton addTarget:self action:@selector(_toggleSound) forControlEvents:UIControlEventTouchUpInside];
        
        self.soundButton = soundButton;
        [self addSubview:soundButton];
        
        // 点击悬浮窗触发功能并隐藏悬浮窗图标
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleContainerTap:)];
        tapGesture.numberOfTapsRequired = 1;
        tapGesture.delegate = self;
        [self addGestureRecognizer:tapGesture];
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_handlePipPan:)];
        pan.delegate = self;
        [self addGestureRecognizer:pan];
        
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(handleAppDidEnterBackground) 
                                                     name:UIApplicationDidEnterBackgroundNotification 
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(handleAppWillEnterForeground) 
                                                     name:UIApplicationWillEnterForegroundNotification 
                                                   object:nil];
    }
    return self;
}

- (void)_toggleSound {
    if (!self.pipPlayer) {
        return;
    }
    
    BOOL currentlyMuted = self.pipPlayer.isMuted;
    
    if (currentlyMuted) {
        self.pipPlayer.muted = NO;
        self.pipPlayer.volume = 1.0;
        
        if (@available(iOS 13.0, *)) {
            UIImage *soundImage = [UIImage systemImageNamed:@"speaker.wave.2.fill"];
            [self.soundButton setImage:soundImage forState:UIControlStateNormal];
        } else {
            [self.soundButton setTitle:@"🔊" forState:UIControlStateNormal];
        }
        
        self.soundButton.accessibilityLabel = @"静音";
    } else {
        self.pipPlayer.muted = YES;
        self.pipPlayer.volume = 0.0;
        
        if (@available(iOS 13.0, *)) {
            UIImage *mutedImage = [UIImage systemImageNamed:@"speaker.slash.fill"];
            [self.soundButton setImage:mutedImage forState:UIControlStateNormal];
        } else {
            [self.soundButton setTitle:@"🔇" forState:UIControlStateNormal];
        }
        
        self.soundButton.accessibilityLabel = @"开启声音";
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    CGPoint location = [touch locationInView:self];
    
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
        CGRect closeButtonArea = CGRectMake(0, 0, 44, 44);
        if (CGRectContainsPoint(closeButtonArea, location)) {
            return NO;
        }
        
        CGRect soundButtonArea = CGRectMake(self.bounds.size.width - 44, 0, 44, 44);
        if (CGRectContainsPoint(soundButtonArea, location)) {
            return NO;
        }
    }
    
    return YES;
}

// 点击悬浮窗触发功能并隐藏悬浮窗图标
- (void)_handleContainerTap:(UITapGestureRecognizer *)tap {
    CGPoint location = [tap locationInView:self];
    
    CGRect closeButtonArea = CGRectMake(0, 0, 44, 44);
    if (CGRectContainsPoint(closeButtonArea, location)) {
        return;
    }
    
    CGRect soundButtonArea = CGRectMake(self.bounds.size.width - 44, 0, 44, 44);
    if (CGRectContainsPoint(soundButtonArea, location)) {
        return;
    }
    
    // 获取当前正在观看的视频控制器
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) {
        keyWindow = [UIApplication sharedApplication].windows.firstObject;
    }
    
    AWEPlayInteractionViewController *playController = [self _findPlayInteractionViewController:keyWindow];
    
    if (playController && playController.awemeModel) {
        // 使用当前视频更新小窗内容
        [self updatePipPlayerWithAwemeModel:playController.awemeModel];
        
        // 同时更新PIPManager中的当前视频模型
        PIPManager *pipManager = [PIPManager sharedManager];
        pipManager.currentAwemeModel = playController.awemeModel;
        
        // 隐藏PIP按钮
        if (!pipManager.pipButton.hidden) {
            pipManager.pipButton.hidden = YES;
        }
        
        // 显示Toast提示用户
        [ToastManager showToast:@"已更新为当前视频" duration:1.0];
    }
}

// 切换到下一个视频的方法
- (void)_switchToNextVideo {
    // 查找当前的AWEPlayInteractionViewController
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) {
        keyWindow = [UIApplication sharedApplication].windows.firstObject;
    }
    
    AWEPlayInteractionViewController *playController = [self _findPlayInteractionViewController:keyWindow];
    
    if (playController) {
        // 尝试使用系统提供的方法切换视频
        if ([playController respondsToSelector:@selector(enterNextVideo)] ||
            [playController respondsToSelector:NSSelectorFromString(@"enterNextVideo")]) {
            NSLog(@"使用enterNextVideo方法切换视频");
            [playController performSelector:@selector(enterNextVideo)];
            return;
        }
        
        if ([playController respondsToSelector:@selector(goToNextVideo)] ||
            [playController respondsToSelector:NSSelectorFromString(@"goToNextVideo")]) {
            NSLog(@"使用goToNextVideo方法切换视频");
            [playController performSelector:@selector(goToNextVideo)];
            return;
        }
        
        // 尝试查找并点击"下一个"按钮
        UIView *nextButton = [self _findNextButtonInView:playController.view];
        if (nextButton) {
            NSLog(@"找到下一个按钮，模拟点击");
            [self _simulateButtonTap:nextButton];
            return;
        }
        
        // 如果上述方法都失败，尝试使用通知
        NSLog(@"尝试通过通知切换视频");
        [[NSNotificationCenter defaultCenter] postNotificationName:@"AWEPlayInteractionSwitchToNext" object:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"AWEFeedCellNextVideo" object:nil];
    }
}

// 查找AWEPlayInteractionViewController的递归方法
- (AWEPlayInteractionViewController *)_findPlayInteractionViewController:(UIView *)view {
    if ([view.nextResponder isKindOfClass:NSClassFromString(@"AWEPlayInteractionViewController")]) {
        return (AWEPlayInteractionViewController *)view.nextResponder;
    }
    
    for (UIView *subview in view.subviews) {
        AWEPlayInteractionViewController *result = [self _findPlayInteractionViewController:subview];
        if (result) {
            return result;
        }
    }
    
    return nil;
}

// 查找下一个按钮的递归方法
- (UIView *)_findNextButtonInView:(UIView *)view {
    // 检查当前视图是否是按钮
    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        
        // 检查按钮标题
        NSString *title = [button titleForState:UIControlStateNormal];
        if (title && ([title isEqualToString:@"下一个"] || 
                     [title isEqualToString:@"Next"] || 
                     [title containsString:@"下一"] ||
                     [title containsString:@"next"])) {
            return button;
        }
        
        // 检查辅助功能标签
        if (button.accessibilityLabel && 
            ([button.accessibilityLabel containsString:@"下一"] || 
             [button.accessibilityLabel containsString:@"next"])) {
            return button;
        }
    }
    
    // 递归检查子视图
    for (UIView *subview in view.subviews) {
        UIView *nextButton = [self _findNextButtonInView:subview];
        if (nextButton) {
            return nextButton;
        }
    }
    
    return nil;
}

// 模拟按钮点击
- (void)_simulateButtonTap:(UIView *)button {
    if (![button isKindOfClass:[UIButton class]]) {
        return;
    }
    
    UIButton *btn = (UIButton *)button;
    
    // 尝试通过发送操作来点击按钮
    [btn sendActionsForControlEvents:UIControlEventTouchUpInside];
    
    // 备用方法：模拟触摸事件序列
    CGPoint point = CGPointMake(button.bounds.size.width / 2, button.bounds.size.height / 2);
    
    // 创建触摸开始事件
    UITouch *touch = [[UITouch alloc] init];
    if ([touch respondsToSelector:@selector(setLocation:inView:)]) {
        [touch setValue:@(UITouchPhaseBegan) forKey:@"phase"];
        [touch setValue:button forKey:@"view"];
        [touch setValue:@(point) forKey:@"locationInWindow"];
        
        UIEvent *event = [[UIEvent alloc] init];
        [event setValue:@(UIEventTypeTouches) forKey:@"type"];
        [event setValue:[NSSet setWithObject:touch] forKey:@"touches"];
        
        [button touchesBegan:[NSSet setWithObject:touch] withEvent:event];
        
        // 创建触摸结束事件
        [touch setValue:@(UITouchPhaseEnded) forKey:@"phase"];
        [button touchesEnded:[NSSet setWithObject:touch] withEvent:event];
    }
}

// 模拟向上滑动手势
- (void)_simulateSwipeUpGesture:(UIViewController *)viewController {
    UIView *targetView = viewController.view;
    
    // 创建向上滑动的手势事件
    CGPoint startPoint = CGPointMake(targetView.bounds.size.width / 2, targetView.bounds.size.height * 0.8);
    CGPoint endPoint = CGPointMake(targetView.bounds.size.width / 2, targetView.bounds.size.height * 0.2);
    
    // 查找目标视图中的滑动手势识别器
    UIPanGestureRecognizer *panGesture = nil;
    for (UIGestureRecognizer *gesture in targetView.gestureRecognizers) {
        if ([gesture isKindOfClass:[UIPanGestureRecognizer class]]) {
            panGesture = (UIPanGestureRecognizer *)gesture;
            break;
        }
    }
    
    if (panGesture) {
        // 模拟手势开始
        [panGesture setValue:@(UIGestureRecognizerStateBegan) forKey:@"state"];
        [panGesture.view touchesBegan:[NSSet setWithObject:[[UITouch alloc] init]] withEvent:nil];
        
        // 模拟手势移动
        [panGesture setValue:@(UIGestureRecognizerStateChanged) forKey:@"state"];
        
        // 模拟手势结束
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [panGesture setValue:@(UIGestureRecognizerStateEnded) forKey:@"state"];
            [panGesture.view touchesEnded:[NSSet setWithObject:[[UITouch alloc] init]] withEvent:nil];
        });
    } else {
        // 如果找不到手势识别器，尝试通过通知或其他方式触发
        [self _triggerNextVideoByNotification];
    }
}

// 通过通知触发下一个视频
- (void)_triggerNextVideoByNotification {
    // 发送特定的通知来触发下一个视频
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AWEPlayInteractionSwitchToNext" object:nil];
}

- (void)_toggleControlButtons {
    static BOOL buttonsVisible = YES;
    
    [UIView animateWithDuration:0.3 animations:^{
        self.soundButton.alpha = buttonsVisible ? 0.0 : 1.0;
        
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UIButton class]] && subview != self.soundButton) {
                subview.alpha = buttonsVisible ? 0.0 : 1.0;
            }
        }
    }];
    
    buttonsVisible = !buttonsVisible;
    
    if (!buttonsVisible) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!buttonsVisible) {
                [self _toggleControlButtons];
            }
        });
    }
}

- (void)handleAppDidEnterBackground {
    if (self.pipPlayer) {
        [self.pipPlayer pause];
    }
}

- (void)handleAppWillEnterForeground {
    if (self.pipPlayer && self.isPlayingInPip) {
        [self.pipPlayer play];
    }
}

- (void)setupPipPlayerWithAwemeModel:(AWEAwemeModel *)awemeModel {
    if (!awemeModel) {
        NSLog(@"setupPipPlayerWithAwemeModel: awemeModel为空");
        return;
    }
    
    NSLog(@"设置PIP播放器，视频ID: %@，类型: %ld", 
          [awemeModel respondsToSelector:@selector(awemeId)] ? [awemeModel awemeId] : @"未知", 
          (long)awemeModel.awemeType);
    
    self.awemeModel = awemeModel;
    
    [self cleanupPreviousContent];
    
    if (awemeModel.awemeType == 68) {
        [self setupImageContentForAwemeModel:awemeModel];
    } else if (awemeModel.awemeType == 2 || awemeModel.awemeType == 0) {
        [self setupVideoContentForAwemeModel:awemeModel];
    }
    
    self.isPlayingInPip = YES;
}

- (void)cleanupPreviousContent {
    if (self.pipPlayer) {
        [self.pipPlayer pause];
        self.pipPlayer = nil;
    }
    
    if (self.pipPlayerLayer) {
        [self.pipPlayerLayer removeFromSuperlayer];
        self.pipPlayerLayer = nil;
    }
    
    for (UIView *subview in self.contentContainerLayer.subviews) {
        [subview removeFromSuperview];
    }
    
    NSArray *sublayers = [self.contentContainerLayer.layer.sublayers copy];
    for (CALayer *layer in sublayers) {
        [layer removeFromSuperlayer];
    }
}

- (void)setupImageContentForAwemeModel:(AWEAwemeModel *)awemeModel {
    if (!awemeModel.albumImages || awemeModel.albumImages.count == 0) {
        return;
    }
    
    AWEImageAlbumImageModel *currentImage = nil;
    if (awemeModel.currentImageIndex > 0 && awemeModel.currentImageIndex <= awemeModel.albumImages.count) {
        currentImage = awemeModel.albumImages[awemeModel.currentImageIndex - 1];
    } else {
        currentImage = awemeModel.albumImages.firstObject;
    }
    
    if (!currentImage || !currentImage.urlList || currentImage.urlList.count == 0) {
        return;
    }
    
    NSString *imageURLString = nil;
    for (NSString *urlString in currentImage.urlList) {
        NSURL *url = [NSURL URLWithString:urlString];
        NSString *pathExtension = [url.path.lowercaseString pathExtension];
        if (![pathExtension isEqualToString:@"image"]) {
            imageURLString = urlString;
            break;
        }
    }
    
    if (!imageURLString && currentImage.urlList.count > 0) {
        imageURLString = currentImage.urlList.firstObject;
    }
    
    if (!imageURLString) {
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:imageURLString]];
        UIImage *image = [UIImage imageWithData:imageData];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (image) {
                UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
                imageView.frame = self.contentContainerLayer.bounds;
                imageView.contentMode = UIViewContentModeScaleAspectFill;
                imageView.clipsToBounds = YES;
                [self.contentContainerLayer addSubview:imageView];
            }
        });
    });
}

- (void)setupLivePhotoForAwemeModel:(AWEAwemeModel *)awemeModel {
    if (awemeModel.video && awemeModel.video.coverURL && awemeModel.video.coverURL.originURLList.count > 0) {
        NSString *coverURLString = awemeModel.video.coverURL.originURLList.firstObject;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:coverURLString]];
            UIImage *coverImage = [UIImage imageWithData:imageData];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (coverImage) {
                    UIImageView *coverImageView = [[UIImageView alloc] initWithImage:coverImage];
                    coverImageView.frame = self.contentContainerLayer.bounds;
                    coverImageView.contentMode = UIViewContentModeScaleAspectFill;
                    coverImageView.clipsToBounds = YES;
                    [self.contentContainerLayer addSubview:coverImageView];
                }
            });
        });
    }
    
    if (awemeModel.video && awemeModel.video.playURL && awemeModel.video.playURL.originURLList.count > 0) {
        [self setupVideoContentForAwemeModel:awemeModel];
    }
}

- (void)updatePipPlayerWithAwemeModel:(AWEAwemeModel *)awemeModel {
    if (!awemeModel) return;
    
    BOOL wasMuted = self.pipPlayer ? self.pipPlayer.isMuted : YES;
    CGFloat currentVolume = self.pipPlayer ? self.pipPlayer.volume : 0.0;
    
    [self removePlayerObservers];
    
    [self setupPipPlayerWithAwemeModel:awemeModel];
    
    if (self.pipPlayer) {
        self.pipPlayer.muted = wasMuted;
        self.pipPlayer.volume = currentVolume;
        
        if (wasMuted) {
            if (@available(iOS 13.0, *)) {
                UIImage *mutedImage = [UIImage systemImageNamed:@"speaker.slash.fill"];
                [self.soundButton setImage:mutedImage forState:UIControlStateNormal];
            } else {
                [self.soundButton setTitle:@"🔇" forState:UIControlStateNormal];
            }
            self.soundButton.accessibilityLabel = @"开启声音";
        } else {
            if (@available(iOS 13.0, *)) {
                UIImage *soundImage = [UIImage systemImageNamed:@"speaker.wave.2.fill"];
                [self.soundButton setImage:soundImage forState:UIControlStateNormal];
            } else {
                [self.soundButton setTitle:@"🔊" forState:UIControlStateNormal];
            }
            self.soundButton.accessibilityLabel = @"静音";
        }
    }
}

- (void)setupVideoContentForAwemeModel:(AWEAwemeModel *)awemeModel {
    AWEVideoModel *videoModel = awemeModel.video;
    if (!videoModel) {
        return;
    }
    
    NSURL *videoURL = nil;
    if (videoModel.playURL && videoModel.playURL.originURLList.count > 0) {
        videoURL = [NSURL URLWithString:videoModel.playURL.originURLList.firstObject];
    } else if (videoModel.h264URL && videoModel.h264URL.originURLList.count > 0) {
        videoURL = [NSURL URLWithString:videoModel.h264URL.originURLList.firstObject];
    }
    
    if (!videoURL) {
        return;
    }
    
    self.pipPlayer = [AVPlayer playerWithURL:videoURL];
    
    self.pipPlayer.volume = 0.0;
    self.pipPlayer.muted = YES;
    
    if (@available(iOS 10.0, *)) {
        self.pipPlayer.automaticallyWaitsToMinimizeStalling = NO;
    }
    
    self.pipPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:self.pipPlayer];
    self.pipPlayerLayer.frame = self.contentContainerLayer.bounds;
    self.pipPlayerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.contentContainerLayer.layer addSublayer:self.pipPlayerLayer];
    
    [self addPlayerObservers];
    
    [self.pipPlayer play];
    
    if (@available(iOS 13.0, *)) {
        UIImage *mutedImage = [UIImage systemImageNamed:@"speaker.slash.fill"];
        [self.soundButton setImage:mutedImage forState:UIControlStateNormal];
    } else {
        [self.soundButton setTitle:@"🔇" forState:UIControlStateNormal];
    }
    self.soundButton.accessibilityLabel = @"开启声音";
}

- (void)addPlayerObservers {
    if (!self.pipPlayer) return;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handlePlayerDidFinishPlaying:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.pipPlayer.currentItem];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handlePlayerFailedToPlay:)
                                                 name:AVPlayerItemFailedToPlayToEndTimeNotification
                                               object:self.pipPlayer.currentItem];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handlePlayerStalled:)
                                                 name:AVPlayerItemPlaybackStalledNotification
                                               object:self.pipPlayer.currentItem];
}

- (void)removePlayerObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemFailedToPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemPlaybackStalledNotification object:nil];
}

- (void)handlePlayerDidFinishPlaying:(NSNotification *)notification {
    if (self.pipPlayer && self.isPlayingInPip) {
        [self.pipPlayer seekToTime:kCMTimeZero];
        [self.pipPlayer play];
    }
}

- (void)handlePlayerFailedToPlay:(NSNotification *)notification {
    if (self.pipPlayer && self.isPlayingInPip) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.pipPlayer seekToTime:kCMTimeZero];
            [self.pipPlayer play];
        });
    }
}

- (void)handlePlayerStalled:(NSNotification *)notification {
    if (self.pipPlayer && self.isPlayingInPip) {
        [self.pipPlayer play];
    }
}

// 关闭小窗时显示PIP按钮
- (void)_closeAndStopPip {
    [self removePlayerObservers];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (self.pipPlayer) {
        [self.pipPlayer pause];
        self.pipPlayer = nil;
    }
    
    if (self.pipPlayerLayer) {
        [self.pipPlayerLayer removeFromSuperlayer];
        self.pipPlayerLayer = nil;
    }
    
    self.isPlayingInPip = NO;
    
    PIPManager *pipManager = [PIPManager sharedManager];
    pipManager.currentPipContainer = nil;
    
    // 关闭小窗时，如果有当前视频模型，则重新显示PIP按钮
    if (pipManager.currentAwemeModel) {
        pipManager.pipButton.hidden = NO;
        [pipManager showPipButtonWithFullOpacity];
    }
    
    [self removeFromSuperview];
}

- (void)_handlePipPan:(UIPanGestureRecognizer *)pan {
    UIView *pipContainer = pan.view;
    CGPoint translation = [pan translationInView:self.superview];
    static CGPoint originCenter;
    
    if (pan.state == UIGestureRecognizerStateBegan) {
        originCenter = pipContainer.center;
        [UIView animateWithDuration:0.1 animations:^{
            pipContainer.transform = CGAffineTransformMakeScale(1.05, 1.05);
        }];
    }
    
    CGPoint newCenter = CGPointMake(originCenter.x + translation.x, originCenter.y + translation.y);
    
    CGFloat halfW = pipContainer.bounds.size.width / 2.0;
    CGFloat halfH = pipContainer.bounds.size.height / 2.0;
    CGFloat minX = halfW, maxX = self.superview.bounds.size.width - halfW;
    CGFloat minY = halfH + 50, maxY = self.superview.bounds.size.height - halfH - 50;
    
    newCenter.x = MAX(minX, MIN(maxX, newCenter.x));
    newCenter.y = MAX(minY, MIN(maxY, newCenter.y));
    pipContainer.center = newCenter;
    
    if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        [pan setTranslation:CGPointZero inView:self.superview];
        
        [UIView animateWithDuration:0.2 animations:^{
            pipContainer.transform = CGAffineTransformIdentity;
        }];
        
        CGFloat screenWidth = self.superview.bounds.size.width;
        CGFloat currentX = pipContainer.center.x;
        CGFloat targetX = (currentX < screenWidth / 2) ? halfW + 10 : screenWidth - halfW - 10;
        
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            pipContainer.center = CGPointMake(targetX, pipContainer.center.y);
        } completion:nil];
    }
}

- (NSString *)getAwemeId {
    if (!self.awemeModel) return nil;
    
    if ([self.awemeModel respondsToSelector:@selector(awemeId)]) {
        return [self.awemeModel performSelector:@selector(awemeId)];
    } else if ([self.awemeModel respondsToSelector:@selector(awemeID)]) {
        return [self.awemeModel performSelector:@selector(awemeID)];
    }
    return nil;
}

- (void)dealloc {
    [self removePlayerObservers];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (self.pipPlayer) {
        [self.pipPlayer pause];
    }
}

@end

%hook AWEPlayInteractionViewController

- (void)setAwemeModel:(AWEAwemeModel *)awemeModel {
    %orig;
    
    NSLog(@"AWEPlayInteractionViewController setAwemeModel: %@", awemeModel);
    
    if (awemeModel) {
        // 立即更新PIPManager的当前视频模型
        [[PIPManager sharedManager] setCurrentAwemeModel:awemeModel];
        
        // 延迟显示，确保界面加载完成
        dispatch_async(dispatch_get_main_queue(), ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                // 强制显示PIP按钮，解决切换视频后按钮不显示的问题
                PIPManager *pipManager = [PIPManager sharedManager];
                if (pipManager.currentPipContainer && pipManager.currentPipContainer.superview) {
                    // 如果有PIP容器在显示，确保更新内容
                    [pipManager.currentPipContainer updatePipPlayerWithAwemeModel:awemeModel];
                } else {
                    // 否则显示PIP按钮
                    pipManager.pipButton.hidden = NO;
                    [pipManager showPipButtonForAwemeModel:awemeModel];
                }
            });
        });
    }
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    
    NSLog(@"AWEPlayInteractionViewController viewDidAppear");
    
    // 页面显示时确保使用最新的视频模型
    if (self.awemeModel) {
        PIPManager *pipManager = [PIPManager sharedManager];
        pipManager.currentAwemeModel = self.awemeModel;
        
        // 如果有PIP容器在显示，则不需要显示按钮
        if (!pipManager.currentPipContainer || !pipManager.currentPipContainer.superview) {
            pipManager.pipButton.hidden = NO;
            [pipManager showPipButtonForAwemeModel:self.awemeModel];
        }
    }
}

%end

%ctor {
    %init(_ungrouped);
}
