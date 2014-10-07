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
#import "EBGPXManager.h"

#define EB_UUID         @"B9407F30-F5F8-466E-AFF9-25556B57FE6D"
#define EB_MOTION_UUID  @"B9407F30-F5F8-466E-AFF9-25556B57FE6A"
#define EB_MAJOR        34696 //keeping these in to avoid false positives
#define EB_MINOR        11408
#define EB_MOVING_REGION @"estibikemoving"
#define EB_STATIC_REGION @"estibike"
#define EB_BIKE_MIN_SPEED 10

@implementation EBBackgroundWorker

+ (EBBackgroundWorker *)sharedManager {
    static EBBackgroundWorker *ebBackgroundWorker = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ebBackgroundWorker = [[self alloc] init];
    });
    return ebBackgroundWorker;
}

int firstRecordedRSSI = -1;

- (id)init {
    
    if (self = [super init]) {

        self.trackingState = EBWaiting;
        self.bikeMovingUUID = EB_MOTION_UUID;
        self.bikeStaticUUID = EB_UUID;
        self.bikeMajor = [NSNumber numberWithInt:EB_MAJOR];
        self.bikeMinor = [NSNumber numberWithInt:EB_MINOR];
        
        // setup Estimote beacon manager and define two regions
        self.beaconManager = [[ESTBeaconManager alloc] init];
        self.beaconManager.delegate = self;
        
        NSUUID *motionUUID = [[NSUUID alloc] initWithUUIDString:self.bikeMovingUUID];
        self.bikeMovingRegion = [[ESTBeaconRegion alloc] initWithProximityUUID:motionUUID
                                                                         major:[self.bikeMajor integerValue]
                                                                         minor:[self.bikeMinor integerValue]
                                                                    identifier:EB_MOVING_REGION];
        NSUUID *staticUUID = [[NSUUID alloc] initWithUUIDString:self.bikeStaticUUID];
        self.bikeStaticRegion = [[ESTBeaconRegion alloc] initWithProximityUUID:staticUUID
                                                                         major:[self.bikeMajor integerValue]
                                                                         minor:[self.bikeMinor integerValue]
                                                                    identifier:EB_STATIC_REGION];
        
        [PSLocationManager sharedLocationManager].delegate = self;
    }
    return self;
}

- (void) startTracking {
    
    self.trackingState = EBTracking;
    [self setUpTrack];
    self.journeyStarted = [NSDate date];
    [[PSLocationManager sharedLocationManager] startLocationUpdates]; 
    
    if ([self.delegate respondsToSelector:@selector(backgroundWorkerSendStateChange:)]) {
            [self.delegate backgroundWorkerSendStateChange:self.trackingState];
    }
    
    [self sendDebug:@"Started tracking"];
}

- (void) stopTracking {
    
    NSLog(@"Stopping PSLocationManager services");
    [[PSLocationManager sharedLocationManager] stopLocationUpdates];
    [[PSLocationManager sharedLocationManager] resetLocationUpdates];
    [self sendDebug:@"Stopped tracking"];
}

- (NSTimeInterval) getJourneyTime {
    return [[NSDate date] timeIntervalSinceDate:self.journeyStarted];
}

- (void) lookForBike {
    
    // start looking for bike - moving or static
    [self.beaconManager startMonitoringForRegion:self.bikeMovingRegion];
    [self.beaconManager startMonitoringForRegion:self.bikeStaticRegion];
}

- (void) setUpTrack {
    
    NSLog(@"setUpTrack:+");
    NSString *dateString = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                          dateStyle:NSDateFormatterShortStyle
                                                          timeStyle:NSDateFormatterShortStyle];
    if (!self.track) {
        self.track = [[EBGPXTrack alloc] initWithName:dateString];
        NSLog(@"track name is %@", self.track.name);
    }
}

- (void) complete:(BOOL)doUpload {
    
    [[EBGPXManager sharedManager] logGPXToFile:self.track withUpload:doUpload];
    self.journeyEnded = [NSDate date];
    self.track = nil;
    self.trackingState = EBWaiting;
    [self stopTracking];
}

