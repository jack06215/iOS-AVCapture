//
//  ViewController+Camera.m
//  SenseAV
//
//  Created by Nacho on 17/04/2015.
//  Copyright (c) 2015 Advance Analytics Institute. All rights reserved.
//

#import "ViewController.h"
#import "ViewController+Camera.h"

#import <Structure/Structure.h>
#import <Structure/StructureSLAM.h>

#import <objc/runtime.h>

@implementation ViewController (Camera) 

-(void)avCaptureSessionDidStartRunning:(NSNotification*)notification
{
    // We lock the focus as soon as possible we can to make it as close as possible to infinity.
    // This is necessary on iOS7 since we cannot manually lock the focus at infinity, but on iOS8
    // we can use setFocusModeLockedWithLensPosition.
    if (notification.name == AVCaptureSessionDidStartRunningNotification)
    {
        NSError * error;
        if([self.AVDevice lockForConfiguration:&error]) {
            
            if ([self.AVDevice isFocusModeSupported:AVCaptureFocusModeLocked])
                self.AVDevice.focusMode = (AVCaptureFocusMode)AVCaptureFocusModeLocked;
            
            [self.AVDevice unlockForConfiguration];
        }
    }
}

- (BOOL)queryCameraAuthorizationStatusAndNotifyUserIfNotGranted
{
    // This API was introduced in iOS 7, but in iOS 8 it's actually enforced.
    if ([AVCaptureDevice respondsToSelector:@selector(authorizationStatusForMediaType:)])
    {
        AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        
        if (authStatus != AVAuthorizationStatusAuthorized)
        {
            NSLog(@"Not authorized to use the camera!");
            
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo
                                     completionHandler:^(BOOL granted)
             {
                 // This block fires on a separate thread, so we need to ensure any actions here
                 // are sent to the right place.
                 
                 // If the request is granted, let's try again to start an AVFoundation session.
                 // Otherwise, alert the user that things won't go well.
                 if (granted)
                 {
                     dispatch_async(dispatch_get_main_queue(), ^(void)
                     {
                         
                         [self startColorCamera];
                         _appStatus.colorCameraIsAuthorized = true;
                     });
                 }
             }];
            
            return false;
        }
    }
    return true;
}

