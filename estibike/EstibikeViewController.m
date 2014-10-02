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

@property (nonatomic, weak) IBOutlet UILabel *debugLabel;
@property (nonatomic, weak) IBOutlet UILabel *waitingLabel;
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
    [self setLabelsToWaitingState];
    
    
    //set it as a subview
    [self.view addSubview:backgroundImageView]; //in your case, again, use _blurView
    //just in case
    [self.view sendSubviewToBack:backgroundImageView];
    [self setDebugText:@"Waiting"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) resetCounters {
    NSLog(@"resetLabels");
    //self.currentSpeed.text = @"Current speed";
    //self.distanceLabel.text = @"Distance travelled";
    [self setDebugText:@"Debug info"];
    self.controlButton.hidden = YES;
}

- (void) setLabelsToReadyState {
    
    NSLog(@"setlabels to ready");
    [self setDebugText:@"Ready"];
    self.waitingLabel.text = @"#estibike ready...";
    self.controlButton.hidden = NO;
    self.controlButton.backgroundColor = [UIColor colorWithRed:(0/255.0) green:(128.0/255.0) blue:(64.0/255.0) alpha:1.0];
    [self.controlButton setTitle:@"Start" forState:UIControlStateNormal];
    
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
        UILocalNotification *notification = [[UILocalNotification alloc] init];
        notification.alertBody = @"Hey! Let's #estibike!";
        notification.soundName = UILocalNotificationDefaultSoundName;
        [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
    }
}

- (void) setLabelsToTrackingState {
    NSLog(@"setlabels to tracking");
    [self setDebugText:@"Tracking"];
    self.waitingLabel.text = @"#estibike go go go!";
    self.controlButton.hidden = YES;
}

- (void) setLabelsToFinaliseState {
    NSLog(@"setlabels to finalise");
    //self.statusLabel.text = @"Waiting to finalise";
    //self.currentSpeed.text = @"average speed";
    //self.distanceLabel.text = [NSString stringWithFormat:@"%.2f m", [[PSLocationManager sharedLocationManager] totalDistance]];
    self.controlButton.hidden = NO;
    self.controlButton.backgroundColor = [UIColor redColor];
    [self.controlButton setTitle:@"Finish" forState:UIControlStateNormal];
    self.waitingLabel.text = @"#estibike needs a rest";
    [self setDebugText:@"Ready to finish"];
}

- (void) setLabelsToWaitingState {
    
    NSLog(@"setlabels to waiting");
    //self.statusLabel.text = @"Waiting to finalise";
    //self.currentSpeed.text = @"average speed";
    //self.distanceLabel.text = [NSString stringWithFormat:@"%.2f m", [[PSLocationManager sharedLocationManager] totalDistance]];
    self.controlButton.hidden = YES;
    //self.controlButton.backgroundColor = [UIColor redColor];
    //[self.controlButton setTitle:@"Finish" forState:UIControlStateNormal];
    [self setDebugText:@"Waiting"];
    self.waitingLabel.text = @"#estibike waiting...";
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
                [self setLabelsToWaitingState];
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

- (void) setDebugText:(NSString *)txt {
    NSMutableString* s = [NSMutableString string];
    [s appendString:txt];
    [s appendString:[NSString stringWithFormat:@"\nTracking state %d\n", self.trackingState]];
    self.debugLabel.text = [NSString stringWithString:s];
}

- (void) backgroundWorkerSentDebug:(NSString *)msg {
    [self setDebugText:msg];
}
- (void) backgroundWorkerUpdatedSpeed:(NSString *)speed {
    //self.currentSpeed.text = speed;
}
- (void) backgroundWorkerUpdatedDistance:(NSString *)distance {
    //self.distanceLabel.text = distance;
}

@end
