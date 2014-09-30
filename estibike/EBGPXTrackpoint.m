//
//  EBGPXTrackpoint.m
//  estibike
//
//  Created by John Cieslik-Bridgen on 30/09/14.
//  Copyright (c) 2014 jcb1973. All rights reserved.
//

#import "EBGPXTrackpoint.h"

@implementation EBGPXTrackpoint

- (instancetype) initWithLongitude:(NSNumber *) longitude
                          latitude:(NSNumber *) latitude
                         timestamp:(NSDate *) timestamp
{
    self = [super init];
    if (self) {
        self.longitude = longitude;
        self.latitude  = latitude;
        self.timestamp = timestamp;
    }    
    return self;
}

- (instancetype) initWithLongitude:(NSNumber *) longitude
                          latitude:(NSNumber *) latitude
{
    self = [super init];
    if (self) {;
        self = [self initWithLongitude:longitude latitude:latitude timestamp:[NSDate date]];
    }
    return self;
}

- (NSString*) printGPX
{
    return [NSString stringWithFormat:@"<trkpt lon=\"%.15f\" lat=\"%.15f\">\n%@\n</trkpt>\n", [self.longitude doubleValue], [self.latitude doubleValue], [self formattedTimestamp]];
}

- (NSString*) formattedTimestamp
{
    // what we want <time>2014-09-28T08:07:47.000Z</time>
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"'<time>'yyyy-MM-dd'T'HH:mm:ss'Z</time>'"];
    
    return [dateFormatter stringFromDate:self.timestamp];
}

@end
