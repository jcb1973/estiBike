//
//  EstibikeViewController.m
//  estibike
//
//  Created by John Cieslik-Bridgen on 29/09/14.
//  Copyright (c) 2014 jcb1973. All rights reserved.
//

#import "EstibikeViewController.h"
#import <CoreLocation/CoreLocation.h>
#import "EBBackgroundWorker.h"

@interface EstibikeViewController ()

@property (nonatomic, weak) IBOutlet UILabel *distanceLabel;
@property (nonatomic, weak) IBOutlet UILabel *currentSpeed;
@property (nonatomic, weak) IBOutlet UILabel *statusLabel;
@property (nonatomic, weak) IBOutlet UILabel *debugLabel;
@property (nonatomic, weak) IBOutlet UIButton *controlButton;
@property EBTrackingState trackingState;
@property (nonatomic, strong) EBGPXTrack *track;

@end

@implementation EstibikeViewController


- (IBAction) forceStopTracking:(id)sender {
    NSLog(@"forceStopTracking:+");
    
    [self resetCounters];
    
    if ([[EBBackgroundWorker sharedManager] trackingState] == EBTracking) {
    
        [[EBBackgroundWorker sharedManager] stopTracking];
        [[EBBackgroundWorker sharedManager] finish];
    } else {
        NSLog(@"wasn't tracking no need to stop");
    }
}

- (IBAction) handleUserInteraction:(id)sender {
    
    UIButton *btn = (UIButton *)sender;
    NSString *action = [[btn titleLabel] text];
    
    if ([action isEqualToString:@"Start"]) {
        if ([[EBBackgroundWorker sharedManager] trackingState] != EBTracking) {
            [self setLabelsToTrackingState];
            [[EBBackgroundWorker sharedManager] startTracking];
            
        } else {
            NSLog(@"was already tracking no need to restart");
        }
    } else if ([action isEqualToString:@"Finish"]) {
        if ([[EBBackgroundWorker sharedManager] trackingState] == EBReadyToFinalise) {
            
            [[EBBackgroundWorker sharedManager] stopTracking];
            [[EBBackgroundWorker sharedManager] finish];
            [self resetCounters];
            
        } else {
            NSLog(@"was not tracking no need to stop");
        }
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // I'm the person who is going to listen to you... Any time you call method from protocol, I'll deal with it.
    [[EBBackgroundWorker sharedManager] setDelegate:self];
    //Create UIImageView
    UIImageView *backgroundImageView = [[UIImageView alloc] initWithFrame:self.view.frame]; //or in your case you should use your _blurView
    backgroundImageView.image = [UIImage imageNamed:@"splash_screen.png"];
    self.controlButton.hidden = YES;
    
    //set it as a subview
    [self.view addSubview:backgroundImageView]; //in your case, again, use _blurView
    //just in case
    [self.view sendSubviewToBack:backgroundImageView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) resetCounters {
    NSLog(@"resetLabels");
    self.currentSpeed.text = @"Current speed";
    self.distanceLabel.text = @"Distance travelled";
    self.statusLabel.text = @"Not tracking";
    self.debugLabel.text = @"Debug info";
    self.controlButton.hidden = YES;
}

- (void) setLabelsToReadyState {
    NSLog(@"setlabels to ready");
    self.statusLabel.text = @"Ready";
    self.currentSpeed.text = @"waiting...";
    self.distanceLabel.text = @"waiting...";
    self.controlButton.hidden = NO;
    self.controlButton.backgroundColor = [UIColor colorWithRed:(0/255.0) green:(128.0/255.0) blue:(64.0/255.0) alpha:1.0];
    [self.controlButton setTitle:@"Start" forState:UIControlStateNormal];
}

- (void) setLabelsToTrackingState {
    NSLog(@"setlabels to tracking");
    self.statusLabel.text = @"Tracking";
    self.currentSpeed.text = @"waiting...";
    self.distanceLabel.text = @"waiting...";
    self.controlButton.hidden = YES;
}

- (void) setLabelsToFinaliseState {
    NSLog(@"setlabels to finalise");
    self.statusLabel.text = @"Waiting to finalise";
    self.currentSpeed.text = @"average speed";
    self.distanceLabel.text = [NSString stringWithFormat:@"%.2f m", [[PSLocationManager sharedLocationManager] totalDistance]];
    self.controlButton.hidden = NO;
    self.controlButton.backgroundColor = [UIColor redColor];
    [self.controlButton setTitle:@"Finish" forState:UIControlStateNormal];
}

#pragma mark EBBackgroundWorkerDelegate
- (void) backgroundWorkerSendStateChange:(EBTrackingState)state {
   
    EBTrackingState previousState = self.trackingState;
    self.trackingState = state;
    
    if (state != previousState) {
        
        NSLog(@" *** state change sent by background worker old state %u new state %u *** ", previousState, state);
        
        switch (state) {
            case EBWaiting:
                //no buttons
                self.controlButton.hidden = YES;
                break;
            case EBReadyToTrack:
                [self setLabelsToReadyState];
                break;
            case EBTracking:
                [self setLabelsToTrackingState];
                break;
            case EBCouldFinish:
                // don't do anything?
                break;
            case EBReadyToFinalise:
                [self setLabelsToFinaliseState];
                break;
            default:
                break;
        }
    }
}

- (void) backgroundWorkerSentDebug:(NSString *)msg {
    self.debugLabel.text = msg;
}
- (void) backgroundWorkerUpdatedSpeed:(NSString *)speed {
    self.currentSpeed.text = speed;
}
- (void) backgroundWorkerUpdatedDistance:(NSString *)distance {
    self.distanceLabel.text = distance;
}

@end
