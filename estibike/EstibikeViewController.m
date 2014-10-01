//
//  EstibikeViewController.m
//  estibike
//
//  Created by John Cieslik-Bridgen on 29/09/14.
//  Copyright (c) 2014 jcb1973. All rights reserved.
//

#import "EstibikeViewController.h"
#import <CoreLocation/CoreLocation.h>
#import "EBGPXTrackpoint.h"
#import "EBGPXTrack.h"
#import "FRDStravaClientImports.h"


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
- (IBAction) stopTracking:(id)sender
{
    NSLog(@"stopTracking:+");
    [self resetCounters];
    [self logGPXToFile];
    [[PSLocationManager sharedLocationManager] stopLocationUpdates];
    [[PSLocationManager sharedLocationManager] resetLocationUpdates];
    NSLog(@"stopTracking:-");    
}

- (void) logGPXToFile {
    NSLog(@"logGPXToFile:+");
    
    NSArray *directoryPaths = NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [directoryPaths objectAtIndex:0];
    NSLog(@"%@", documentsDirectoryPath);
  
    NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970];
    NSNumber *timeStampObj = [NSNumber numberWithDouble: timeStamp];
    NSString *fileName = [NSString stringWithFormat:@"%@/%@_out.gpx",
                          documentsDirectoryPath,
                          [timeStampObj stringValue]];
    
    NSString *gpx = self.track.dumpGPX;
 
    NSError *error;
    BOOL ok = [gpx writeToFile:fileName
                        atomically:YES
                        encoding:NSUTF8StringEncoding
                        error:&error];
    
    if (!ok) {
        NSLog(@"Error writing file at %@\n%@",
              documentsDirectoryPath, [error localizedFailureReason]);
    }
    NSURL* URL = [NSURL fileURLWithPath:fileName];
    
    [self uploadGPX:URL];
    
    NSLog(@"%@", gpx);
    NSLog(@"logGPXToFile:-");
}

- (void) uploadGPX:(NSURL *)URL
{
    NSLog(@"uploadGPX:+");
    
    [[FRDStravaClient sharedInstance] initializeWithClientId:1660
                                                clientSecret:@"7bc2f3a1a2e58f492f339d8b9f4e5b745fab9ce2"];
    [[FRDStravaClient sharedInstance] setAccessToken:@"9727d907a025965a2d1bc526ace39ebe17623511"];
    
    [[FRDStravaClient sharedInstance] uploadActivity:URL
                                                name:self.track.name
                                        activityType:kUnknownType
                                            dataType:kUploadDataTypeGPX
                                             private:NO
     
                                             success:^(StravaActivityUploadStatus *uploadStatus) {
                                                 NSLog(@"upload sent");
                                                 NSLog(@"%@",[uploadStatus debugDescription]);
                                                 self.debugLabel.text = [uploadStatus debugDescription];
                                             }
     
                                             failure:^(NSError *error) {
                                                 UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Upload failed"
                                                                                              message:error.localizedDescription
                                                                                             delegate:nil
                                                                                    cancelButtonTitle:@"Ok"
                                                                                    otherButtonTitles: nil];
                                                 [av show];
                                             }];
   NSLog(@"uploadGPX:-");
}

- (void) setUpGPX {
    
    NSLog(@"setUpGPX:+");
    NSString *dateString = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                          dateStyle:NSDateFormatterShortStyle
                                                          timeStyle:NSDateFormatterShortStyle];
    self.track = [[EBGPXTrack alloc] initWithName:dateString];

    NSLog(@"track name is %@", self.track.name);
    NSLog(@"setUpGPX:-");
}


- (IBAction) startTracking:(id)sender
{
    NSLog(@"startTracking:+");
    [self setUpGPX];
    self.statusLabel.text = @"Tracking";
    self.currentSpeed.text = @"waiting...";
    self.distanceLabel.text = @"waiting...";

    [[PSLocationManager sharedLocationManager] startLocationUpdates];
    NSLog(@"startTracking:-");
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [[PSLocationManager sharedLocationManager] prepLocationUpdates];
    [PSLocationManager sharedLocationManager].delegate = self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark PSLocationManagerDelegate
-(void)locationManager:(PSLocationManager *)locationManager waypoint:(CLLocation *)waypoint calculatedSpeed:(double)calculatedSpeed {
    
    NSLog(@"called waypoint+");
    
    EBGPXTrackpoint *point = [[EBGPXTrackpoint alloc] initWithLongitude:[NSNumber numberWithDouble:waypoint.coordinate.longitude] latitude:[NSNumber numberWithDouble:waypoint.coordinate.latitude]];
    [self.track addTrackpoint:point];
    if ([[PSLocationManager sharedLocationManager] currentSpeed] > 0) {
        double kmPerHour = [[PSLocationManager sharedLocationManager] currentSpeed] * 60 * 60 / 1000 ;
        self.currentSpeed.text = [NSString stringWithFormat:@"%.2f km/h", kmPerHour];
        
    }
    
    NSLog(@"called waypoint-");
}

- (void)locationManager:(PSLocationManager *)locationManager signalStrengthChanged:(PSLocationManagerGPSSignalStrength)signalStrength {
    NSString *strengthText;
    if (signalStrength == PSLocationManagerGPSSignalStrengthWeak) {
        strengthText = NSLocalizedString(@"Weak", @"");
    } else if (signalStrength == PSLocationManagerGPSSignalStrengthStrong) {
        strengthText = NSLocalizedString(@"Strong", @"");
    } else {
        strengthText = NSLocalizedString(@"...", @"");
    }
    
    NSLog(@"%@", strengthText);
}

- (void)locationManagerSignalConsistentlyWeak:(PSLocationManager *)locationManager {
    //self.strengthLabel.text = NSLocalizedString(@"Consistently Weak", @"");
    NSLog(@"Consistently weak");
}

- (void)locationManager:(PSLocationManager *)locationManager distanceUpdated:(CLLocationDistance)distance {
    self.distanceLabel.text = [NSString stringWithFormat:@"%.2f %@", distance, NSLocalizedString(@"meters", @"")];
    NSLog(@"%.2f meters", distance);
}

- (void)locationManager:(PSLocationManager *)locationManager error:(NSError *)error {
    // location services is probably not enabled for the app
    //self.strengthLabel.text = NSLocalizedString(@"Unable to determine location", @"");
    NSLog(@"Unable to determine location");
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
