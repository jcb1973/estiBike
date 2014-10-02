//
//  EBGPXManager.h
//  estibike
//
//  Created by John Cieslik-Bridgen on 02/10/14.
//  Copyright (c) 2014 jcb1973. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EBGPXTrack.h"

@interface EBGPXManager : NSObject

+ (EBGPXManager *)sharedManager;

- (void) logGPXToFile:(EBGPXTrack *)track;

@end
