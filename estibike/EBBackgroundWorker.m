//
//  EBBackgroundWorker.m
//  estibike
//
//  Created by John Cieslik-Bridgen on 01/10/14.
//  Copyright (c) 2014 jcb1973. All rights reserved.
//

#import "EBBackgroundWorker.h"

#define EB_UUID         @"8195AC37-CD0F-4538-B49E-172DF15FF4F4"
#define EB_MOTION_UUID  @"B9407F30-F5F8-466E-AFF9-25556B57FE6D"
#define EB_MAJOR        34692
#define EB_MINOR        11408

@implementation EBBackgroundWorker

+ (id)sharedManager {
    static EBBackgroundWorker *ebBackgroundWorker = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ebBackgroundWorker = [[self alloc] init];
    });
    return ebBackgroundWorker;
}

- (id)init {
    if (self = [super init]) {
        self.bikeUUID = EB_UUID;
        self.bikeMovingUUID = EB_MOTION_UUID;
        self.bikeMajor = [NSNumber numberWithInt:EB_MAJOR];
        self.bikeMinor = [NSNumber numberWithInt:EB_MINOR];
        
        // setup Estimote beacon manager
        self.beaconManager = [[ESTBeaconManager alloc] init];
        self.beaconManager.delegate = self;
    }
    return self;
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



@end
