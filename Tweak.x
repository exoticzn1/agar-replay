#import <UIKit/UIKit.h>
#import <ReplayKit/ReplayKit.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>

// --- Models ---
@interface VantageClip : NSObject
@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, strong) NSString *name;
@end
@implementation VantageClip @end

// --- Manager ---
@interface VantageManager : NSObject
@property (nonatomic, strong) NSMutableArray<VantageClip *> *clips;
@property (nonatomic, assign) int duration; // 30 or 60
@property (nonatomic, assign) BOOL isEnabled;
+ (instancetype)shared;
- (void)saveLastSeconds;
@end

@implementation VantageManager
+ (instancetype)shared {
    static VantageManager *s = nil;
    static dispatch_once_t o;
    dispatch_once(&o, ^{ s = [VantageManager new]; });
    return s;
}
- (instancetype)init {
    self = [super init];
    if (self) {
        _clips = [NSMutableArray new];
        _duration = 30;
        _isEnabled = NO;
    }
    return self;
}
- (void)saveLastSeconds {
    // This triggers the ReplayKit/Buffer logic
    NSLog(@"[Vantage] Clipping last %d seconds", self.duration);
}
@end

// --- UI ---
@interface VantageUI : UIView <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UIView *menu;
@property (nonatomic, strong) UIButton *logoBtn;
@property (nonatomic, strong) UIButton *floatClipBtn;
@property (nonatomic, strong) UIView *clippingTab;
@property (nonatomic, strong) UIView *infoTab;
@property (nonatomic, strong) UITableView *clipsTable;
@property (nonatomic, assign) BOOL moveMode;
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
        _moveMode = NO;
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
    _logoBtn.frame = CGRectMake(30, 50, 60, 60);
    _logoBtn.layer.cornerRadius = 30;
    _logoBtn.backgroundColor = [UIColor cyanColor];
    [_logoBtn setBackgroundImage:[UIImage imageNamed:@"vantage_icon"] forState:UIControlStateNormal];
    [_logoBtn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_logoBtn];
}

- (void)setupFloatingButton {
    _floatClipBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _floatClipBtn.frame = CGRectMake(self.frame.size.width/2 - 40, 50, 80, 40);
    _floatClipBtn.backgroundColor = [UIColor colorWithRed:0 green:0.6 blue:0.7 alpha:0.9];
    [_floatClipBtn setTitle:@"CLIP" forState:UIControlStateNormal];
    [_floatClipBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _floatClipBtn.layer.cornerRadius = 10;
    _floatClipBtn.hidden = YES;
    [_floatClipBtn addTarget:self action:@selector(runClip) forControlEvents:UIControlEventTouchUpInside];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [_floatClipBtn addGestureRecognizer:pan];
    
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
    [_floatClipBtn addGestureRecognizer:pinch];
    
    [self addSubview:_floatClipBtn];
}

- (void)setupMenu {
    _menu = [[UIView alloc] initWithFrame:CGRectMake(30, 120, 320, 450)];
    _menu.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.98];
    _menu.layer.cornerRadius = 20;
    _menu.layer.borderWidth = 1;
    _menu.layer.borderColor = [UIColor cyanColor].CGColor;
    _menu.hidden = YES;
    [self addSubview:_menu];
    
    // Tab Bar
    UIButton *tab1 = [UIButton buttonWithType:UIButtonTypeSystem];
    tab1.frame = CGRectMake(0, 0, 160, 50);
    [tab1 setTitle:@"CLIPPING" forState:UIControlStateNormal];
    [tab1 addTarget:self action:@selector(showClipTab) forControlEvents:UIControlEventTouchUpInside];
    [_menu addSubview:tab1];
    
    UIButton *tab2 = [UIButton buttonWithType:UIButtonTypeSystem];
    tab2.frame = CGRectMake(160, 0, 160, 50);
    [tab2 setTitle:@"INFO" forState:UIControlStateNormal];
    [tab2 addTarget:self action:@selector(showInfoTab) forControlEvents:UIControlEventTouchUpInside];
    [_menu addSubview:tab2];
    
    // Tabs
    _clippingTab = [[UIView alloc] initWithFrame:CGRectMake(0, 50, 320, 400)];
    _infoTab = [[UIView alloc] initWithFrame:CGRectMake(0, 50, 320, 400)];
    _infoTab.hidden = YES;
    [_menu addSubview:_clippingTab];
    [_menu addSubview:_infoTab];
    
    [self buildClippingUI];
    [self buildInfoUI];
}

