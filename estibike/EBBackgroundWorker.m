//
//  EBBackgroundWorker.m
//  estibike
//
//  Created by John Cieslik-Bridgen on 01/10/14.
//  Copyright (c) 2014 jcb1973. All rights reserved.
//

#import "EBBackgroundWorker.h"
#import "PSLocationManager.h"
#import "EBGPXTrackpoint.h"
#import "EBGPXTrack.h"
#import "FRDStravaClientImports.h"

#define DO_REAL_UPLOAD  NO
#define EB_UUID         @"8195AC37-CD0F-4538-B49E-172DF15FF4F4"
#define EB_MOTION_UUID  @"B9407F30-F5F8-466E-AFF9-25556B57FE6D"
#define EB_MAJOR        34692
#define EB_MINOR        11408

@implementation EBBackgroundWorker

+ (EBBackgroundWorker *)sharedManager
{
    static EBBackgroundWorker *ebBackgroundWorker = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ebBackgroundWorker = [[self alloc] init];
    });
    return ebBackgroundWorker;
}

- (id)init {
    if (self = [super init]) {
        
        self.isTracking = NO;
        self.bikeUUID = EB_UUID;
        self.bikeMovingUUID = EB_MOTION_UUID;
        self.bikeMajor = [NSNumber numberWithInt:EB_MAJOR];
        self.bikeMinor = [NSNumber numberWithInt:EB_MINOR];
        
        // setup Estimote beacon manager
        self.beaconManager = [[ESTBeaconManager alloc] init];
        self.beaconManager.delegate = self;
        
        [[PSLocationManager sharedLocationManager] prepLocationUpdates];
        [PSLocationManager sharedLocationManager].delegate = self;
    }
    return self;
}

- (void) startTracking {
    
    self.isTracking = YES;
    [self setUpGPX];
    [[PSLocationManager sharedLocationManager] startLocationUpdates];
    
    [self sendStatus:@"Started tracking"];
}

- (void) stopTracking {
    
    self.isTracking = NO;
    [[PSLocationManager sharedLocationManager] stopLocationUpdates];
    [[PSLocationManager sharedLocationManager] resetLocationUpdates];
    [self logGPXToFile];
}

- (void) lookForBike {
    
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:self.bikeUUID];
    self.bikeRegion = [[ESTBeaconRegion alloc] initWithProximityUUID:uuid
                                                                 major:[self.bikeMajor integerValue]
                                                                 minor:[self.bikeMinor integerValue]
                                                            identifier:@"estibike"];
    
    // start looking for bike
    [self.beaconManager startMonitoringForRegion:self.bikeRegion];
    [self.beaconManager requestStateForRegion:self.bikeRegion];
}

- (void) lookForBikeMovement {
    
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:self.bikeMovingUUID];
    self.bikeMovingRegion = [[ESTBeaconRegion alloc] initWithProximityUUID:uuid
                                                               major:[self.bikeMajor integerValue]
                                                               minor:[self.bikeMinor integerValue]
                                                          identifier:@"estibikemoving"];
    
    // start looking for bike
    [self.beaconManager startMonitoringForRegion:self.bikeMovingRegion];
    [self.beaconManager requestStateForRegion:self.bikeMovingRegion];
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
    
    if (DO_REAL_UPLOAD) {
        [[FRDStravaClient sharedInstance] uploadActivity:URL
                                                name:self.track.name
                                        activityType:kUnknownType
                                            dataType:kUploadDataTypeGPX
                                             private:NO
     
                                             success:^(StravaActivityUploadStatus *uploadStatus) {
                                                 NSLog(@"upload sent");
                                                 NSLog(@"%@",[uploadStatus debugDescription]);
                                                 //self.debugLabel.text = [uploadStatus debugDescription];
                                             }
     
                                             failure:^(NSError *error) {
                                                 UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Upload failed"
                                                                                              message:error.localizedDescription
                                                                                             delegate:nil
                                                                                    cancelButtonTitle:@"Ok"
                                                                                    otherButtonTitles: nil];
                                                 [av show];
                                             }];
    }
    NSLog(@"uploadGPX:-");
}

#pragma mark ESTBeaconManagerDelegate
- (void)beaconManager:(ESTBeaconManager *)manager didDetermineState:(CLRegionState)state forRegion:(ESTBeaconRegion *)region
{
    NSLog(@"\n\n ***** DETERMINED STATE %d FOR REGION %@ ***** \n\n", state, region.identifier);
    
    switch (state) {
        case CLRegionStateUnknown:
            NSLog(@"unknown");
            break;
        case CLRegionStateInside:
            NSLog(@"inside");
            break;
        case CLRegionStateOutside:
            NSLog(@"outside");
            break;
            
        default:
            break;
    }
}


- (void)beaconManager:(ESTBeaconManager *)manager didEnterRegion:(ESTBeaconRegion *)region
{
    NSLog(@"\n\n ***** ENTERED %@ REGION EVENT ***** \n\n", region.identifier);
}

- (void)beaconManager:(ESTBeaconManager *)manager didExitRegion:(ESTBeaconRegion *)region
{
    NSLog(@"\n\n ***** EXITED %@ REGION EVENT ***** \n\n", region.identifier);
}

#pragma mark PSLocationManagerDelegate
-(void)locationManager:(PSLocationManager *)locationManager waypoint:(CLLocation *)waypoint calculatedSpeed:(double)calculatedSpeed {
    
    NSLog(@"called waypoint+");
    
    EBGPXTrackpoint *point = [[EBGPXTrackpoint alloc] initWithLongitude:[NSNumber numberWithDouble:waypoint.coordinate.longitude] latitude:[NSNumber numberWithDouble:waypoint.coordinate.latitude]];
    [self.track addTrackpoint:point];
    if ([[PSLocationManager sharedLocationManager] currentSpeed] > 0) {
        double kmPerHour = [[PSLocationManager sharedLocationManager] currentSpeed] * 60 * 60 / 1000 ;
        //self.currentSpeed.text = [NSString stringWithFormat:@"%.2f km/h", kmPerHour];
        NSLog(@"%.2f km/h", kmPerHour);
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
    //self.distanceLabel.text = [NSString stringWithFormat:@"%.2f %@", distance, NSLocalizedString(@"meters", @"")];
    NSLog(@"%.2f meters", distance);
}

- (void)locationManager:(PSLocationManager *)locationManager error:(NSError *)error {
    // location services is probably not enabled for the app
    //self.strengthLabel.text = NSLocalizedString(@"Unable to determine location", @"");
    NSLog(@"Unable to determine location");
}

#pragma mark - Utilities

- (void)sendStatus:(NSString *)status
{
    if([self.delegate respondsToSelector:@selector(backgroundWorkerUpdatedStatus:)])
    {
        [self.delegate backgroundWorkerUpdatedStatus:status];
    }
}

@end
