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
        self.statusLabel.text = @"Tracking";
        self.currentSpeed.text = @"waiting...";
        self.distanceLabel.text = @"waiting...";
    
        [[EBBackgroundWorker sharedManager] startTracking];
    } else {
        NSLog(@"was already tracking no need to restart");
    }
    
    NSLog(@"forceStartTracking:-");
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