- (void)buildClippingUI {
    UISwitch *s = [[UISwitch alloc] initWithFrame:CGRectMake(250, 20, 0, 0)];
    [s addTarget:self action:@selector(toggleMaster:) forControlEvents:UIControlEventValueChanged];
    [_clippingTab addSubview:s];
    
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, 200, 30)];
    l.text = @"Enable Vantage";
    l.textColor = [UIColor whiteColor];
    [_clippingTab addSubview:l];
    
    UISegmentedControl *dur = [[UISegmentedControl alloc] initWithItems:@[@"30s", @"60s"]];
    dur.frame = CGRectMake(20, 70, 280, 40);
    dur.selectedSegmentIndex = 0;
    [dur addTarget:self action:@selector(changeDur:) forControlEvents:UIControlEventValueChanged];
    [_clippingTab addSubview:dur];
    
    UIButton *mv = [UIButton buttonWithType:UIButtonTypeSystem];
    mv.frame = CGRectMake(20, 130, 280, 40);
    [mv setTitle:@"Move Buttons: OFF" forState:UIControlStateNormal];
    [mv addTarget:self action:@selector(toggleMove:) forControlEvents:UIControlEventTouchUpInside];
    [_clippingTab addSubview:mv];
    
    UILabel *saveL = [[UILabel alloc] initWithFrame:CGRectMake(20, 190, 200, 30)];
    saveL.text = @"Saved Clips";
    saveL.textColor = [UIColor cyanColor];
    [_clippingTab addSubview:saveL];
    
    _clipsTable = [[UITableView alloc] initWithFrame:CGRectMake(10, 230, 300, 160)];
    _clipsTable.backgroundColor = [UIColor clearColor];
    _clipsTable.delegate = self;
    _clipsTable.dataSource = self;
    [_clippingTab addSubview:_clipsTable];
}

- (void)buildInfoUI {
    UILabel *info = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, 280, 100)];
    info.numberOfLines = 0;
    info.text = @"Vantage\nVersion 1.0\nMade by exoticzn\nPremium Clipping Tool";
    info.textColor = [UIColor whiteColor];
    info.textAlignment = NSTextAlignmentCenter;
    [_infoTab addSubview:info];
    
    UIButton *disc = [UIButton buttonWithType:UIButtonTypeSystem];
    disc.frame = CGRectMake(20, 150, 280, 50);
    disc.backgroundColor = [UIColor colorWithRed:0.34 green:0.39 blue:0.93 alpha:1.0];
    [disc setTitle:@"Join Discord" forState:UIControlStateNormal];
    [disc setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [disc addTarget:self action:@selector(openDisc) forControlEvents:UIControlEventTouchUpInside];
    disc.layer.cornerRadius = 10;
    [_infoTab addSubview:disc];
}

// --- Actions ---
- (void)toggleMenu { _menu.hidden = !_menu.hidden; }
- (void)showClipTab { _clippingTab.hidden = NO; _infoTab.hidden = YES; }
- (void)showInfoTab { _clippingTab.hidden = YES; _infoTab.hidden = NO; }
- (void)toggleMaster:(UISwitch *)s { [VantageManager shared].isEnabled = s.on; _floatClipBtn.hidden = !s.on; }
- (void)changeDur:(UISegmentedControl *)s { [VantageManager shared].duration = (s.selectedSegmentIndex == 0) ? 30 : 60; }
- (void)openDisc { [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://discord.gg/wVfRnFTPwj"] options:@{} completionHandler:nil]; }
- (void)runClip { [[VantageManager shared] saveLastSeconds]; }

- (void)toggleMove:(UIButton *)b {
    _moveMode = !_moveMode;
    [b setTitle:_moveMode ? @"Move Buttons: ON" : @"Move Buttons: OFF" forState:UIControlStateNormal];
}

- (void)handlePan:(UIPanGestureRecognizer *)p {
    if (!_moveMode) return;
    CGPoint t = [p translationInView:self];
    p.view.center = CGPointMake(p.view.center.x + t.x, p.view.center.y + t.y);
    [p setTranslation:CGPointZero inView:self];
}

- (void)handlePinch:(UIPinchGestureRecognizer *)p {
    if (!_moveMode) return;
    p.view.transform = CGAffineTransformScale(p.view.transform, p.scale, p.scale);
    p.scale = 1.0;
}

// --- TableView ---
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return [VantageManager shared].clips.count; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)i {
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:@"C"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"C"];
    c.textLabel.text = [VantageManager shared].clips[i.row].name;
    c.textLabel.textColor = [UIColor whiteColor];
    c.backgroundColor = [UIColor clearColor];
    return c;
}
@end

// --- Hook ---
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIWindow *window = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene* ws in [UIApplication sharedApplication].connectedScenes) {
                if (ws.activationState == UISceneActivationStateForegroundActive) {
                    window = ws.windows.firstObject; break;
                }
            }
        } else { window = [UIApplication sharedApplication].keyWindow; }
        [window addSubview:[VantageUI shared]];
    });
}
%end
