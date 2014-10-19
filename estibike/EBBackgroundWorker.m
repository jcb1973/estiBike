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
        self.rssiHistory = [[NSMutableArray alloc] init];
        
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

- (void) restartTracking {
    
    self.trackingState = EBTracking;
    [[PSLocationManager sharedLocationManager] startLocationUpdates];
    
    if ([self.delegate respondsToSelector:@selector(backgroundWorkerSendStateChange:)]) {
        [self.delegate backgroundWorkerSendStateChange:self.trackingState];
    }
    
    [self sendDebug:@"reStarted tracking"];
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
    [self.beaconManager requestStateForRegion:self.bikeStaticRegion];
    [self.beaconManager requestStateForRegion:self.bikeMovingRegion];
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
    self.track = nil;
    [self.rssiHistory removeAllObjects];
    self.trackingState = EBWaiting;
    [self stopTracking];
}

#pragma mark ESTBeaconManagerDelegate
- (void)beaconManager:(ESTBeaconManager *)manager didDetermineState:(CLRegionState)state forRegion:(ESTBeaconRegion *)region {
    
    NSLog(@"\n ***** determined state %d FOR REGION %@ with current tracking state %u ***** \n", state, region.identifier, self.trackingState);
    
    switch (state) {
        case CLRegionStateUnknown:
            NSLog(@"unknown");
            break;
        case CLRegionStateInside:
            NSLog(@"inside %@ region", region.identifier);
            // Doesn't matter what region -  look for bike. Don't change state though
            [self.beaconManager startRangingBeaconsInRegion:self.bikeMovingRegion];
            [self.beaconManager startRangingBeaconsInRegion:self.bikeStaticRegion];
            if ([region.identifier isEqualToString:EB_STATIC_REGION] && self.trackingState == EBCouldFinish) {
                // perhaps we should finish?
                [self sendDebug:@"determined inside static region in EBCouldFinish state - sending ready to finalise"];
                self.trackingState = EBReadyToFinalise;
            }
            break;
        case CLRegionStateOutside:
            //[self.beaconManager stopRangingBeaconsInRegion:region];
            NSLog(@"outside %@ region", region.identifier);
            // outside either - set to ready to finalise if in EBCouldFinish?
            if ([region.identifier isEqualToString:EB_STATIC_REGION] || [region.identifier isEqualToString:EB_MOVING_REGION]) {
                if (self.trackingState == EBCouldFinish) {
                    [self sendDebug:[NSString stringWithFormat:@"determined outside %@ region in EBCouldFinish state - sending ready to finalise", region.identifier]];
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

-(void) recordRSSIWhenMoving:(int)rssi {
    
    if (self.trackingState == EBTracking) {
        [self.rssiHistory addObject:[NSNumber numberWithDouble:rssi]];
    }
}

-(double) getAverageMovingRSSI {
    int total = 0;
    int count = [self.rssiHistory count];
    
    for (NSNumber *item in self.rssiHistory) {
        
        total += [item intValue];
    }
    
    double average = 1.0 * total / count;
    return average;
}

-(double) getSTDDevForMovingRSSI {
    
    double average = [self getAverageMovingRSSI];
    int count = [self.rssiHistory count];
    // Sum difference squares
    double diff, diffTotal = 0;
    
    for (NSNumber *item in self.rssiHistory) {
        
        diff = [item doubleValue] - average;
        diffTotal += diff * diff;
    }
    
    // Set variance (average from total differences)
    double variance = diffTotal / count; // -1 if sample std deviation
    
    // Standard Deviation, the square root of variance
    double stdDeviation = sqrt(variance);
    return stdDeviation;
}

// fired every second
-(void) beaconManager:(ESTBeaconManager *)manager
      didRangeBeacons:(NSArray *)beacons
             inRegion:(ESTBeaconRegion *)region {

    ESTBeacon *beacon = [[ESTBeacon alloc] init];
    beacon = [beacons lastObject];
    
    NSLog(@"r+ %@ blo %@", region.identifier, beacon.proximityUUID);
    if ([region.identifier isEqualToString:EB_MOVING_REGION]) {
        
        if (beacon != nil) {
            [self sendDebug:@"Bike in motion"];
            [self recordRSSIWhenMoving:abs(beacon.rssi)];
            
            if (self.trackingState == EBWaiting && beacon.proximity <= CLProximityNear) {
                self.trackingState = EBReadyToTrack;
                [[PSLocationManager sharedLocationManager] prepLocationUpdates];
            }
            if ([self.delegate respondsToSelector:@selector(backgroundWorkerSendBikeMotionFlag:)]) {
                [self.delegate backgroundWorkerSendBikeMotionFlag:YES];
            }
            
            // if we've paused, restart tracking tracking then
            if (self.trackingState == EBReadyToFinalise || self.trackingState == EBCouldFinish) {
                self.trackingState = EBTracking;
                [self restartTracking];
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
    } else if ([region.identifier isEqualToString:EB_STATIC_REGION]) {
       // NSLog(@"ranged static region beacon proximity is %d", beacon.proximity);
        if (self.trackingState == EBCouldFinish) {
            
            // We think we've stopped, determine if we should send "EBFinalise" state

            if (beacon != nil) {
                [self sendDebug:[NSString stringWithFormat:@"could finish? beacon proximity %d current speed is %.2f rssi %d", beacon.proximity, [[PSLocationManager sharedLocationManager] currentSpeed], abs(beacon.rssi)]];
                NSLog(@"beacon proximity %d current speed is %.2f rssi %d", beacon.proximity, [[PSLocationManager sharedLocationManager] currentSpeed], abs(beacon.rssi));
                
                //
                // Here's where we figure out we can finish.
                //
                // Things that mean we can finish: - proximity not immediate
                //                                 - walking speed (so look for speed < 6000 / 3600 == 1.6)
                //                                 - weak GPS?
                //
                // Maybe we don't need to look for RSSI dropping if we are walking speed...?
                // Trying new approach with looking for rssi more than 1 stddev from average during journey.
                // Could tweak this to store, eg last 2 minutes.
                //
                double avgRSSI = [self getAverageMovingRSSI];
                double stddevRSSI = [self getSTDDevForMovingRSSI];
                double targetRSSI = avgRSSI + (1.0 * stddevRSSI);
                NSLog(@"avgRSSI %.2f stdev %.2f target %.2f", avgRSSI,stddevRSSI, targetRSSI);
                
                if (beacon.proximity >= CLProximityNear && ([[NSDate date] timeIntervalSinceDate: self.journeyStarted] > 30.0) ) {
                
                    NSLog(@"beacon proximity %d current speed is %.2f firstRecordedRSSI %.2f currentRSSI %ld", beacon.proximity, [[PSLocationManager sharedLocationManager] currentSpeed], avgRSSI, (long)abs(beacon.rssi));
                    
                    int currentRSSI = abs(beacon.rssi);
                    if (currentRSSI >= targetRSSI)  {
                        [self sendDebug:[NSString stringWithFormat:@"ready to finalise sent avg RRSI %.2f target rssi %.2f beacon proximity %d current speed is %.2f rssi %d", avgRSSI, targetRSSI, beacon.proximity, [[PSLocationManager sharedLocationManager] currentSpeed], abs(beacon.rssi)]];
                       self.trackingState = EBReadyToFinalise;
                    }
                }
            } else {
                [self sendDebug:@"in static region and got nil beacon"];
                // in static region and got nil... - could finalise?
            }
        } // end if state couldfinish
    } // end if static region
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
            [self sendDebug:@"didExitRegion, moving region, was EBCouldFinish, so sending EBReadyToFinalise"];
            self.trackingState = EBReadyToFinalise;
        }
    } else if ([region.identifier isEqualToString:EB_STATIC_REGION] && self.trackingState == EBCouldFinish) {
        [self sendDebug:@"didExitRegion, static region, was EBCouldFinish, so sending EBReadyToFinalise"];
        self.trackingState = EBReadyToFinalise;
        [self stopTracking];
    }
    if([self.delegate respondsToSelector:@selector(backgroundWorkerSendStateChange:)]) {
        [self.delegate backgroundWorkerSendStateChange:self.trackingState];
    }
}

#pragma mark PSLocationManagerDelegate
-(void)locationManager:(PSLocationManager *)locationManager waypoint:(CLLocation *)waypoint calculatedSpeed:(double)calculatedSpeed {
    
    // if we are tracking, or even if we have paused, or are in finalise state but haven't clicked button yet
    // basically, any state apart from waiting or ready to track (i.e. not started), record the waypoint
    if (self.trackingState != EBWaiting && self.trackingState != EBReadyToTrack) {
        NSLog(@"called waypoint while not in waiting state+");
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
