//
//  CameraOverlayViewController.m
//  DisposableCamera
//
//  Created by Bobby Ren on 1/5/15.
//  Copyright (c) 2015 Bobby Ren Tech. All rights reserved.
//

#import "CameraOverlayViewController.h"
#import "AppDelegate.h"

@interface CameraOverlayViewController ()
{
    AVAudioPlayer *playerFlash;
    AVAudioPlayer *playerClickFlash;
    AVAudioPlayer *playerClick;
    AVAudioPlayer *playerAdvance;
}

@end

@implementation CameraOverlayViewController

-(NSUInteger)navigationControllerSupportedInterfaceOrientations:(UINavigationController *)navigationController {
    return UIInterfaceOrientationMaskLandscapeRight;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleGesture:)];
    swipe.direction = UISwipeGestureRecognizerDirectionDown;
    [swipe setDelegate:self];
    [self.view addGestureRecognizer:swipe];

    viewLabel.layer.cornerRadius = viewLabel.frame.size.width/4;
    viewLabel.layer.borderWidth = 1;
    viewLabel.layer.borderColor = [[UIColor darkGrayColor] CGColor];
    labelCountCurr.transform = CGAffineTransformMakeRotation(M_PI_2);
    labelCountPrev.transform = CGAffineTransformMakeRotation(M_PI_2);
    labelCountNext.transform = CGAffineTransformMakeRotation(M_PI_2);
    labelCountFuture.transform = CGAffineTransformMakeRotation(M_PI_2);

    for (UILabel *label in @[labelCountCurr, labelCountFuture, labelCountNext, labelCountPrev]) {
        label.font = [UIFont boldSystemFontOfSize:12];
    }

#if !TESTING
    buttonFlash.backgroundColor = [UIColor clearColor];
    buttonViewFinder.backgroundColor = [UIColor clearColor];
    viewFilmAdvance.backgroundColor = [UIColor clearColor];
#endif

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(imageCaptured:) name:@"image:captured" object:nil];
    [self refresh];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)refresh {
    [self toggleFlash:NO];
    [self toggleCapture:NO];

    rollCount = [self.delegate initialRollCount];

    if (rollCount == 0 && ![[NSUserDefaults standardUserDefaults] objectForKey:@"film:position"]) {
        rollCount = 0;
        advancedCount = INITIAL_ADVANCE_COUNT;
    }
    else
        advancedCount = [[[NSUserDefaults standardUserDefaults] objectForKey:@"film:position"] intValue];

    if (advancedCount == MAX_ADVANCE_COUNT && rollCount < MAX_ROLL_SIZE) {
        [self toggleCapture:YES];
    }
    [self setLabelCountPosition:advancedCount];

    if (rollCount < MAX_ROLL_SIZE) {
#if TESTING
        [buttonRoll setHidden:NO];
#else
        [buttonRoll setHidden:YES];
#endif
        [buttonCapture setHidden:NO];
    }
    else {
        [buttonRoll setHidden:NO];
        [buttonCapture setHidden:YES];
    }
}

#pragma mark buttons

-(IBAction)didClickButtonFlash:(id)sender {
    if (!flash) {
        flash = YES;
        [self playFlash];
        [self toggleFlash:NO];
    }
    [self toggleFlash:YES];
}

-(IBAction)didClickCapture:(id)sender {
    if (advancedCount < MAX_ADVANCE_COUNT-1)
        return;

    [self playClick];
    if (flash) {
        [self toggleFlash:NO];
    }
    advancedCount = 0; // on click, the advanced count should be 4
    rollCount++;
    [self setLabelCountPosition:advancedCount];

    // doesn't matter if the camera outcome fails, always toggle the button and "advance" the count
    [self toggleCapture:NO];

    // zoom out
    if (isZooming) {
        [self performSelector:@selector(stopLookingInViewFinder) withObject:nil afterDelay:.5];
    }

    // tell camera to actually try to capture
    [self.delegate capture];
}

-(IBAction)didClickFilmRoll:(id)sender {
    // opens roll and reveals existing images
    [self.delegate showFilmRoll];
}

