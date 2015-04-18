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
    [self.view bringSubviewToFront:self.PressMSGButton];
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


- (IBAction)ShowMSG:(UIButton *)sender
{
    [self.view bringSubviewToFront:self.PopupMSGLabel];
    [self.PopupMSGLabel setText:@"Knocking on heaven door!"];
}
@end
