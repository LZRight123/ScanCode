//
//  ViewController.m
//  ScanCode
//
//  Created by Right on 15/11/25.
//  Copyright © 2015年 Right. All rights reserved.
//

#import "ViewController.h"
#import "ScanViewController.h"
@interface ViewController ()<ScanViewDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)scanCode:(UIButton *)sender {
    ScanViewController *scanCode = [[ScanViewController alloc] init];
    scanCode.delegate = self;
    [self presentViewController:scanCode animated:YES completion:nil];
}
- (void)scanView:(ScanViewController *)controller didScanedCode:(NSString *)code{
    NSLog(@"%@",code);
}
@end