#pragma mark Sounds
-(void)playFlash {
    if (!playerFlash) {
        NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle]
                                             pathForResource:@"cameraFlash"
                                             ofType:@"mp3"]];
        playerFlash = [[AVAudioPlayer alloc]
                       initWithContentsOfURL:url
                       error:nil];
        [playerClickFlash setDelegate:self];
    }
    [playerFlash play];
}

-(void)playClickFlash {
    if (!playerClickFlash) {
        NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle]
                                             pathForResource:@"cameraClickFlash"
                                             ofType:@"mp3"]];
        playerClickFlash = [[AVAudioPlayer alloc]
                            initWithContentsOfURL:url
                            error:nil];
        [playerClickFlash setDelegate:self];
    }
    [playerClickFlash play];
}

-(void)playClick {
    if (!playerClick) {
        NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle]
                                             pathForResource:@"cameraClick"
                                             ofType:@"mp3"]];
        playerClick = [[AVAudioPlayer alloc]
                       initWithContentsOfURL:url
                       error:nil];
    }
    [playerClick play];
}

-(void)playAdvance {
    if (!playerAdvance) {
        NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle]
                                             pathForResource:@"cameraFilmAdvance"
                                             ofType:@"mp3"]];
        playerAdvance = [[AVAudioPlayer alloc]
                         initWithContentsOfURL:url
                         error:nil];
    }
    [playerAdvance play];

    // if tactile feedback is desired. doesn't feel too authentic.
    //AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    NSLog(@"Done");
}

-(void)toggleCapture:(BOOL)canCapture {
    if (!canCapture) {
        [buttonCapture setEnabled:NO];
    }
    else {
        [buttonCapture setEnabled:YES];
    }
}

#pragma mark flash
-(void)toggleFlash:(BOOL)isReady {
    if (!isReady) {
        [flashImage setAlpha:0];
    }
    else {
        [UIView animateWithDuration:1 animations:^{
            flashImage.alpha = 1;
        } completion:^(BOOL finished) {
            [self.delegate enableFlash];
        }];
    }
}

#pragma mark film advance
-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if (isZooming)
        return NO;

    if (CGRectContainsPoint(viewFilmAdvance.frame, [touch locationInView:self.view])) {
        return YES;
    }
    return NO;
}
-(void)handleGesture:(UIGestureRecognizer *)gesture {
    if (rollCount > MAX_ROLL_SIZE)
        return;

    if (advancedCount < MAX_ADVANCE_COUNT) {
        [self playAdvance];

        advancedCount = advancedCount + 1;
        [self setLabelCountPosition:advancedCount];
        [self doScrollAnimation];

        if (advancedCount == MAX_ADVANCE_COUNT && rollCount < MAX_ROLL_SIZE) {
            [self toggleCapture:YES];
        }
    }
}

-(void)doScrollAnimation {
    [scrollImage2 setHidden:NO];
    [self performSelector:@selector(doScroll3) withObject:nil afterDelay:.1];
}

-(void)doScroll3 {
    [scrollImage3 setHidden:NO];
    [self performSelector:@selector(endScroll) withObject:nil afterDelay:.1];
}

-(void)endScroll {
    static BOOL repeat = YES;
    [scrollImage2 setHidden:YES];
    [scrollImage3 setHidden:YES];
    if (repeat) {
        repeat = NO;
        [self performSelector:@selector(doScrollAnimation) withObject:nil afterDelay:.1];
    }
    else {
        repeat = YES;
    }
}

#pragma mark Viewfinder
-(IBAction)didClickViewFinder:(id)sender {
    if (!isZooming) {
        [self lookInViewFinder];
    }
    else {
        [self stopLookingInViewFinder];
    }
}

