//
//  ViewController.m
//  SenseAV
//
//  Created by Nacho on 17/04/2015.
//  Copyright (c) 2015 Advance Analytics Institute. All rights reserved.
//

#import "ViewController.h"
#import "ViewController+Camera.h"

@implementation ViewController

#pragma mark - UI Interface Configuration

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    
    // Set up a windows for image rendering
    CGRect colorFrame = self.view.frame;
    colorFrame.size.height = self.view.frame.size.height;
    colorFrame.size.width = self.view.frame.size.width;
    _colorImageView = [[UIImageView alloc] initWithFrame:colorFrame];
    _colorImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.view addSubview:_colorImageView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.view bringSubviewToFront:self.PressMSGButton];
    static BOOL fromLaunch = true;
    if(fromLaunch)
    {
        
        // Create a UILabel in the center of our view to display status messages

        //self.PopupMSGLabel = [[UILabel alloc] initWithFrame:self.view.bounds];
        self.PopupMSGLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
        self.PopupMSGLabel.textAlignment = NSTextAlignmentCenter;
        self.PopupMSGLabel.font = [UIFont systemFontOfSize:35.0];
        self.PopupMSGLabel.numberOfLines = 2;
        self.PopupMSGLabel.textColor = [UIColor whiteColor];
        // [self updateAppStatusMessage];
        [self.view addSubview: self.PopupMSGLabel];
        [self startColorCamera];
        fromLaunch = false;
        
        // From now on, make sure we get notified when the app becomes active to restore the state if necessary.
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appDidBecomeActive)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self stopColorCamera];
}

- (void)appDidBecomeActive
{
    // Start Running the main system
    [self startColorCamera];
}

# pragma mark - Screen Orientation
- (NSUInteger) supportedInterfaceOrientations
{
    // Return a bitmask of supported orientations. If you need more,
    // use bitwise or (see the commented return).
    return UIInterfaceOrientationMaskLandscapeRight;
}

- (UIInterfaceOrientation) preferredInterfaceOrientationForPresentation
{
    // Return the orientation you'd prefer - this is what it launches to. The
    // user can still rotate. You don't have to implement this method, in which
    // case it launches in the current orientation
    return UIInterfaceOrientationLandscapeRight;
}

#pragma mark - Pop up message overlay
- (void)showAppStatusMessage:(NSString *)msg
{
    _appStatus.needsDisplayOfStatusMessage = true;
    [self.view.layer removeAllAnimations];
    
    [self.PopupMSGLabel setText:msg];
    [self.PopupMSGLabel setHidden:NO];
    
    // Progressively show the message label.
    [self.view setUserInteractionEnabled:false];
    [self.view bringSubviewToFront:self.PopupMSGLabel];
    //
    [UIView animateWithDuration:0.5f
                     animations:^()
     {
         self.PopupMSGLabel.alpha = 1.0f;
         //self.PopupMSGLabel.backgroundColor = 0.7f;
     }
                     completion:nil
     ];
}

- (void)hideAppStatusMessage
{
    
    _appStatus.needsDisplayOfStatusMessage = false;
    [self.view.layer removeAllAnimations];
    
    [UIView animateWithDuration:0.5f
                     animations:^()
     {
         self.PopupMSGLabel.alpha = 0.0f;
     }
                     completion:^(BOOL finished)
     {
         // If nobody called showAppStatusMessage before the end of the animation, do not hide it.
         if (!_appStatus.needsDisplayOfStatusMessage)
         {
             [self.PopupMSGLabel setHidden:YES];
             [self.view setUserInteractionEnabled:true];
             [self.view sendSubviewToBack:self.PopupMSGLabel];
         }
     }];
}

-(void)updateAppStatusMessage
{
    // Skip everything if we should not show app status messages (e.g. in viewing state).
    /*if (_appStatus.statusMessageDisabled)
    {
        [self hideAppStatusMessage];
        return;
    }*/
    
    // First show sensor issues, if any.
    switch (_appStatus.sensorStatus)
    {
        case AppStatus::SensorStatusOk:
        {
            break;
        }
            
        case AppStatus::SensorStatusNeedsUserToConnect:
        {
            [self showAppStatusMessage:_appStatus.pleaseConnectSensorMessage];
            return;
        }
            
        case AppStatus::SensorStatusNeedsUserToCharge:
        {
            //[self showAppStatusMessage:_appStatus.pleaseChargeSensorMessage];
            [self showAppStatusMessage:@"Knocking on heaven door!"];
            //return;
        }
    }
    
    // Then show color camera permission issues, if any.
    if (!_appStatus.colorCameraIsAuthorized)
    {
        [self showAppStatusMessage:_appStatus.needColorCameraAccessMessage];
        return;
    }
    // If we reach this point, no status to show.
    [self hideAppStatusMessage];
}

#pragma mark - IBAction handller
- (IBAction)ShowMSG:(UIButton *)sender
{
    [self updateAppStatusMessage];
}
@end
