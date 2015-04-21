//
//  ViewController+Camera.h
//  SenseAV
//
//  Created by Nacho on 17/04/2015.
//  Copyright (c) 2015 Advance Analytics Institute. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#define HAS_LIBCXX
#import "ViewController.h"
#import <Structure/Structure.h>
#import <Structure/StructureSLAM.h>

//#import "MeshViewController.h"

@interface ViewController (Camera) <AVCaptureVideoDataOutputSampleBufferDelegate>

- (void) startColorCamera;
- (void) stopColorCamera;

@end
