#import <UIKit/UIKit.h>
#import <ReplayKit/ReplayKit.h>
#import <Photos/Photos.h>

// --- Data Manager ---
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
    // Delay to prevent crash on game load
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self.recorder.isAvailable) return;
        [self.recorder startRecordingWithHandler:^(NSError *error) {
            if (error && error.code == -5803) [self startBuffer];
        }];
    });
}

- (void)saveClip {
    if (!self.recorder.isRecording) { [self startBuffer]; return; }
    
    NSString *fileName = [NSString stringWithFormat:@"Vantage_%f.mp4", [[NSDate date] timeIntervalSince1970]];
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];

    [self.recorder stopRecordingWithOutputURL:url completionHandler:^(NSError *error) {
        if (!error) {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
            } completionHandler:^(BOOL success, NSError *phError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
                    [gen impactOccurred];
                });
                [self startBuffer];
            }];
        }
    }];
}
@end

// --- UI Logic ---
@interface VantageUI : UIView
@property (nonatomic, strong) UIView *menu;
@property (nonatomic, strong) UIButton *logoBtn;
@property (nonatomic, strong) UIButton *floatClipBtn;
@property (nonatomic, strong) UILabel *sliderLabel;
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
        self.userInteractionEnabled = YES;
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
    _logoBtn.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.5];
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
    _floatClipBtn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.2]; // 80% Transparent
    _floatClipBtn.layer.borderWidth = 1.5;
    _floatClipBtn.layer.borderColor = [UIColor whiteColor].CGColor;
    [_floatClipBtn setTitle:@"CLIP" forState:UIControlStateNormal];
    [_floatClipBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _floatClipBtn.hidden = YES;
    [_floatClipBtn addTarget:self action:@selector(runClip) forControlEvents:UIControlEventTouchUpInside];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [_floatClipBtn addGestureRecognizer:pan];
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
    [_floatClipBtn addGestureRecognizer:pinch];
    
    [self addSubview:_floatClipBtn];
}

- (void)setupMenu {
    _menu = [[UIView alloc] initWithFrame:CGRectMake(0,0,280,380)];
    _menu.center = self.center;
    _menu.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.12 alpha:0.98];
    _menu.layer.cornerRadius = 15;
    _menu.clipsToBounds = YES;
    _menu.hidden = YES;
    [self addSubview:_menu];
    
    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(0,0,280,45)];
    header.text = @"Vantage";
    header.textAlignment = NSTextAlignmentCenter;
    header.textColor = [UIColor whiteColor];
    header.backgroundColor = [UIColor colorWithWhite:0.05 alpha:1.0];
    [_menu addSubview:header];

    // Main Buttons
    [self createMenuBtn:@"Clipping" y:45 action:@selector(openClipPage)];
    [self createMenuBtn:@"Information" y:95 action:@selector(openInfoPage)];
}

- (void)createMenuBtn:(NSString *)title y:(float)y action:(SEL)action {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(0, y, 280, 50);
    [btn setTitle:[NSString stringWithFormat:@"  > %@", title] forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    btn.layer.borderWidth = 0.3;
    btn.layer.borderColor = [UIColor darkGrayColor].CGColor;
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [_menu addSubview:btn];
}

- (void)openClipPage {
    UIView *p = [[UIView alloc] initWithFrame:CGRectMake(0, 45, 280, 335)];
    p.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.12 alpha:1.0];
    [_menu addSubview:p];

    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, 150, 30)];
    l.text = @"Enable Clipping";
    l.textColor = [UIColor whiteColor];
    [p addSubview:l];

    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(210, 20, 0, 0)];
    sw.on = [VantageManager shared].isEnabled;
    [sw addTarget:self action:@selector(masterSw:) forControlEvents:UIControlEventValueChanged];
    [p addSubview:sw];

    _sliderLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 70, 240, 20)];
    _sliderLabel.text = [NSString stringWithFormat:@"Duration: %.0fs", [VantageManager shared].clipDuration];
    _sliderLabel.textColor = [UIColor cyanColor];
    [p addSubview:_sliderLabel];

    UISlider *sl = [[UISlider alloc] initWithFrame:CGRectMake(20, 100, 240, 30)];
    sl.minimumValue = 15; sl.maximumValue = 60;
    sl.value = [VantageManager shared].clipDuration;
    [sl addTarget:self action:@selector(slMoved:) forControlEvents:UIControlEventValueChanged];
    [p addSubview:sl];

    UIButton *saved = [UIButton buttonWithType:UIButtonTypeSystem];
    saved.frame = CGRectMake(0, 150, 280, 50);
    [saved setTitle:@"  > Saved Clips" forState:UIControlStateNormal];
    [saved setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
    saved.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [p addSubview:saved];

    UIButton *back = [UIButton buttonWithType:UIButtonTypeSystem];
    back.frame = CGRectMake(0, 285, 280, 50);
    [back setTitle:@"Back" forState:UIControlStateNormal];
    [back addTarget:self action:@selector(closePage:) forControlEvents:UIControlEventTouchUpInside];
    [p addSubview:back];
}

- (void)openInfoPage {
    UIView *p = [[UIView alloc] initWithFrame:CGRectMake(0, 45, 280, 335)];
    p.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.12 alpha:1.0];
    [_menu addSubview:p];

    UILabel *txt = [[UILabel alloc] initWithFrame:CGRectMake(20, 40, 240, 100)];
    txt.numberOfLines = 0;
    txt.text = @"Vantage\nMade by exoticzn\n\nDiscord: discord.gg/wVfRnFTPwj";
    txt.textColor = [UIColor whiteColor];
    txt.textAlignment = NSTextAlignmentCenter;
    [p addSubview:txt];

    UIButton *back = [UIButton buttonWithType:UIButtonTypeSystem];
    back.frame = CGRectMake(0, 285, 280, 50);
    [back setTitle:@"Back" forState:UIControlStateNormal];
    [back addTarget:self action:@selector(closePage:) forControlEvents:UIControlEventTouchUpInside];
    [p addSubview:back];
}

- (void)masterSw:(UISwitch *)s { 
    [VantageManager shared].isEnabled = s.on; 
    _floatClipBtn.hidden = !s.on;
    s.superview.backgroundColor = s.on ? [UIColor colorWithWhite:0.2 alpha:1.0] : [UIColor colorWithRed:0.12 green:0.12 blue:0.12 alpha:1.0];
    if(s.on) [[VantageManager shared] startBuffer];
}
- (void)slMoved:(UISlider *)s { 
    [VantageManager shared].clipDuration = s.value; 
    _sliderLabel.text = [NSString stringWithFormat:@"Duration: %.0fs", s.value];
}
- (void)toggleMenu { _menu.hidden = !_menu.hidden; }
- (void)closePage:(UIButton *)b { [b.superview removeFromSuperview]; }
- (void)runClip { [[VantageManager shared] saveClip]; }

- (void)handlePan:(UIPanGestureRecognizer *)p {
    CGPoint t = [p translationInView:self];
    p.view.center = CGPointMake(p.view.center.x + t.x, p.view.center.y + t.y);
    [p setTranslation:CGPointZero inView:self];
}
- (void)handlePinch:(UIPinchGestureRecognizer *)p {
    p.view.transform = CGAffineTransformScale(p.view.transform, p.scale, p.scale);
    p.scale = 1.0;
}
@end

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ [[UIApplication sharedApplication].keyWindow addSubview:[VantageUI shared]]; });
}
%end