-(void)lookInViewFinder {
    [buttonFlash setUserInteractionEnabled:isZooming];
    [viewFilmAdvance setUserInteractionEnabled:isZooming];
    [flashImage setHidden:!isZooming];
    [scrollImage2 setHidden:!isZooming];
    [scrollImage3 setHidden:!isZooming];

    float tx = self.view.frame.size.width/2 - buttonViewFinder.center.x;
    float ty = self.view.frame.size.height/2 - buttonViewFinder.center.y;
    NSLog(@"x y: %f %f", buttonViewFinder.center.x, buttonViewFinder.center.y);
    float scale = 7;

    // scale and translate so that the center of the viewFinder is enlarged and centered
    // transform for viewFinder and background/view must be composed differently; this is due to autolayout
    [self.delegate zoomIn];
    CGAffineTransform transform = CGAffineTransformScale(CGAffineTransformTranslate(viewBG.transform, tx*scale, ty*scale), scale, scale);
    CGAffineTransform transform2 = CGAffineTransformScale(CGAffineTransformTranslate(buttonViewFinder.transform, tx, 0), scale, scale);

    viewLabel.alpha = 0;
    buttonRoll.alpha = 0;
    [UIView animateWithDuration:.5 animations:^{
        viewBG.transform = transform;
        buttonViewFinder.transform = transform2;
        buttonViewFinder.alpha = .25;
    } completion:^(BOOL finished) {
        isZooming = !isZooming;
    }];
}

-(void)stopLookingInViewFinder {
    [self.delegate zoomOut:YES];
    [UIView animateWithDuration:.5 animations:^{
        viewBG.transform = CGAffineTransformIdentity;
        buttonViewFinder.transform = CGAffineTransformIdentity;
        buttonViewFinder.alpha = 1;
    } completion:^(BOOL finished) {
        viewLabel.alpha = 1;
        buttonRoll.alpha = 1;
        
        [buttonFlash setUserInteractionEnabled:isZooming];
        [viewFilmAdvance setUserInteractionEnabled:isZooming];
        [flashImage setHidden:!isZooming];
        [scrollImage2 setHidden:!isZooming];
        [scrollImage3 setHidden:!isZooming];

        isZooming = !isZooming;
    }];
}

-(float)viewFinderOffsetX {
    return buttonViewFinder.center.x - self.view.center.x;
}

-(float)viewFinderOffsetY {
    return buttonViewFinder.center.y - self.view.center.y;
}

-(float)viewFinderWidth {
    return constraintViewFinderWidth.constant;
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark rotating animations
-(void)setLabelCountPosition:(int)position {
    NSLog(@"roll %lu position %d", rollCount, position);
    // 20 degrees between each number, 4 scroll wheel positions = 5 degrees each position
    float degreesCurr = 5 * position;
    float degreesPrev = degreesCurr + 20;
    float degreesNext = degreesCurr - 20;
    float degreesFuture = degreesCurr - 40;

    if (rollCount > 0)
        labelCountPrev.text = [NSString stringWithFormat:@"%lu", rollCount-1];
    else
        labelCountPrev.text = nil;
    labelCountCurr.text = [NSString stringWithFormat:@"%lu", rollCount];

    if (rollCount + 1 <= MAX_ROLL_SIZE)
        labelCountNext.text = [NSString stringWithFormat:@"%lu", rollCount+1];
    else
        labelCountNext.text = nil;

    if (rollCount + 2 <= MAX_ROLL_SIZE)
        labelCountFuture.text = [NSString stringWithFormat:@"%lu", rollCount+2];
    else
        labelCountFuture.text = nil;
    viewRotaterPrev.transform = CGAffineTransformMakeRotation(degreesPrev / 360 * 2*M_PI);
    viewRotaterCurr.transform = CGAffineTransformMakeRotation(degreesCurr / 360 * 2*M_PI);
    viewRotaterNext.transform = CGAffineTransformMakeRotation(degreesNext / 360 * 2*M_PI);
    viewRotaterFuture.transform = CGAffineTransformMakeRotation(degreesFuture / 360 * 2*M_PI);

    [[NSUserDefaults standardUserDefaults] setObject:@(advancedCount) forKey:@"film:position"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(void)imageCaptured:(NSNotification *)n {
    if (rollCount == MAX_ROLL_SIZE) {
        [buttonCapture setHidden:YES];
        [buttonRoll setHidden:NO];
        if (!isZooming)
            buttonRoll.alpha = 1;
    }

    if (flash) {
        [self playFlash];
        [self toggleFlash:YES];
    }
}

@end
