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
#define EB_MAJOR        34696
#define EB_MINOR        11408
#define EB_MOVING_REGION @"estibikemoving"
#define EB_STATIC_REGION @"estibike"

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
        NSLog(@"called init");
        self.trackingState = EBWaiting;
        self.bikeMovingUUID = EB_MOTION_UUID;
        self.bikeStaticUUID = EB_UUID;
        self.bikeMajor = [NSNumber numberWithInt:EB_MAJOR];
        self.bikeMinor = [NSNumber numberWithInt:EB_MINOR];
        
        // setup Estimote beacon managers - one for static one for moving
        self.beaconManager = [[ESTBeaconManager alloc] init];
        self.beaconManager.delegate = self;
        self.staticBeaconManager = [[ESTBeaconManager alloc] init];
        self.staticBeaconManager.delegate = self;
        
        
        NSUUID *muuid = [[NSUUID alloc] initWithUUIDString:self.bikeMovingUUID];
        self.bikeMovingRegion = [[ESTBeaconRegion alloc] initWithProximityUUID:muuid
                                                                         major:[self.bikeMajor integerValue]
                                                                         minor:[self.bikeMinor integerValue]
                                                                    identifier:EB_MOVING_REGION];
        NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:self.bikeStaticUUID];
        self.bikeStaticRegion = [[ESTBeaconRegion alloc] initWithProximityUUID:uuid
                                                                         major:55129
                                                                         minor:48863
                                                                    identifier:EB_STATIC_REGION];
        
        [[PSLocationManager sharedLocationManager] prepLocationUpdates];
        [PSLocationManager sharedLocationManager].delegate = self;
    }
    return self;
}

- (void) startTracking {
    
    self.trackingState = EBTracking;
    [self setUpTrack];
    [[PSLocationManager sharedLocationManager] startLocationUpdates];
    
    if ([self.delegate respondsToSelector:@selector(backgroundWorkerSendStateChange:)]) {
            [self.delegate backgroundWorkerSendStateChange:EBTracking];
    }
    
    [self sendDebug:@"Started tracking"];
}

- (void) stopTracking {
    
    NSLog(@"Stopping PSLocationManager services, stopping 2x beaconmanagers");
    [[PSLocationManager sharedLocationManager] stopLocationUpdates];
    [[PSLocationManager sharedLocationManager] resetLocationUpdates];
    [self.staticBeaconManager stopRangingBeaconsInRegion:self.bikeStaticRegion];
    [self.beaconManager stopRangingBeaconsInRegion:self.bikeMovingRegion];
    [self sendDebug:@"Stopped tracking"];
}

