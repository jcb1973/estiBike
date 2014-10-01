//
//  EBBackgroundWorker.h
//  estibike
//
//  Created by John Cieslik-Bridgen on 01/10/14.
//  Copyright (c) 2014 jcb1973. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ESTBeaconManager.h"

@interface EBBackgroundWorker : NSObject <ESTBeaconManagerDelegate>

@property (nonatomic, strong) NSString *bikeUUID;
@property (nonatomic, strong) NSString *bikeMovingUUID;
@property (nonatomic, strong) NSNumber *bikeMajor;
@property (nonatomic, strong) NSNumber *bikeMinor;

@property (nonatomic, strong) ESTBeacon         *beacon;
@property (nonatomic, strong) ESTBeaconManager  *beaconManager;
@property (nonatomic, strong) ESTBeaconRegion   *bikeRegion;
@property (nonatomic, strong) ESTBeaconRegion   *bikeMovingRegion;

+ (id)sharedManager;

- (void) lookForBike;
- (void) lookForBikeMovement;

@end