#pragma mark ESTBeaconManagerDelegate
- (void)beaconManager:(ESTBeaconManager *)manager didDetermineState:(CLRegionState)state forRegion:(ESTBeaconRegion *)region
{
    NSLog(@"\n ***** determined state %d FOR REGION %@ with current tracking state %u ***** \n", state, region.identifier, self.trackingState);
    
    switch (state) {
        case CLRegionStateUnknown:
            NSLog(@"unknown");
            break;
        case CLRegionStateInside:
            NSLog(@"inside %@ region", region.identifier);
            // Doesn't matter what region -  look for movement. Don't change state though
            [self.beaconManager startRangingBeaconsInRegion:self.bikeMovingRegion];
            if ([region.identifier isEqualToString:EB_STATIC_REGION] && self.trackingState == EBCouldFinish) {
                // perhaps we should finish?
                self.trackingState = EBReadyToFinalise;
            }
            break;
        case CLRegionStateOutside:
            //[self.beaconManager stopRangingBeaconsInRegion:region];
            NSLog(@"outside %@ region", region.identifier);
            // outside either - set to ready to finalise if in EBCouldFinish?
            if ([region.identifier isEqualToString:EB_STATIC_REGION] || [region.identifier isEqualToString:EB_MOVING_REGION]) {
                if (self.trackingState == EBCouldFinish) {
                    self.trackingState = EBReadyToFinalise;
                }
            }
            break;
            
        default:
            break;
    }
    
    if([self.delegate respondsToSelector:@selector(backgroundWorkerSendStateChange:)]) {
        [self.delegate backgroundWorkerSendStateChange:self.trackingState];
    }
}

// fired every second
-(void) beaconManager:(ESTBeaconManager *)manager
      didRangeBeacons:(NSArray *)beacons
             inRegion:(ESTBeaconRegion *)region {

    if ([region.identifier isEqualToString:EB_MOVING_REGION]) {
        
        ESTBeacon *beacon = [[ESTBeacon alloc] init];
        beacon = [beacons lastObject];
        if (beacon != nil) {
            if (self.trackingState == EBWaiting && beacon.proximity <= CLProximityNear) {
                self.trackingState = EBReadyToTrack;
                [[PSLocationManager sharedLocationManager] prepLocationUpdates];
            }
            [self sendDebug:@"Bike in motion"];
            if ([self.delegate respondsToSelector:@selector(backgroundWorkerSendBikeMotionFlag:)]) {
                [self.delegate backgroundWorkerSendBikeMotionFlag:YES];
            }
            // if we've paused, restart tracking tracking then
            if (self.trackingState == EBReadyToFinalise || self.trackingState == EBCouldFinish) {
                self.trackingState = EBTracking;
                [self startTracking];
                // reset
                firstRecordedRSSI = -1;
            } else if (self.trackingState == EBWaiting) {
                self.trackingState = EBReadyToTrack;
                [[PSLocationManager sharedLocationManager] prepLocationUpdates];
            }
        } else {
            [self sendDebug:[NSString stringWithFormat:@"Not moving - tracking state is %u", self.trackingState]];
            if ([self.delegate respondsToSelector:@selector(backgroundWorkerSendBikeMotionFlag:)]) {
                [self.delegate backgroundWorkerSendBikeMotionFlag:NO];
            }
            // enter EBCouldFinish state if we are tracking, we want to catch the end of ride asap
            if (self.trackingState == EBTracking) {
                [self sendDebug:@"tracking, but not moving - could finish?"];
                self.trackingState = EBCouldFinish;
                // look for the static bike
                NSLog(@"I'll look for the static bike");
                [self.beaconManager startRangingBeaconsInRegion:self.bikeStaticRegion];
            }
        }
    } else if ([region.identifier isEqualToString:EB_STATIC_REGION] && self.trackingState == EBCouldFinish) {
        [self sendDebug:@"could finish?"];
        // We think we've stopped, determine if we should send "EBFinalise" state
        ESTBeacon *beacon = [[ESTBeacon alloc] init];
        beacon = [beacons lastObject];
        if (beacon != nil) {
            NSLog(@"beacon proximity %d current speed is %.2f rssi %d", beacon.proximity, [[PSLocationManager sharedLocationManager] currentSpeed], abs(beacon.rssi));
            
            //
            // Here's where we figure out we can finish.
            //
            if (beacon.proximity >= CLProximityNear) {
            //self.trackingState = EBReadyToFinalise;
                NSLog(@"beacon proximity %d current speed is %.2f firstRecordedRSSI %d currentRSSI %ld", beacon.proximity, [[PSLocationManager sharedLocationManager] currentSpeed], firstRecordedRSSI, (long)abs(beacon.rssi));
                // see if the signal strength is decreasing
                if (firstRecordedRSSI == -1) {
                    firstRecordedRSSI = abs(beacon.rssi);
                } else {
                    int currentRSSI = abs(beacon.rssi);
                    if ((currentRSSI - firstRecordedRSSI >= 2
                         ) && firstRecordedRSSI != -1)  {
                       self.trackingState = EBReadyToFinalise;
                    }
                }
            }
        } else {
            // in static region and got nil... - could finalise?
        }
    }
    if ([self.delegate respondsToSelector:@selector(backgroundWorkerSendStateChange:)]) {
        [self.delegate backgroundWorkerSendStateChange:self.trackingState];
    }
}

