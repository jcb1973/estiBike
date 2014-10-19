//
//  EstibikeViewController.h
//  estibike
//
//  Created by John Cieslik-Bridgen on 29/09/14.
//  Copyright (c) 2014 jcb1973. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PSLocationManager.h"
#import <Foundation/Foundation.h>
#import "EBBackgroundWorker.h"
#import "EBGPXManager.h"

// I understand messages from ...
@interface EstibikeViewController : UIViewController  <EBBackgroundWorkerDelegate, EBGPXManagerDelegate>

@end
