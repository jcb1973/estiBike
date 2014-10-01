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
@property (nonatomic, strong) EBGPXTrack *track;

@end

@implementation EstibikeViewController

- (void) resetCounters
{
    self.currentSpeed.text = @"Current speed";
    self.distanceLabel.text = @"Distance travelled";
    self.statusLabel.text = @"Not tracking";
    self.debugLabel.text = @"Debug info";
}
- (IBAction) forceStopTracking:(id)sender
{
    NSLog(@"forceStopTracking:+");
    
    [self resetCounters];
    
    if ([[EBBackgroundWorker sharedManager] isTracking]) {
        [[EBBackgroundWorker sharedManager] stopTracking];
    } else {
        NSLog(@"wasn't tracking no need to stop");
    }
    
    NSLog(@"forceStopTracking:-");    
}

- (IBAction) forceStartTracking:(id)sender
{
    NSLog(@"forceStartTracking:+");
    
    if (![[EBBackgroundWorker sharedManager] isTracking]) {
        [self setLabelsToTrackingState];
        [[EBBackgroundWorker sharedManager] startTracking];
        
    } else {
        NSLog(@"was already tracking no need to restart");
    }
    
    NSLog(@"forceStartTracking:-");
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // I'm the person who is going to listen to you... Any time you call method from protocol, I'll deal with it.
    [[EBBackgroundWorker sharedManager] setDelegate:self];
    //Create UIImageView
    UIImageView *backgroundImageView = [[UIImageView alloc] initWithFrame:self.view.frame]; //or in your case you should use your _blurView
    backgroundImageView.image = [UIImage imageNamed:@"splash_screen.png"];
    
    //set it as a subview
    [self.view addSubview:backgroundImageView]; //in your case, again, use _blurView
    
    //just in case
    [self.view sendSubviewToBack:backgroundImageView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) setLabelsToTrackingState {
    self.statusLabel.text = @"Tracking";
    self.currentSpeed.text = @"waiting...";
    self.distanceLabel.text = @"waiting...";
}

#pragma mark EBBackgroundWorkerDelegate
- (void) backgroundWorkerStartedTracking {
    NSLog(@" *** started tracking *** ");
    //self.debugLabel.text = status;
    // set button states
    [self setLabelsToTrackingState];
    NSLog(@"foo");
}

- (void) backgroundWorkerStoppedTracking {
    NSLog(@" *** stopped tracking *** ");
    //self.debugLabel.text = status;
    // set button states
    [self resetCounters];
    NSLog(@"foo");
}

- (void) backgroundWorkerUpdatedStatus:(NSString *)status {
    NSLog(@"Invoked EBBackgroundWorkerDelegate with status %@ ", status);
    self.debugLabel.text = status;
}
- (void) backgroundWorkerUpdatedSpeed:(NSString *)speed {
    NSLog(@"Invoked EBBackgroundWorkerDelegate with speed %@ ", speed);
    self.currentSpeed.text = speed;
}
- (void) backgroundWorkerUpdatedDistance:(NSString *)distance {
    NSLog(@"Invoked EBBackgroundWorkerDelegate with distance %@ ", distance);
    self.distanceLabel.text = distance;
}

@end
