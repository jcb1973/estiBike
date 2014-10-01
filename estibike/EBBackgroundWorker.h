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

// what I'm going to say
@protocol EBBackgroundWorkerDelegate <NSObject>

- (void) backgroundWorkerUpdatedStatus:(NSString *)status;
- (void) backgroundWorkerUpdatedSpeed:(NSString *)speed;
- (void) backgroundWorkerUpdatedDistance:(NSString *)distance;

@end

@interface EBBackgroundWorker : NSObject <ESTBeaconManagerDelegate, PSLocationManagerDelegate>

// who I'm going to talk to
@property (nonatomic, assign) id<EBBackgroundWorkerDelegate> delegate;

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

+ (EBBackgroundWorker *)sharedManager;

- (void) lookForBike;
- (void) lookForBikeMovement;

- (void) startTracking;
- (void) stopTracking;

@end
