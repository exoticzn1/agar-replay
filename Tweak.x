#import <UIKit/UIKit.h>
#import <ReplayKit/ReplayKit.h>
#import <Photos/Photos.h>

@interface VantageManager : NSObject
@property (nonatomic, assign) float clipDuration;
@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, strong) RPScreenRecorder *recorder;
+ (instancetype)shared;
- (void)startBuffer;
- (void)saveClip;
@end

@implementation VantageManager
+ (instancetype)shared {
    static VantageManager *s = nil;
    static dispatch_once_t o;
    dispatch_once(&o, ^{ 
        s = [VantageManager new]; 
        s.clipDuration = 30.0; 
        s.recorder = [RPScreenRecorder sharedRecorder]; 
    });
    return s;
}

- (void)startBuffer {
    if (!self.isEnabled || self.recorder.isRecording) return;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self.recorder.isAvailable) return;
        
        [self.recorder startRecordingWithHandler:^(NSError *error) {
            if (error) {
                if (error.code == -5803) { 
                    [self startBuffer]; 
                }
            }
        }];
    });
}

- (void)saveClip {
    if (!self.recorder.isRecording) {
        [self startBuffer];
        return;
    }

    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen impactOccurred];

    // FIXED FILENAME LINE BELOW
    NSString *dateStr = [[NSDate date] description];
    NSString *fileName = [dateStr stringByAppendingString:@".mp4"];
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    NSURL *url = [NSURL fileURLWithPath:tempPath];

    [self.recorder stopRecordingWithOutputURL:url completionHandler:^(NSError *error) {
        if (error) return;
        
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
        } completionHandler:^(BOOL success, NSError *phError) {
            [self startBuffer];
        }];
    }];
}
@end

@interface VantageUI : UIView
@property (nonatomic, strong) UIView *menu;
@property (nonatomic, strong) UIButton *logoBtn;
@property (nonatomic, strong) UIButton *floatClipBtn;
+ (instancetype)shared;
@end

@implementation VantageUI
+ (instancetype)shared {
    static VantageUI *s = nil;
    static dispatch_once_t o;
    dispatch_once(&o, ^{ s = [[VantageUI alloc] init]; });
    return s;
}

- (instancetype)init {
    self = [super initWithFrame:[UIScreen mainScreen].bounds];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        [self setupLogo];
        [self setupFloatingButton];
        [self setupMenu];
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return (hit == self) ? nil : hit;
}

- (void)setupLogo {
    _logoBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _logoBtn.frame = CGRectMake(50, 50, 60, 60);
    _logoBtn.layer.cornerRadius = 30;
    _logoBtn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.5];
    [_logoBtn setBackgroundImage:[UIImage imageNamed:@"vantage_icon"] forState:UIControlStateNormal];
    [_logoBtn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [_logoBtn addGestureRecognizer:pan];
    [self addSubview:_logoBtn];
}

- (void)setupFloatingButton {
    _floatClipBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _floatClipBtn.frame = CGRectMake(self.frame.size.width/2 - 35, 100, 70, 70);
    _floatClipBtn.layer.cornerRadius = 35;
    _floatClipBtn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.2];
    _floatClipBtn.layer.borderWidth = 2;
    _floatClipBtn.layer.borderColor = [UIColor whiteColor].CGColor;
    [_floatClipBtn setTitle:@"CLIP" forState:UIControlStateNormal];
    [_floatClipBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _floatClipBtn.hidden = YES;
    [_floatClipBtn addTarget:self action:@selector(triggerClip) forControlEvents:UIControlEventTouchUpInside];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [_floatClipBtn addGestureRecognizer:pan];
    [self addSubview:_floatClipBtn];
}

- (void)setupMenu {
    _menu = [[UIView alloc] initWithFrame:CGRectMake(0,0,280,300)];
    _menu.center = self.center;
    _menu.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:0.95];
    _menu.layer.cornerRadius = 15;
    _menu.hidden = YES;
    [self addSubview:_menu];
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0,0,280,40)];
    title.text = @"Vantage";
    title.textAlignment = NSTextAlignmentCenter;
    title.textColor = [UIColor whiteColor];
    title.backgroundColor = [UIColor colorWithWhite:0.05 alpha:1.0];
    [_menu addSubview:title];
    
    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(210, 60, 0, 0)];
    [sw addTarget:self action:@selector(swToggled:) forControlEvents:UIControlEventValueChanged];
    [_menu addSubview:sw];
    
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 60, 180, 30)];
    lbl.text = @"Enable Clipping";
    lbl.textColor = [UIColor whiteColor];
    [_menu addSubview:lbl];
}

- (void)toggleMenu { _menu.hidden = !_menu.hidden; }
- (void)swToggled:(UISwitch *)sw { 
    [VantageManager shared].isEnabled = sw.on; 
    _floatClipBtn.hidden = !sw.on;
    if(sw.on) [[VantageManager shared] startBuffer];
}
- (void)triggerClip { [[VantageManager shared] saveClip]; }

- (void)handlePan:(UIPanGestureRecognizer *)p {
    CGPoint t = [p translationInView:self];
    p.view.center = CGPointMake(p.view.center.x + t.x, p.view.center.y + t.y);
    [p setTranslation:CGPointZero inView:self];
}
@end

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [[UIApplication sharedApplication].keyWindow addSubview:[VantageUI shared]];
    });
}
%end
