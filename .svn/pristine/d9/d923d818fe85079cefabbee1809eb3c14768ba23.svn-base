//
//  ScanViewController.h
//  Ibeauty
//
//  Created by sean on 15/4/2.
//  Copyright (c) 2015年 sean. All rights reserved.
//

#import <UIKit/UIKit.h>
@class ScanViewController;

@protocol ScanViewDelegate <NSObject>

- (void)scanView:(ScanViewController *)controller didScanedCode:(NSString *)code;

@end

@interface ScanViewController : UIViewController

@property (weak, nonatomic) id<ScanViewDelegate> delegate;

@end
