#import <UIKit/UIKit.h>
#import <ReplayKit/ReplayKit.h>
#import <Photos/Photos.h>

// --- The Brain: Rolling Buffer Manager ---
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
    dispatch_once(&o, ^{ s = [VantageManager new]; s.clipDuration = 30.0; s.recorder = [RPScreenRecorder sharedRecorder]; });
    return s;
}

- (void)startBuffer {
    if (!self.isEnabled || self.recorder.isRecording) return;
    
    // Starts the "Hidden" recording
    [self.recorder startRecordingWithHandler:^(NSError *error) {
        if (error) NSLog(@"[Vantage] Buffer Error: %@", error.localizedDescription);
    }];
}

- (void)saveClip {
    if (!self.recorder.isRecording) {
        [self startBuffer];
        return;
    }

    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"vantage_temp.mp4"];
    NSURL *url = [NSURL fileURLWithPath:tempPath];

    // We stop the recording, which gives us the file
    [self.recorder stopRecordingWithOutputURL:url completionHandler:^(NSError *error) {
        if (error) return;
        
        // Save to Photos app immediately
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
        } completionHandler:^(BOOL success, NSError *phError) {
            if (success) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
                    [gen impactOccurred]; // Vibrates phone so you know it worked
                });
            }
            // Restart the buffer immediately for the next clip
            [self startBuffer];
        }];
    }];
}
@end

// --- UI (Vantage Shark Style) ---
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
        self.backgroundColor = [UIColor clearColor];
        [self setupLogo];
        [self setupMenu];
        [self setupFloatingButton];
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
    [_logoBtn setBackgroundImage:[UIImage imageNamed:@"vantage_icon"] forState:UIControlStateNormal];
    if (![UIImage imageNamed:@"vantage_icon"]) _logoBtn.backgroundColor = [UIColor grayColor];
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
    
    [_floatClipBtn addTarget:self action:@selector(doTheClip) forControlEvents:UIControlEventTouchUpInside];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [_floatClipBtn addGestureRecognizer:pan];
    
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
    [_floatClipBtn addGestureRecognizer:pinch];
    
    [self addSubview:_floatClipBtn];
}

- (void)setupMenu {
    _menu = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 280, 350)];
    _menu.center = self.center;
    _menu.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:0.98];
    _menu.layer.cornerRadius = 20;
    _menu.clipsToBounds = YES;
    _menu.hidden = YES;
    [self addSubview:_menu];
    
    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 280, 45)];
    header.text = @"Vantage";
    header.textColor = [UIColor whiteColor];
    header.textAlignment = NSTextAlignmentCenter;
    header.backgroundColor = [UIColor colorWithWhite:0.05 alpha:1.0];
    [_menu addSubview:header];

    // Clipping Row
    UIButton *clipRow = [UIButton buttonWithType:UIButtonTypeSystem];
    clipRow.frame = CGRectMake(0, 45, 280, 50);
    [clipRow setTitle:@"  > Clipping" forState:UIControlStateNormal];
    [clipRow setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    clipRow.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [clipRow addTarget:self action:@selector(showClipSettings) forControlEvents:UIControlEventTouchUpInside];
    [_menu addSubview:clipRow];
}

- (void)showClipSettings {
    UIView *settings = [[UIView alloc] initWithFrame:CGRectMake(0, 45, 280, 305)];
    settings.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    [_menu addSubview:settings];

    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(210, 20, 0, 0)];
    sw.on = [VantageManager shared].isEnabled;
    [sw addTarget:self action:@selector(toggleMaster:) forControlEvents:UIControlEventValueChanged];
    [settings addSubview:sw];

    _sliderLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 70, 240, 20)];
    _sliderLabel.text = [NSString stringWithFormat:@"Time: %.0fs", [VantageManager shared].clipDuration];
    _sliderLabel.textColor = [UIColor cyanColor];
    [settings addSubview:_sliderLabel];

    UISlider *sl = [[UISlider alloc] initWithFrame:CGRectMake(20, 100, 240, 30)];
    sl.minimumValue = 15; sl.maximumValue = 60;
    sl.value = [VantageManager shared].clipDuration;
    [sl addTarget:self action:@selector(sliderMoved:) forControlEvents:UIControlEventValueChanged];
    [settings addSubview:sl];

    UIButton *back = [UIButton buttonWithType:UIButtonTypeSystem];
    back.frame = CGRectMake(0, 255, 280, 50);
    [back setTitle:@"Back" forState:UIControlStateNormal];
    [back addTarget:self action:@selector(closeSettings:) forControlEvents:UIControlEventTouchUpInside];
    [settings addSubview:back];
}

- (void)toggleMenu { _menu.hidden = !_menu.hidden; }
- (void)closeSettings:(UIButton *)s { [s.superview removeFromSuperview]; }
- (void)toggleMaster:(UISwitch *)s { 
    [VantageManager shared].isEnabled = s.on; 
    _floatClipBtn.hidden = !s.on;
    if (s.on) [[VantageManager shared] startBuffer];
}
- (void)sliderMoved:(UISlider *)s { 
    [VantageManager shared].clipDuration = s.value; 
    _sliderLabel.text = [NSString stringWithFormat:@"Time: %.0fs", s.value];
}
- (void)doTheClip { [[VantageManager shared] saveClip]; }

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
    dispatch_once(&once, ^{
        [[UIApplication sharedApplication].keyWindow addSubview:[VantageUI shared]];
    });
}
%end