- (void)beaconManager:(ESTBeaconManager *)manager didEnterRegion:(ESTBeaconRegion *)region {
    
    NSLog(@"\n ***** ENTERED %@ REGION with tracking state %u ***** \n", region.identifier, self.trackingState);
    if ([region.identifier isEqualToString:EB_MOVING_REGION]) {
        
        if (self.trackingState == EBWaiting) {
            NSLog(@"starting ranging");
            [self.beaconManager startRangingBeaconsInRegion:self.bikeMovingRegion];
            self.trackingState = EBReadyToTrack;
            [[PSLocationManager sharedLocationManager] prepLocationUpdates];
        } else if (self.trackingState == EBReadyToFinalise) {
            self.trackingState = EBTracking;
            // we paused, start again
            NSLog(@"RE starting ranging");
            [self.beaconManager startRangingBeaconsInRegion:self.bikeMovingRegion];
        }
        if ([self.delegate respondsToSelector:@selector(backgroundWorkerSendStateChange:)]) {
            [self.delegate backgroundWorkerSendStateChange:self.trackingState];
        }
    } else if ([region.identifier isEqualToString:EB_STATIC_REGION]) {
        // might as well start looking for movement here too, but not change state
        [self.beaconManager startRangingBeaconsInRegion:self.bikeMovingRegion];
    }
}

- (void)beaconManager:(ESTBeaconManager *)manager didExitRegion:(ESTBeaconRegion *)region
{
    if ([region.identifier isEqualToString:EB_MOVING_REGION]) {
        // the bike isn't moving
        NSLog(@"\n ***** EXITED %@ region with current tracking state %u***** \n", region.identifier, self.trackingState);
        if (self.trackingState == EBTracking) {
            self.trackingState = EBCouldFinish;
            NSLog(@"Looking for the static bike");
            [self.beaconManager startRangingBeaconsInRegion:self.bikeStaticRegion];
            
        } else if (self.trackingState == EBReadyToTrack) {
            NSLog(@"was ready to track, so sending waiting state change");
            self.trackingState = EBWaiting;
            [[PSLocationManager sharedLocationManager] stopLocationUpdates];
        } else if (self.trackingState == EBCouldFinish) {
            NSLog(@"was EBCouldFinish, so sending EBReadyToFinalise");
            self.trackingState = EBReadyToFinalise;
        }
    } else if ([region.identifier isEqualToString:EB_STATIC_REGION] && self.trackingState == EBCouldFinish) {
        NSLog(@"exited static bike region in EBCouldFinish state, can finalise");
        self.trackingState = EBReadyToFinalise;
        [self stopTracking];
    }
    if([self.delegate respondsToSelector:@selector(backgroundWorkerSendStateChange:)]) {
        [self.delegate backgroundWorkerSendStateChange:self.trackingState];
    }
}

#pragma mark PSLocationManagerDelegate
-(void)locationManager:(PSLocationManager *)locationManager waypoint:(CLLocation *)waypoint calculatedSpeed:(double)calculatedSpeed
{
    if (self.trackingState == EBTracking) {
        NSLog(@"called waypoint while tracking+");
        EBGPXTrackpoint *point = [[EBGPXTrackpoint alloc] initWithLongitude:[NSNumber numberWithDouble:waypoint.coordinate.longitude] latitude:[NSNumber numberWithDouble:waypoint.coordinate.latitude]];
        [self.track addTrackpoint:point];
        if ([[PSLocationManager sharedLocationManager] currentSpeed] > 0) {

            if([self.delegate respondsToSelector:@selector(backgroundWorkerUpdatedSpeed:)]) {
                [self.delegate backgroundWorkerUpdatedSpeed:[[PSLocationManager sharedLocationManager] currentSpeed]];
            }
        }
    }
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
}

- (void)locationManagerSignalConsistentlyWeak:(PSLocationManager *)locationManager {
    NSLog(@"Consistently weak");
}

- (void)locationManager:(PSLocationManager *)locationManager distanceUpdated:(CLLocationDistance)distance {
    
}

- (void)locationManager:(PSLocationManager *)locationManager error:(NSError *)error {
    // location services is probably not enabled for the app
    NSLog(@"Unable to determine location");
}

#pragma mark - Utilities

- (void)sendDebug:(NSString *)msg {
    if([self.delegate respondsToSelector:@selector(backgroundWorkerSentDebug:)]) {
        [self.delegate backgroundWorkerSentDebug:msg];
    }
}

@end
