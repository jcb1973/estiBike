//
//  EBGPXTrack.m
//  estibike
//
//  Created by John Cieslik-Bridgen on 30/09/14.
//  Copyright (c) 2014 jcb1973. All rights reserved.
//

#import "EBGPXTrack.h"

@implementation EBGPXTrack

- (instancetype) initWithName:(NSString *)name {
    
    self = [super init];
    
    if (self) {
        self.name = name;
        self.createdAt = [NSDate date];
        self.trackpoints = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (BOOL) addTrackpoint:(EBGPXTrackpoint *) point {
    
    [self.trackpoints addObject:point];
    return YES;
}

- (NSString*) getGPXHeader {
    
    
//    <?xml version="1.0" encoding="UTF-8"?>
//    <gpx version="1.1" creator="Garmin Connect"
//xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd http://www.garmin.com/xmlschemas/GpxExtensions/v3 http://www.garmin.com/xmlschemas/GpxExtensionsv3.xsd http://www.garmin.com/xmlschemas/TrackPointExtension/v1 http://www.garmin.com/xmlschemas/TrackPointExtensionv1.xsd"
//    xmlns="http://www.topografix.com/GPX/1/1"
//xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1"
//xmlns:gpxx="http://www.garmin.com/xmlschemas/GpxExtensions/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
//    <metadata>
//    <link href="connect.garmin.com">
//    <text>Garmin Connect</text>
//    </link>
//    <time>2014-09-28T08:07:47.000Z</time>
//    </metadata>
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"'<time>'yyyy-MM-dd'T'HH:mm:ss'Z</time>'"];
    NSString *time = [dateFormatter stringFromDate:self.createdAt];
    
    return [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<gpx version=\"1.1\">\n<metadata><time>%@</time>\n</metadata>\n", time];
    
}

- (NSString*) dumpGPX {
    
    NSMutableString* s = [NSMutableString string];
    [s appendString:[self getGPXHeader]];
    [s appendString:@"<trk>\n"];
    [s appendString:[NSString stringWithFormat:@"<name>%@</name>\n<trkseg>\n", self.name]];
    
    [self.trackpoints sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES]]];
    
    for (EBGPXTrackpoint *trackpoint in self.trackpoints) {
        [s appendString:trackpoint.printGPX];
    }
    
    [s appendString:@"</trkseg>\n</trk>\n</gpx>"];
    return [NSString stringWithString:s];
}

@end