- (void) lookForBikeMovement {
    
    // start looking for moving bike
    [self.beaconManager startMonitoringForRegion:self.bikeMovingRegion];
    //[self.beaconManager requestStateForRegion:self.bikeMovingRegion];
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

- (void) finish {
    
    [[EBGPXManager sharedManager] logGPXToFile:self.track];
    self.track = nil;
    self.trackingState = EBWaiting;
    
}



#pragma mark ESTBeaconManagerDelegate
- (void)beaconManager:(ESTBeaconManager *)manager didDetermineState:(CLRegionState)state forRegion:(ESTBeaconRegion *)region
{
    NSLog(@"\n ***** DETERMINED STATE %d FOR REGION %@ with current tracking state %u ***** \n", state, region.identifier, self.trackingState);
    
    switch (state) {
        case CLRegionStateUnknown:
            NSLog(@"unknown");
            break;
        case CLRegionStateInside:
            NSLog(@"inside %@ region", region.identifier);
            
            if ([region.identifier isEqualToString:EB_MOVING_REGION]) {
                
                [self.beaconManager startRangingBeaconsInRegion:self.bikeMovingRegion];
                
                if (self.trackingState == EBWaiting) {
                    self.trackingState = EBReadyToTrack;
                
                    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
                        [[UIApplication sharedApplication] cancelAllLocalNotifications];
                        UILocalNotification *notification = [[UILocalNotification alloc] init];
                        notification.alertBody = @"Hey! Let's #estibike!";
                        notification.soundName = UILocalNotificationDefaultSoundName;
                        [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
                    }
                }
            }
            break;
        case CLRegionStateOutside:
            //[self.beaconManager stopRangingBeaconsInRegion:region];
            NSLog(@"outside %@ region", region.identifier);
            if ([region.identifier isEqualToString:EB_STATIC_REGION]) {
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

    NSLog(@"ranging + %@", region.identifier);
    if ([region.identifier isEqualToString:EB_MOVING_REGION]) {
        
        ESTBeacon *beacon = [[ESTBeacon alloc] init];
        beacon = [beacons lastObject];
        if (beacon != nil) {
            [self sendDebug:[NSString stringWithFormat:@"Bike in motion, major %@ minor %@", beacon.major, beacon.minor]];
            // if we've paused, restart tracking tracking then
            if (self.trackingState == EBReadyToFinalise || self.trackingState == EBCouldFinish) {
                self.trackingState = EBTracking;
                [self startTracking];
            }
        } else {
            [self sendDebug:[NSString stringWithFormat:@"Not moving - tracking state is %u", self.trackingState]];
            // enter EBCouldFinish state if we are tracking, we want to catch the end of ride asap
            if (self.trackingState == EBTracking) {
                [self sendDebug:@"tracking, but not moving - could finish?"];
                self.trackingState = EBCouldFinish;
                // look for the static bike
                NSLog(@"So I'll look for the static bike");
                [self.staticBeaconManager startRangingBeaconsInRegion:self.bikeStaticRegion];
            }
        }
    } else if ([region.identifier isEqualToString:EB_STATIC_REGION] && self.trackingState == EBCouldFinish) {
        //NSLog(@"could finish ???");
        [self sendDebug:@"could finish?"];
        // We think we've stopped, determine if we should send "EBFinalise" state
        ESTBeacon *beacon = [[ESTBeacon alloc] init];
        beacon = [beacons lastObject];
        if (beacon != nil) {
            NSLog(@"beacon not nil proximity is %d", beacon.proximity);
            if (beacon.proximity != CLProximityImmediate) {
                self.trackingState = EBReadyToFinalise;
            }
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

            if([self.delegate respondsToSelector:@selector(backgroundWorkerSendStateChange:)]) {
                [self.delegate backgroundWorkerSendStateChange:EBReadyToTrack];
            }
        } else if (self.trackingState == EBReadyToFinalise) {
            // we paused, start again
            NSLog(@"RE starting ranging");
            [self.beaconManager startRangingBeaconsInRegion:self.bikeMovingRegion];
            
            if([self.delegate respondsToSelector:@selector(backgroundWorkerSendStateChange:)]) {
                [self.delegate backgroundWorkerSendStateChange:EBTracking];
            }
        }
    }
}

- (void)beaconManager:(ESTBeaconManager *)manager didExitRegion:(ESTBeaconRegion *)region
{
    if ([region.identifier isEqualToString:EB_MOVING_REGION]) {
        // the bike isn't moving
        NSLog(@"\n ***** EXITED %@ region with current tracking state %u***** \n", region.identifier, self.trackingState);
        if (self.trackingState == EBTracking) {
            self.trackingState = EBCouldFinish;
            
            // look for the static bike
            NSLog(@"Looking for the static bike");
            [self.staticBeaconManager startRangingBeaconsInRegion:self.bikeStaticRegion];
            
        } else if (self.trackingState == EBReadyToTrack) {
            NSLog(@"was ready to track, so sending waiting state change");
            self.trackingState = EBWaiting;
        }
        // should keep going...?
        //[self stopTracking];
        //[self.beaconManager stopRangingBeaconsInRegion:region];
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
            double kmPerHour = [[PSLocationManager sharedLocationManager] currentSpeed] * 60 * 60 / 1000 ;

            if([self.delegate respondsToSelector:@selector(backgroundWorkerUpdatedSpeed:)]) {
                [self.delegate backgroundWorkerUpdatedSpeed:[NSString stringWithFormat:@"%.2f km/h", kmPerHour]];
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
    
    //NSLog(@"%@", strengthText);
}

- (void)locationManagerSignalConsistentlyWeak:(PSLocationManager *)locationManager {
    NSLog(@"Consistently weak");
}

- (void)locationManager:(PSLocationManager *)locationManager distanceUpdated:(CLLocationDistance)distance {
    
    if([self.delegate respondsToSelector:@selector(backgroundWorkerUpdatedDistance:)]) {
        [self.delegate backgroundWorkerUpdatedDistance:[NSString stringWithFormat:@"%.2f metres", distance]];
    }
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
