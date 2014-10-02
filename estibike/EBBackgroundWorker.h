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

typedef enum {
    EBWaiting = 0
    , EBReadyToTrack
    , EBTracking
    , EBCouldFinish
    , EBReadyToFinalise
} EBTrackingState;

// what I'm going to say
@protocol EBBackgroundWorkerDelegate <NSObject>

- (void) backgroundWorkerSentDebug:(NSString *)msg;
- (void) backgroundWorkerSendStateChange: (EBTrackingState) state;

@end

@interface EBBackgroundWorker : NSObject <ESTBeaconManagerDelegate, PSLocationManagerDelegate>
// who I'm going to talk to
@property (nonatomic, assign) id<EBBackgroundWorkerDelegate> delegate;

@property (nonatomic, strong) NSString *bikeMovingUUID;
@property (nonatomic, strong) NSString *bikeStaticUUID;
@property (nonatomic, strong) NSNumber *bikeMajor;
@property (nonatomic, strong) NSNumber *bikeMinor;

@property (nonatomic, strong) ESTBeacon         *beacon;
@property (nonatomic, strong) ESTBeaconManager  *beaconManager;
@property (nonatomic, strong) ESTBeaconRegion   *bikeMovingRegion;
@property (nonatomic, strong) ESTBeaconRegion   *bikeStaticRegion;

@property (nonatomic, strong) EBGPXTrack *track;

@property (atomic) EBTrackingState trackingState;

+ (EBBackgroundWorker *)sharedManager;

- (void) lookForBikeMovement;
- (void) startTracking;
- (void) stopTracking;
- (void) finish;

@end