- (void)setUpCaptureSession
{
    // If already setup, skip it
    if (self.AVCaptureSession)
        return;
    
    bool cameraAccessAuthorized = [self queryCameraAuthorizationStatusAndNotifyUserIfNotGranted];
    
    if (!cameraAccessAuthorized)
    {
        _appStatus.colorCameraIsAuthorized = false;
        //[self updateAppStatusMessage];
        return;
    }
    
    // Use VGA color.
    NSString *sessionPreset = AVCaptureSessionPreset640x480;
    
    // Set up Capture Session.
    self.AVCaptureSession = [[AVCaptureSession alloc] init];
    [self.AVCaptureSession beginConfiguration];
    
    // Set preset session size.
    [self.AVCaptureSession setSessionPreset:sessionPreset];
    
    // Create a video device and input from that Device.  Add the input to the capture session.
    self.AVDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (self.AVDevice == nil)
        assert(0);
    
    // Configure Focus, Exposure, and White Balance
    NSError *error;
    
    // iOS8 supports manual focus at near-infinity, but iOS7 doesn't.
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
    bool avCaptureSupportsFocusNearInfinity = [self.AVDevice respondsToSelector:@selector(setFocusModeLockedWithLensPosition:completionHandler:)];
#else
    bool avCaptureSupportsFocusNearInfinity = false;
#endif
    
    // Use auto-exposure, and auto-white balance and set the focus to infinity.
    if([self.AVDevice lockForConfiguration:&error])
    {
        
        // Allow exposure to change
        if ([self.AVDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure])
            [self.AVDevice setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
        
        // Allow white balance to change
        if ([self.AVDevice isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance])
            [self.AVDevice setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
        
        if (avCaptureSupportsFocusNearInfinity)
        {
            // Set focus at the maximum position allowable (e.g. "near-infinity") to get the
            // best color/depth alignment.
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
            [self.AVDevice setFocusModeLockedWithLensPosition:1.0f completionHandler:nil];
#endif
        }
        else
        {
            
            // Allow the focus to vary, but restrict the focus to far away subject matter
            if ([self.AVDevice isAutoFocusRangeRestrictionSupported])
                [self.AVDevice setAutoFocusRangeRestriction:AVCaptureAutoFocusRangeRestrictionFar];
            
            if ([self.AVDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus])
                [self.AVDevice setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
            
        }
        
        [self.AVDevice unlockForConfiguration];
    }
    
    //  Add the device to the session.
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:self.AVDevice error:&error];
    if (error)
    {
        NSLog(@"Cannot initialize AVCaptureDeviceInput");
        assert(0);
    }
    
    [self.AVCaptureSession addInput:input]; // After this point, captureSession captureOptions are filled.
    
    //  Create the output for the capture session.
    AVCaptureVideoDataOutput* dataOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    // We don't want to process late frames.
    [dataOutput setAlwaysDiscardsLateVideoFrames:YES];
    
    // Use BGRA pixel format.
    [dataOutput setVideoSettings:[NSDictionary
                                  dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                                  forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    
    // Set dispatch to be on the main thread so OpenGL can do things with the data
    [dataOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    [self.AVCaptureSession addOutput:dataOutput];
    
    // Force the framerate to 30 FPS, to be in sync with Structure Sensor.
    if ([self.AVDevice respondsToSelector:@selector(setActiveVideoMaxFrameDuration:)]
        && [self.AVDevice respondsToSelector:@selector(setActiveVideoMinFrameDuration:)])
    {
        // Available since iOS 7.
        if([self.AVDevice lockForConfiguration:&error])
        {
            [self.AVDevice setActiveVideoMaxFrameDuration:CMTimeMake(1, 30)];
            [self.AVDevice setActiveVideoMinFrameDuration:CMTimeMake(1, 30)];
            [self.AVDevice unlockForConfiguration];
        }
    }
    else
    {
        NSLog(@"iOS 7 or higher is required. Camera not properly configured.");
        return;
    }
    
    
    self.AVPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.AVCaptureSession];
    //NSString *sessionPreset = AVCaptureSessionPresetPhoto;
    //[self.AVCaptureSession setSessionPreset:sessionPreset];
    self.AVPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.AVPreviewLayer.frame = self.view.bounds;
    
    self.AVPreviewLayer.transform =  CATransform3DMakeRotation(-M_PI/2, 0, 0, 1); // Hard-code orientation
    
    self.AVPreviewLayer.frame = CGRectMake(0.0, 0.0, self.view.frame.size.width, self.view.frame.size.height);
    [self.view.layer addSublayer:self.AVPreviewLayer];
    
    [self.AVCaptureSession commitConfiguration];

}

- (void)startColorCamera
{
    if (self.AVCaptureSession && [self.AVCaptureSession isRunning])
        return;
    
    // Re-setup so focus is lock even when back from background
    if (self.AVCaptureSession == nil)
        [self setUpCaptureSession];
    
    // Start streaming color images.
    [self.AVCaptureSession startRunning];
}

- (void)stopColorCamera
{
    if ([self.AVCaptureSession isRunning])
    {
        // Stop the session
        [self.AVCaptureSession stopRunning];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVCaptureSessionDidStartRunningNotification
                                                  object:self.AVCaptureSession];
    
    self.AVCaptureSession = nil;
    self.AVDevice = nil;
}

- (void)setColorCameraParametersForInit
{
    NSError *error;
    
    [self.AVDevice lockForConfiguration:&error];
    
    // Auto-exposure
    if ([self.AVDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure])
        [self.AVDevice setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
    
    // Auto-white balance.
    if ([self.AVDevice isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance])
        [self.AVDevice setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
    
    [self.AVDevice unlockForConfiguration];
    
}

- (void)setColorCameraParametersForRecording
{
    NSError *error;
    
    [self.AVDevice lockForConfiguration:&error];
    
    // Exposure locked to its current value.
    if([self.AVDevice isExposureModeSupported:AVCaptureExposureModeLocked])
        [self.AVDevice setExposureMode:AVCaptureExposureModeLocked];
    
    // White balance locked to its current value.
    if([self.AVDevice isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeLocked])
        [self.AVDevice setWhiteBalanceMode:AVCaptureWhiteBalanceModeLocked];
    
    [self.AVDevice unlockForConfiguration];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    // Process the frame...(to be finished by YOU)
}


@end
