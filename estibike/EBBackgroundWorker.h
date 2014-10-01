//
//  EBBackgroundWorker.h
//  estibike
//
//  Created by John Cieslik-Bridgen on 01/10/14.
//  Copyright (c) 2014 jcb1973. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ESTBeaconManager.h"
#import "EBGPXTrack.h"
#import "PSLocationManager.h"

@interface EBBackgroundWorker : NSObject <ESTBeaconManagerDelegate, PSLocationManagerDelegate>

@property (nonatomic, strong) NSString *bikeUUID;
@property (nonatomic, strong) NSString *bikeMovingUUID;
@property (nonatomic, strong) NSNumber *bikeMajor;
@property (nonatomic, strong) NSNumber *bikeMinor;

@property (nonatomic, strong) ESTBeacon         *beacon;
@property (nonatomic, strong) ESTBeaconManager  *beaconManager;
@property (nonatomic, strong) ESTBeaconRegion   *bikeRegion;
@property (nonatomic, strong) ESTBeaconRegion   *bikeMovingRegion;

@property (nonatomic, strong) EBGPXTrack *track;

@property BOOL isTracking;

+ (id)sharedManager;

- (void) lookForBike;
- (void) lookForBikeMovement;

- (void) startTracking;
- (void) stopTracking;

@end
