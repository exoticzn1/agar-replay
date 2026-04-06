#import <UIKit/UIKit.h>

// --- Data Manager ---
@interface VantageManager : NSObject
@property (nonatomic, assign) float clipDuration;
@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, assign) BOOL moveMode;
+ (instancetype)shared;
@end

@implementation VantageManager
+ (instancetype)shared {
    static VantageManager *s = nil;
    static dispatch_once_t o;
    dispatch_once(&o, ^{ s = [VantageManager new]; s.clipDuration = 30.0; });
    return s;
}
@end

// --- UI Components ---
@interface VantageUI : UIView
@property (nonatomic, strong) UIView *menu;
@property (nonatomic, strong) UIButton *logoBtn;
@property (nonatomic, strong) UIButton *floatClipBtn;
@property (nonatomic, strong) UIView *clippingPage;
@property (nonatomic, strong) UIView *infoPage;
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

// Allows clicking the game through the transparent parts
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return (hit == self) ? nil : hit;
}

- (void)setupLogo {
    _logoBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _logoBtn.frame = CGRectMake(50, 50, 60, 60);
    _logoBtn.layer.cornerRadius = 30;
    _logoBtn.backgroundColor = [UIColor clearColor];
    [_logoBtn setBackgroundImage:[UIImage imageNamed:@"vantage_icon"] forState:UIControlStateNormal];
    
    // If icon is missing, use a placeholder so it's not invisible
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
    _floatClipBtn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.2]; // 80% Transparent
    _floatClipBtn.layer.borderWidth = 2;
    _floatClipBtn.layer.borderColor = [UIColor whiteColor].CGColor;
    
    [_floatClipBtn setTitle:@"CLIP" forState:UIControlStateNormal];
    [_floatClipBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _floatClipBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    _floatClipBtn.hidden = YES;
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [_floatClipBtn addGestureRecognizer:pan];
    
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
    [_floatClipBtn addGestureRecognizer:pinch];
    
    [self addSubview:_floatClipBtn];
}

- (void)setupMenu {
    _menu = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 280, 350)];
    _menu.center = self.center;
    _menu.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:0.95];
    _menu.layer.cornerRadius = 20;
    _menu.clipsToBounds = YES;
    _menu.hidden = YES;
    [self addSubview:_menu];
    
    // Header
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 280, 45)];
    header.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
    [_menu addSubview:header];
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 280, 45)];
    title.text = @"Vantage";
    title.textColor = [UIColor whiteColor];
    title.textAlignment = NSTextAlignmentCenter;
    title.font = [UIFont boldSystemFontOfSize:18];
    [header addSubview:title];
    
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(240, 0, 40, 45);
    [close setTitle:@"X" forState:UIControlStateNormal];
    [close setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [close addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:close];

    // Main List View (Home)
    [self buildMainPage];
}

- (void)buildMainPage {
    NSArray *items = @[@"Clipping", @"Information"];
    for (int i = 0; i < items.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(0, 45 + (i * 50), 280, 50);
        btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        btn.titleEdgeInsets = UIEdgeInsetsMake(0, 20, 0, 0);
        [btn setTitle:items[i] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.layer.borderWidth = 0.5;
        btn.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:1.0].CGColor;
        
        if (i == 0) [btn addTarget:self action:@selector(showClippingPage) forControlEvents:UIControlEventTouchUpInside];
        else [btn addTarget:self action:@selector(showInfoPage) forControlEvents:UIControlEventTouchUpInside];
        
        [_menu addSubview:btn];
    }
}

