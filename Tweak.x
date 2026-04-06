#import <UIKit/UIKit.h>
#import <ReplayKit/ReplayKit.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>

@interface VantageClip : NSObject
@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, strong) NSDate *timestamp;
@end
@implementation VantageClip @end

@interface VantageManager : NSObject
@property (nonatomic, strong) NSMutableArray *buffer;
@property (nonatomic, strong) NSMutableArray<VantageClip *> *internalClips;
@property (nonatomic, assign) int clipDuration;
@property (nonatomic, assign) BOOL isClippingEnabled;
+ (instancetype)shared;
- (void)processClip;
@end

@implementation VantageManager
+ (instancetype)shared {
    static VantageManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [VantageManager new]; });
    return shared;
}
- (instancetype)init {
    self = [super init];
    if (self) {
        _buffer = [NSMutableArray new];
        _internalClips = [NSMutableArray new];
        _clipDuration = 30;
        _isClippingEnabled = YES;
    }
    return self;
}

- (void)processClip {
    if (self.buffer.count == 0) return;
    NSString *fileName = [NSString stringWithFormat:@"vantage_%f.mp4", [[NSDate date] timeIntervalSince1970]];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    
    AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:[NSURL fileURLWithPath:path] fileType:AVFileTypeMPEG4 error:nil];
    NSDictionary *settings = @{AVVideoCodecKey:AVVideoCodecTypeH264, AVVideoWidthKey:@1280, AVVideoHeightKey:@720};
    AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:settings];
    [writer addInput:input];
    [writer startWriting];
    [writer startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp((__bridge CMSampleBufferRef)self.buffer.firstObject)];
    
    for (id frame in [self.buffer copy]) {
        while (!input.readyForMoreMediaData);
        [input appendSampleBuffer:(__bridge CMSampleBufferRef)frame];
    }
    
    [writer finishWritingWithCompletionHandler:^{
        VantageClip *c = [VantageClip new];
        c.filePath = path;
        c.timestamp = [NSDate date];
        [self.internalClips addObject:c];
    }];
}
@end

@interface VantageUI : UIView
@property (nonatomic, strong) UIView *menuView;
@property (nonatomic, strong) UIButton *menuButton;
@property (nonatomic, strong) UIButton *clipButton;
@property (nonatomic, assign) BOOL moveMode;
+ (instancetype)shared;
@end

@implementation VantageUI
+ (instancetype)shared {
    static VantageUI *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[VantageUI alloc] init]; });
    return shared;
}

- (instancetype)init {
    self = [super initWithFrame:[UIScreen mainScreen].bounds];
    if (self) {
        self.userInteractionEnabled = NO;
        _moveMode = NO;
        [self setupButtons];
        [self setupMenu];
    }
    return self;
}

- (void)setupButtons {
    _menuButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _menuButton.frame = CGRectMake(30, 50, 60, 60);
    _menuButton.layer.cornerRadius = 30;
    _menuButton.clipsToBounds = YES;
    [_menuButton setBackgroundImage:[UIImage imageNamed:@"vantage_icon"] forState:UIControlStateNormal];
    [_menuButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_menuButton];

    _clipButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _clipButton.frame = CGRectMake(self.frame.size.width/2 - 40, 50, 80, 40);
    _clipButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:0.6 alpha:0.8];
    [_clipButton setTitle:@"CLIP" forState:UIControlStateNormal];
    [_clipButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _clipButton.layer.cornerRadius = 10;
    _clipButton.hidden = NO;
    [_clipButton addTarget:self action:@selector(doClip) forControlEvents:UIControlEventTouchUpInside];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [_clipButton addGestureRecognizer:pan];
    
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
    [_clipButton addGestureRecognizer:pinch];
    
    [self addSubview:_clipButton];
}

- (void)setupMenu {
    _menuView = [[UIView alloc] initWithFrame:CGRectMake(30, 120, 300, 400)];
    _menuView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    _menuView.layer.cornerRadius = 15;
    _menuView.hidden = YES;
    [self addSubview:_menuView];
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 280, 30)];
    title.text = @"VANTAGE - Made by exoticzn";
    title.textColor = [UIColor cyanColor];
    title.font = [UIFont boldSystemFontOfSize:14];
    [_menuView addSubview:title];

    UIButton *discord = [UIButton buttonWithType:UIButtonTypeSystem];
    discord.frame = CGRectMake(10, 350, 280, 40);
    [discord setTitle:@"Join Discord" forState:UIControlStateNormal];
    [discord addTarget:self action:@selector(openDiscord) forControlEvents:UIControlEventTouchUpInside];
    [_menuView addSubview:discord];
}

- (void)toggleMenu { _menuView.hidden = !_menuView.hidden; }
- (void)doClip { [[VantageManager shared] processClip]; }
- (void)openDiscord { [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://discord.gg/wVfRnFTPwj"] options:@{} completionHandler:nil]; }

- (void)handlePan:(UIPanGestureRecognizer *)p {
    if (!self.moveMode) return;
    CGPoint t = [p translationInView:self];
    p.view.center = CGPointMake(p.view.center.x + t.x, p.view.center.y + t.y);
    [p setTranslation:CGPointZero inView:self];
}

- (void)handlePinch:(UIPinchGestureRecognizer *)p {
    if (!self.moveMode) return;
    p.view.transform = CGAffineTransformScale(p.view.transform, p.scale, p.scale);
    p.scale = 1.0;
}
@end

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIWindow *window = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene* windowScene in [UIApplication sharedApplication].connectedScenes) {
                if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                    window = windowScene.windows.firstObject;
                    break;
                }
            }
        } 
        
        if (!window) {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            window = [UIApplication sharedApplication].keyWindow;
            #pragma clang diagnostic pop
        }
        [window addSubview:[VantageUI shared]];
    });
}
%end
