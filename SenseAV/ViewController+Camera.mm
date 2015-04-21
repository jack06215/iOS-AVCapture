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

#pragma mark - Camera Configuration

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
                         [self updateAppStatusMessage];
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
    
    //[self addAVPreviewLayer];
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

#pragma mark - Image Rendering Protocol

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    // Process the frame...(to be finished by YOU)
    [self renderColorFrame:sampleBuffer];
}


#pragma mark - Image Rendering

- (void)renderColorFrame:(CMSampleBufferRef)sampleBuffer
{
    // Get a image buffer that holding video frame
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // Lock the image buffer base address
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    // Obtain the image dimension
    size_t cols = CVPixelBufferGetWidth(pixelBuffer);
    size_t rows = CVPixelBufferGetHeight(pixelBuffer);
    
    // Create a RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Obtain the raw image data
    unsigned char *ptr = (unsigned char *) CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    
    
    // Create an NSData to store the image
    NSData *data = [[NSData alloc] initWithBytes:ptr length:rows*cols*4];
    
    // The image buffer can now be unlocked
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    // Create a bitmap information
    CGBitmapInfo bitmapInfo;
    bitmapInfo = (CGBitmapInfo)kCGImageAlphaNoneSkipFirst;
    bitmapInfo |= kCGBitmapByteOrder32Little;
    
    // Read the image
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);
    CGImageRef imageRef = CGImageCreate(cols,
                                        rows,
                                        8,
                                        8 * 4,
                                        cols*4,
                                        colorSpace,
                                        bitmapInfo,
                                        provider,
                                        NULL,
                                        false,
                                        kCGRenderingIntentDefault);
    
    // Feed the image data to our image viweer
    _colorImageView.image = [[UIImage alloc] initWithCGImage:imageRef];
    
    
    // Clean up stuff
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
}

#pragma mark - AVPreviewLayer

/* 
    (Not used in this program, just for didactic prupose)
    Image preview using an AVPreviewLayer.

*/
- (void)addAVPreviewLayer
{
    // AVPreviewLayer initialisation
    self.AVPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.AVCaptureSession];
    
    // Configure orientation of the prview window (Hard-coded horizontal in this case)
    // http://stackoverflow.com/questions/15075300/avcapturevideopreviewlayer-orientation-need-landscape
    self.AVPreviewLayer.transform =  CATransform3DMakeRotation(-M_PI/2, 0, 0, 1);
    
    // Configure the size of resolution of preview window
    self.AVPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.AVPreviewLayer.frame = self.view.bounds;
    
    // Finally, plug this AVPreviewLayer onto the screen.
    [self.view.layer addSublayer:self.AVPreviewLayer];
}

@end
