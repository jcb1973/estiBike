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
@property (nonatomic, weak) IBOutlet UILabel *distanceLabel;
@property (nonatomic, weak) IBOutlet UILabel *timeLabel;
@property (nonatomic, weak) IBOutlet UILabel *uploadLabel;
@property (nonatomic, weak) IBOutlet UISwitch *uploadSwitch;
@property (nonatomic, weak) IBOutlet UIButton *controlButton;
@property EBTrackingState trackingState;
@property BOOL bikeInMotion;
@property (nonatomic, strong) EBGPXTrack *track;
@property UIImageView *backgroundImageView;

@end

@implementation EstibikeViewController

- (IBAction) handleUserInteraction:(id)sender {
    
    NSString *action = [[(UIButton *)sender titleLabel] text];
    
    if ([action isEqualToString:@"Start"]) {
        if ([[EBBackgroundWorker sharedManager] trackingState] != EBTracking) {
            [self setLabelsToTrackingState];
            [[EBBackgroundWorker sharedManager] startTracking];
            
        } else {
            NSLog(@"was already tracking no need to restart");
        }
    } else if ([action isEqualToString:@"Finish"]) {
        if ([[EBBackgroundWorker sharedManager] trackingState] == EBReadyToFinalise) {
            [[EBBackgroundWorker sharedManager] complete:self.uploadSwitch.isOn];
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

    self.backgroundImageView = [[UIImageView alloc] initWithFrame:self.view.frame];
    self.backgroundImageView.image = [UIImage imageNamed:@"splash_screen.png"];
    [self setLabelsToWaitingState];
    
    //set it as a subview
    [self.view addSubview:self.backgroundImageView];
    [self.view sendSubviewToBack:self.backgroundImageView];
    [self setDebugText:@"Waiting"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) resetCounters {
    NSLog(@"resetLabels");
    [self setDebugText:@"Debug info"];
    self.controlButton.hidden = YES;
    self.distanceLabel.text = @"";
    self.timeLabel.text = @"";
    self.uploadLabel.hidden = YES;
    self.uploadSwitch.hidden = YES;
}

- (void) setLabelsToReadyState {
    
    NSLog(@"setlabels to ready");
    [self setDebugText:@"Ready"];
    self.waitingLabel.text = @"#estibike ready...";
    self.controlButton.hidden = NO;
    self.controlButton.backgroundColor = [UIColor colorWithRed:(163/255.0) green:(195.0/255.0) blue:(167.0/255.0) alpha:1.0];
    [self.controlButton setTitle:@"Start" forState:UIControlStateNormal];
    self.backgroundImageView.image = [UIImage imageNamed:@"splash_screen.png"];
    
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
    self.backgroundImageView.image = [UIImage animatedImageNamed:@"splash_screen" duration:0.09];
    //set it as a subview
    [self.view addSubview:self.backgroundImageView];
    //just in case
    [self.view sendSubviewToBack:self.backgroundImageView];
    self.controlButton.hidden = YES;
    self.distanceLabel.text = @"";
    self.timeLabel.text = @"";
    self.uploadLabel.hidden = YES;
    self.uploadSwitch.hidden = YES;
    
}
- (void) setLabelsToCouldFinishState {
        NSLog(@"setLabelsToCouldFinishState");
        [self setDebugText:@"Could finish"];
        self.backgroundImageView.image = [UIImage animatedImageNamed:@"splash_screen" duration:0.75];
        [self.view addSubview:self.backgroundImageView];
        [self.view sendSubviewToBack:self.backgroundImageView];
}

- (void) setLabelsToFinaliseState {
    NSLog(@"setlabels to finalise");
    
    double distance =[[PSLocationManager sharedLocationManager] totalDistance];
    self.distanceLabel.text = [NSString stringWithFormat:@"%.2f km", (distance / 1000)];
    NSString *timeSpent = [self getFormattedTimeString];
    self.timeLabel.text = timeSpent;
    
    self.uploadLabel.hidden = NO;
    self.uploadSwitch.hidden = NO;
    self.controlButton.hidden = NO;
    self.controlButton.backgroundColor = [UIColor colorWithRed:(144.0/255.0) green:(40.0/255.0) blue:(102.0/255.0) alpha:1.0];
    [self.controlButton setTitle:@"Finish" forState:UIControlStateNormal];
    self.waitingLabel.text = [self getMessageForJourney:distance];
    [self setDebugText:@"Ready to finish"];
    self.backgroundImageView.image = [UIImage imageNamed:@"splash_screen.png"];
    
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
        UILocalNotification *notification = [[UILocalNotification alloc] init];
        notification.alertBody = @"Hey! #estibike done!";
        notification.soundName = UILocalNotificationDefaultSoundName;
        [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
    }
}

- (void) setLabelsToWaitingState {
    
    NSLog(@"setlabels to waiting");
    self.controlButton.hidden = YES;
    [self setDebugText:@"Waiting"];
    self.waitingLabel.text = @"#estibike waiting...";
    self.backgroundImageView.image = [UIImage imageNamed:@"splash_screen.png"];
    self.distanceLabel.text = @"";
    self.timeLabel.text = @"";
    self.uploadLabel.hidden = YES;
    self.uploadSwitch.hidden = YES;
}

- (NSString*) getFormattedTimeString {
    
    NSTimeInterval journeyTime = [[EBBackgroundWorker sharedManager] getJourneyTime];
    
    long journeySeconds = lroundf(journeyTime);
    int hours = journeySeconds / 3600;
    int mins = (journeySeconds % 3600) / 60;
    int secs = journeySeconds % 60;
    
    if (hours > 0) {
        return [NSString stringWithFormat:@"%dh %02dm %02ds", hours, mins,secs];
    } else {
        return [NSString stringWithFormat:@"%02dm %02ds", mins,secs];
    }
}

- (NSString*) getMessageForJourney:(double)distance {
    
    NSString *encouragingString;
    
    if (distance < 5000) {
        encouragingString = @"#estibike needs a rest!";
    } else if (distance > 5000 && distance < 1000) {
        encouragingString = @"#estibike is very tired now!";
    } else {
        encouragingString = @"PLEASE let #estibike rest!";
    }
    
    return encouragingString;
    
}



#pragma mark EBBackgroundWorkerDelegate
- (void) backgroundWorkerSendBikeMotionFlag:(BOOL)isInMotion {
    
    if (isInMotion && (self.trackingState == EBWaiting || self.trackingState == EBReadyToTrack)) {
        [self animateBackgroundWithSpeed:2];
    } else if (!isInMotion && ((self.trackingState == EBWaiting || self.trackingState == EBReadyToTrack))) {
        self.backgroundImageView.image = [UIImage imageNamed:@"splash_screen.png"];
    }
}
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
                [self setLabelsToCouldFinishState];
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

- (void) animateBackgroundWithSpeed:(double)speed {
    self.backgroundImageView.image = [UIImage animatedImageNamed:@"splash_screen" duration:speed];
    //set it as a subview
    [self.view addSubview:self.backgroundImageView]; //in your case, again, use _blurView
    //just in case
    [self.view sendSubviewToBack:self.backgroundImageView];
}

- (void) backgroundWorkerUpdatedSpeed:(double)speed {
    
    // the bigger this is, the faster we want the animation to be
    double newDuration = pow(log(speed * speed), -1);
    if (newDuration == INFINITY || newDuration == 0) newDuration = 1;
    
    NSLog(@"speed is %.2f", speed);
    if (self.trackingState == EBTracking) {
        [self animateBackgroundWithSpeed:newDuration];
    }
}
- (void) backgroundWorkerUpdatedDistance:(NSString *)distance {
    //self.distanceLabel.text = distance;
}

@end
