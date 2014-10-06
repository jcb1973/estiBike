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
        self.dateFormatter = [[NSDateFormatter alloc] init];
        [self.dateFormatter setDateFormat:@"'yyyy-MM-dd'T'HH:mm:ss'Z'"];
        
    }
    
    return self;
}

- (BOOL) addTrackpoint:(EBGPXTrackpoint *) point {
    
    [self.trackpoints addObject:point];
    return YES;
}

- (NSString*) getName {
    
    return [self.dateFormatter stringFromDate:self.createdAt];
}

- (NSString*) getGPXHeader {
    
    
    NSString *time = [self.dateFormatter stringFromDate:self.createdAt];
    
    return [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<gpx version=\"1.1\">\n<metadata><time>%@</time>\n</metadata>\n",
            time];
    
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
