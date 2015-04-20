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
    
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self startColorCamera];
    self.PopupMSGLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];

    [self.view bringSubviewToFront:self.PressMSGButton];
    //[self.view addSubview: self.PopupMSGLabel];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self stopColorCamera];
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

- (IBAction)ShowMSG:(UIButton *)sender
{
    [self showAppStatusMessage:@"Knocking on heaven door!"];
    [self hideAppStatusMessage];
    //[self.PopupMSGLabel setText:@"Knocking on heaven door!"];
}
@end
