//
//  ViewController.h
//  SenseAV
//
//  Created by Nacho on 17/04/2015.
//  Copyright (c) 2015 Advance Analytics Institute. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#define HAS_LIBCXX
#import <Structure/Structure.h>

//#import "CalibrationOverlay.h"
//#import "MeshViewController.h"



struct AppStatus
{
    NSString* const pleaseConnectSensorMessage = @"Please connect Structure Sensor.";
    NSString* const pleaseChargeSensorMessage = @"Please charge Structure Sensor.";
    NSString* const needColorCameraAccessMessage = @"This app requires camera access to capture color.";
    enum SensorStatus
    {
        SensorStatusOk,
        SensorStatusNeedsUserToConnect,
        SensorStatusNeedsUserToCharge,
    };
    
    // Structure Sensor status.
    SensorStatus sensorStatus = SensorStatusOk;
    
    // Whether iOS camera access was granted by the user.
    bool colorCameraIsAuthorized = true;
    
    // Whether there is currently a message to show.
    bool needsDisplayOfStatusMessage = false;
    
    // Flag to disable entirely status message display.
    bool statusMessageDisabled = false;
};



@interface ViewController : UIViewController
{
    // Manages the app status messages.
    AppStatus _appStatus;
}
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *AVPreviewLayer;
@property (nonatomic, strong) AVCaptureSession *AVCaptureSession;
@property (nonatomic, strong) AVCaptureDevice *AVDevice;
@property (weak, nonatomic) IBOutlet UIButton *PressMSGButton;
@property (weak, nonatomic) IBOutlet UILabel *PopupMSGLabel;
- (IBAction)ShowMSG:(UIButton *)sender;

@end

