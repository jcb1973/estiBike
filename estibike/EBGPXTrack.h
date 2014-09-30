//
//  EBGPXTrack.h
//  estibike
//
//  Created by John Cieslik-Bridgen on 30/09/14.
//  Copyright (c) 2014 jcb1973. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EBGPXTrackpoint.h"

@interface EBGPXTrack : NSObject

@property (nonatomic, strong) NSMutableArray *trackpoints;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSDate *createdAt;

- (instancetype) initWithName:(NSString *)name;
- (BOOL) addTrackpoint:(EBGPXTrackpoint *) point;
- (NSString*) dumpGPX;

@end
