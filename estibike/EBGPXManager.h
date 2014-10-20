//
//  EBGPXManager.h
//  estibike
//
//  Created by John Cieslik-Bridgen on 02/10/14.
//  Copyright (c) 2014 jcb1973. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EBGPXTrack.h"

@protocol EBGPXManagerDelegate <NSObject>

- (void) gpxManagerSentMessage:(NSString *)msg;

@end

@interface EBGPXManager : NSObject


@property (nonatomic, assign) id<EBGPXManagerDelegate> delegate;


+ (EBGPXManager *)sharedManager;

- (void) logGPXToFile:(EBGPXTrack *)track withUpload:(BOOL)doUpload;

@end
