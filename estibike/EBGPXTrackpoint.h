//
//  EBGPXTrackpoint.h
//  estibike
//
//  Created by John Cieslik-Bridgen on 30/09/14.
//  Copyright (c) 2014 jcb1973. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EBGPXTrackpoint : NSObject

@property (nonatomic, strong) NSNumber * longitude;
@property (nonatomic, strong) NSNumber * latitude;
@property NSDate *timestamp;

- (instancetype) initWithLongitude:(NSNumber *) longitude
                          latitude:(NSNumber *) latitude
                         timestamp:(NSDate *) timestamp;

- (instancetype) initWithLongitude:(NSNumber *) longitude
                          latitude:(NSNumber *) latitude;

- (NSString*) printGPX;
- (NSString*) formattedTimestamp;

@end
