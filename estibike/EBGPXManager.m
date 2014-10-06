//
//  EBGPXManager.m
//  estibike
//
//  Created by John Cieslik-Bridgen on 02/10/14.
//  Copyright (c) 2014 jcb1973. All rights reserved.
//

#import "EBGPXManager.h"
#import "EBBackgroundWorker.h"
#import "EBGPXTrack.h"
#import "FRDStravaClientImports.h"

#define STRAVA_APP_ID 1660
#define STRAVA_APP_SECRET @"7bc2f3a1a2e58f492f339d8b9f4e5b745fab9ce2"
#define STRAVA_OAUTH @"9727d907a025965a2d1bc526ace39ebe17623511"

#define DO_REAL_UPLOAD  YES

@implementation EBGPXManager

+ (EBGPXManager *)sharedManager {
    static EBGPXManager *GPXManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        GPXManager = [[self alloc] init];
    });
    return GPXManager;
}


- (void) logGPXToFile:(EBGPXTrack *)track withUpload:(BOOL)doUpload {
    NSLog(@"logGPXToFile:+");
    
    NSArray *directoryPaths = NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [directoryPaths objectAtIndex:0];
    NSLog(@"%@", documentsDirectoryPath);
    
    NSString *fileName = [NSString stringWithFormat:@"%@/%@_out.gpx",
                          documentsDirectoryPath,
                          [track getName]];
    
    if (!track.trackpoints.count > 0) {
        NSLog(@"logGPXToFile: nothing to write to file");
    } else {
    
        NSString *gpx = track.dumpGPX;
        NSError *error;
        BOOL ok = [gpx writeToFile:fileName
                        atomically:YES
                          encoding:NSUTF8StringEncoding
                             error:&error];
        
        if (!ok) {
            NSLog(@"Error writing file at %@\n%@",
                  documentsDirectoryPath, [error localizedFailureReason]);
        }
        NSURL* URL = [NSURL fileURLWithPath:fileName];
        
        if (doUpload) {
            [self uploadGPX:URL withName:track.name];
        }
        //self.track = nil;
        //
        NSLog(@"%@", gpx);
    }
    NSLog(@"logGPXToFile:-");
}

- (void) uploadGPX:(NSURL *)URL withName:(NSString *)name
{
    NSLog(@"uploadGPX:+");
    
    [[FRDStravaClient sharedInstance] initializeWithClientId:STRAVA_APP_ID
                                                clientSecret:STRAVA_APP_SECRET];
    [[FRDStravaClient sharedInstance] setAccessToken:STRAVA_OAUTH];
    
    if (DO_REAL_UPLOAD) {
        [[FRDStravaClient sharedInstance] uploadActivity:URL
                                                    name:name
                                            activityType:kUnknownType
                                                dataType:kUploadDataTypeGPX
                                                 private:NO
         
                                                 success:^(StravaActivityUploadStatus *uploadStatus) {
                                                     NSLog(@"upload sent");
                                                     NSLog(@"%@",[uploadStatus debugDescription]);
                                                     //self.debugLabel.text = [uploadStatus debugDescription];
                                                     //[self sendDebug:[uploadStatus debugDescription]];
                                                     UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Upload done"
                                                                                                  message:[uploadStatus debugDescription]
                                                                                                 delegate:nil
                                                                                        cancelButtonTitle:@"Ok"
                                                                                        otherButtonTitles: nil];
                                                     [av show];
                                                 }
         
                                                 failure:^(NSError *error) {
                                                     UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Upload failed"
                                                                                                  message:error.localizedDescription
                                                                                                 delegate:nil
                                                                                        cancelButtonTitle:@"Ok"
                                                                                        otherButtonTitles: nil];
                                                     [av show];
                                                 }];
    }
    NSLog(@"uploadGPX:-");
}

@end