- (void)showClippingPage {
    _clippingPage = [[UIView alloc] initWithFrame:CGRectMake(0, 45, 280, 305)];
    _clippingPage.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0];
    [_menu addSubview:_clippingPage];

    // Enable Toggle
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, 150, 30)];
    l.text = @"Enable Clipping";
    l.textColor = [UIColor whiteColor];
    [_clippingPage addSubview:l];

    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(210, 20, 0, 0)];
    sw.on = [VantageManager shared].isEnabled;
    [sw addTarget:self action:@selector(swChanged:) forControlEvents:UIControlEventValueChanged];
    [_clippingPage addSubview:sw];

    // Slider
    _sliderLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 70, 240, 20)];
    _sliderLabel.text = [NSString stringWithFormat:@"Duration: %.0fs", [VantageManager shared].clipDuration];
    _sliderLabel.textColor = [UIColor lightGrayColor];
    _sliderLabel.font = [UIFont systemFontOfSize:12];
    [_clippingPage addSubview:_sliderLabel];

    UISlider *sl = [[UISlider alloc] initWithFrame:CGRectMake(20, 95, 240, 30)];
    sl.minimumValue = 15;
    sl.maximumValue = 60;
    sl.value = [VantageManager shared].clipDuration;
    [sl addTarget:self action:@selector(slChanged:) forControlEvents:UIControlEventValueChanged];
    [_clippingPage addSubview:sl];

    // Saved Clips Button
    UIButton *saved = [UIButton buttonWithType:UIButtonTypeSystem];
    saved.frame = CGRectMake(0, 150, 280, 50);
    [saved setTitle:@" >  Saved Clips" forState:UIControlStateNormal];
    [saved setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
    saved.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    saved.titleEdgeInsets = UIEdgeInsetsMake(0, 20, 0, 0);
    [_clippingPage addSubview:saved];

    UIButton *back = [UIButton buttonWithType:UIButtonTypeSystem];
    back.frame = CGRectMake(0, 255, 280, 50);
    [back setTitle:@"Back" forState:UIControlStateNormal];
    [back addTarget:self action:@selector(closePage:) forControlEvents:UIControlEventTouchUpInside];
    [_clippingPage addSubview:back];
}

- (void)showInfoPage {
    _infoPage = [[UIView alloc] initWithFrame:CGRectMake(0, 45, 280, 305)];
    _infoPage.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0];
    [_menu addSubview:_infoPage];

    UILabel *txt = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, 240, 100)];
    txt.numberOfLines = 0;
    txt.text = @"Vantage\nMade by exoticzn\n\nVersion 1.0.0";
    txt.textColor = [UIColor whiteColor];
    txt.textAlignment = NSTextAlignmentCenter;
    [_infoPage addSubview:txt];

    UIButton *disc = [UIButton buttonWithType:UIButtonTypeSystem];
    disc.frame = CGRectMake(40, 140, 200, 45);
    disc.backgroundColor = [UIColor colorWithRed:0.3 green:0.4 blue:0.9 alpha:1.0];
    [disc setTitle:@"Discord Server" forState:UIControlStateNormal];
    [disc setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    disc.layer.cornerRadius = 10;
    [disc addTarget:self action:@selector(openDisc) forControlEvents:UIControlEventTouchUpInside];
    [_infoPage addSubview:disc];

    UIButton *back = [UIButton buttonWithType:UIButtonTypeSystem];
    back.frame = CGRectMake(0, 255, 280, 50);
    [back setTitle:@"Back" forState:UIControlStateNormal];
    [back addTarget:self action:@selector(closePage:) forControlEvents:UIControlEventTouchUpInside];
    [_infoPage addSubview:back];
}

- (void)toggleMenu { _menu.hidden = !_menu.hidden; }
- (void)closePage:(UIButton *)sender { [sender.superview removeFromSuperview]; }
- (void)swChanged:(UISwitch *)s { 
    [VantageManager shared].isEnabled = s.on; 
    _floatClipBtn.hidden = !s.on;
    s.superview.backgroundColor = s.on ? [UIColor colorWithWhite:0.2 alpha:1.0] : [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0];
}
- (void)slChanged:(UISlider *)s { 
    [VantageManager shared].clipDuration = s.value; 
    _sliderLabel.text = [NSString stringWithFormat:@"Duration: %.0fs", s.value];
}
- (void)openDisc { [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://discord.gg/wVfRnFTPwj"] options:@{} completionHandler:nil]; }

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
