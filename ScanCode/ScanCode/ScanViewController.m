//
//  ScanViewController.m
//  Ibeauty
//
//  Created by sean on 15/4/2.
//  Copyright (c) 2015年 sean. All rights reserved.
//

#import "ScanViewController.h"
#import <AVFoundation/AVFoundation.h>

#define Screen_Width [UIScreen mainScreen].bounds.size.width
#define Screen_Height [UIScreen mainScreen].bounds.size.height
#define Code_Size CGSizeMake((Screen_Width-60), (Screen_Width-60))
#define Corner_Width 20.f
#define Corner_Border_Width 2.f
#define Border_Width 0.5f

@interface ScanViewController () <AVCaptureMetadataOutputObjectsDelegate,UIAlertViewDelegate>
@property (nonatomic,strong) AVCaptureDevice * device;
@property (strong, nonatomic ) AVCaptureSession * session;
@property (strong, nonatomic ) AVCaptureVideoPreviewLayer * preview;
@property (strong, nonatomic) AVCaptureMetadataOutput *outPutView;
/**
 *  边框
 */
@property (strong, nonatomic) UIView *scanCropView;
/**
 *  扫描线
 */
@property (strong, nonatomic) UIView *line;
/**
 *  扫描区域
 */
@property (assign, nonatomic) CGRect readerViewFrame;
/**
 *  背景图
 */
@property (strong, nonatomic) UIView *backgroundView;
/**
 *  是二维码还是别的 比如条形码
 */
@property (assign, nonatomic) BOOL isQRCode;
/**
 *  是否打开闪光灯
 */
@property (assign, nonatomic) BOOL  isOpenFlashlight;
/**
 *  提示label
 */
@property (strong, nonatomic) UILabel *tiShiView;
/**
 *  二维码按钮
 */
@property (strong, nonatomic) UIButton *QRCodeBtn;
/**
 *  条形码码按钮
 */
@property (strong, nonatomic) UIButton *BarCodeBtn;
@end

@implementation ScanViewController {

    NSTimer *_lineTimer;
}
+ (BOOL) deviceCanUsingCamera {
    if (AVAuthorizationStatusAuthorized == [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]) {
        return YES;
    }
    return NO;
}
- (instancetype)init {

    self = [super init];

    if (self) {
        
        self.view.backgroundColor = [UIColor blackColor];
    }
    
    return self;
}

- (void)viewDidLoad {
    
    [super viewDidLoad];

    self.title = @"扫描二维码";
    
    if(![ScanViewController deviceCanUsingCamera]){
        UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"未获得授权使用摄像头" message:@"请在iOS\"设置\"-\"隐私\"-\"相机\"中打开" delegate:self cancelButtonTitle:@"知道了" otherButtonTitles:nil];
        [alert show];
    }

    // 给以后的视图设置frame；
    self.readerViewFrame = CGRectMake((Screen_Width - Code_Size.width) / 2,(Screen_Height - Code_Size.height) / 2-30, Code_Size.width, Code_Size.height);
    [self initUI];
    [self setOverlayView];
    [self startLineScanning];
}
#pragma mark - alert代理
- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    [self dismissViewControllerAnimated:YES completion:nil];
}
#pragma mark - Private Method

- (void)initUI {
    //init
    self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    //input
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:nil];
    //output
//    AVCaptureMetadataOutput *output = [[AVCaptureMetadataOutput alloc] init];
    self.outPutView = [[AVCaptureMetadataOutput alloc] init];
    [self.outPutView setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    [self.outPutView setRectOfInterest:[self setReaderViewSize]];
    //session
    _session = [[AVCaptureSession alloc] init];
    [_session setSessionPreset:AVCaptureSessionPresetHigh];
    if ([_session canAddInput:input]) {
        
        [_session addInput:input];
    }
    if ([_session canAddOutput:self.outPutView]) {
        
        [_session addOutput:self.outPutView];
    }
    
    // 设备情况
    if (!TARGET_IPHONE_SIMULATOR){
        //条码类型
        self.outPutView.metadataObjectTypes = @[AVMetadataObjectTypeQRCode,AVMetadataObjectTypeCode39Code,AVMetadataObjectTypeCode128Code,AVMetadataObjectTypeCode39Mod43Code,AVMetadataObjectTypeEAN13Code,AVMetadataObjectTypeEAN8Code,AVMetadataObjectTypeCode93Code];
    }
   
    
    
    //preview
    _preview = [AVCaptureVideoPreviewLayer layerWithSession:_session];
    _preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
    _preview.frame = self.view.layer.bounds;
    [self.view.layer insertSublayer:_preview above:0];
}
/**
 *  读取框的frame
 */
- (CGRect)setReaderViewSize {
    return CGRectMake(self.readerViewFrame.origin.y/Screen_Height, self.readerViewFrame.origin.x/Screen_Width,Code_Size.height / Screen_Height, Code_Size.width / Screen_Width);
}
-(void) setReaderViewFrame:(CGRect)readerViewFrame{
    _readerViewFrame = readerViewFrame;
    [self.view.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self setOverlayView];
    [self.outPutView setRectOfInterest:[self setReaderViewSize]];

}
- (void)setOverlayView {
    //背景
    UIView *shadowView = [[UIView alloc] initWithFrame:self.view.bounds];
    shadowView.backgroundColor = [UIColor colorWithWhite:0.f alpha:.7f];
    self.backgroundView = shadowView;
    [self setupCustomView];
    [self.view addSubview:shadowView];
    
    
    //读取二维码区域
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:shadowView.bounds];
    [path appendPath:[[UIBezierPath bezierPathWithRect:self.readerViewFrame] bezierPathByReversingPath]];
    CAShapeLayer *shapeLayer = [CAShapeLayer layer];
    shapeLayer.backgroundColor = [UIColor redColor].CGColor;
    shapeLayer.path = path.CGPath;
    [shadowView.layer setMask:shapeLayer];
    
    /**
      * self.readerViewFrame 的坐标
     */
    CGFloat x = self.readerViewFrame.origin.x;
    CGFloat y = self.readerViewFrame.origin.y;
    CGFloat w = self.readerViewFrame.size.width;
    CGFloat h = self.readerViewFrame.size.height;
    
    //基准线
    _line = [[UIView alloc] initWithFrame:CGRectMake(x ,y, w, 1.5)];
    _line.backgroundColor = [UIColor redColor];
    [self.view addSubview:_line];
    
    //边框
    _scanCropView = [[UIView alloc] initWithFrame:CGRectMake(x - Border_Width,y - Border_Width,w + Border_Width * 2, h + Border_Width * 2)];
    _scanCropView.layer.borderColor = [UIColor whiteColor].CGColor;
    _scanCropView.layer.borderWidth = Border_Width;
    [shadowView addSubview:_scanCropView];

    //四个角
    //左上
    UIBezierPath *topLeftCornerPath = [UIBezierPath new];
    CAShapeLayer *topLeftLayer = [CAShapeLayer new];
    [self setCornerBorder:topLeftLayer];
    [topLeftCornerPath moveToPoint:CGPointMake(0, Corner_Width)];
    [topLeftCornerPath addLineToPoint:CGPointMake(0, 0)];
    [topLeftCornerPath addLineToPoint:CGPointMake(Corner_Width, 0)];
    topLeftLayer.path = topLeftCornerPath.CGPath;
    [self setCorderBounds:topLeftLayer];
    CGPoint point = CGPointMake(Corner_Width / 2 - Border_Width - Border_Width, Corner_Width / 2 - Corner_Border_Width / 2);
    topLeftLayer.position = point;
    [_scanCropView.layer addSublayer:topLeftLayer];

    //右上
    UIBezierPath *topRightCornerPath = [UIBezierPath new];
    CAShapeLayer *topRightLayer = [CAShapeLayer new];
    [self setCornerBorder:topRightLayer];
    [topRightCornerPath moveToPoint:CGPointMake(0, 0)];
    [topRightCornerPath addLineToPoint:CGPointMake(Corner_Width, 0)];
    [topRightCornerPath addLineToPoint:CGPointMake(Corner_Width, Corner_Width)];
    topRightLayer.path = topRightCornerPath.CGPath;
    [self setCorderBounds:topRightLayer];
    point = CGPointMake(_scanCropView.frame.size.width - Corner_Width / 2 + Corner_Border_Width / 2, Corner_Width / 2 - Corner_Border_Width / 2);
    topRightLayer.position = point;
    [_scanCropView.layer addSublayer:topRightLayer];
    
    //左下
    UIBezierPath *bottomLeftCornerPath = [UIBezierPath new];
    CAShapeLayer *bottomLeftLayer = [CAShapeLayer new];
    [self setCornerBorder:bottomLeftLayer];
    [bottomLeftCornerPath moveToPoint:CGPointMake(0, 0)];
    [bottomLeftCornerPath addLineToPoint:CGPointMake(0, Corner_Width)];
    [bottomLeftCornerPath addLineToPoint:CGPointMake(Corner_Width, Corner_Width)];
    bottomLeftLayer.path = bottomLeftCornerPath.CGPath;
    [self setCorderBounds:bottomLeftLayer];
    point = CGPointMake(Corner_Width / 2 - Border_Width - Border_Width, _scanCropView.frame.size.height - Corner_Width / 2 + Corner_Border_Width / 2);
    bottomLeftLayer.position = point;
    [_scanCropView.layer addSublayer:bottomLeftLayer];
    
    //右下
    UIBezierPath *bottomRightCornerPath = [UIBezierPath new];
    CAShapeLayer *bottomRightLayer = [CAShapeLayer new];
    [self setCornerBorder:bottomRightLayer];
    [bottomRightCornerPath moveToPoint:CGPointMake(Corner_Width, 0)];
    [bottomRightCornerPath addLineToPoint:CGPointMake(Corner_Width, Corner_Width)];
    [bottomRightCornerPath addLineToPoint:CGPointMake(0, Corner_Width)];
    bottomRightLayer.path = bottomRightCornerPath.CGPath;
    [self setCorderBounds:bottomRightLayer];
    point = CGPointMake(_scanCropView.frame.size.width - Corner_Width / 2 + Corner_Border_Width / 2, _scanCropView.frame.size.height - Corner_Width / 2 + Corner_Border_Width / 2);
    bottomRightLayer.position = point;
    [_scanCropView.layer addSublayer:bottomRightLayer];
    
    
    //说明label
    UILabel *labIntroudction = [[UILabel alloc] init];
    labIntroudction.backgroundColor = [UIColor clearColor];
    labIntroudction.frame = CGRectMake(_scanCropView.frame.origin.x, CGRectGetMaxY(_scanCropView.frame)+ 30.f, _scanCropView.frame.size.width, 20.f);
    labIntroudction.textAlignment = NSTextAlignmentCenter;
    labIntroudction.font = [UIFont boldSystemFontOfSize:16.0];
    labIntroudction.textColor = [UIColor whiteColor];
    labIntroudction.text = @"将二维码置于框内,即可自动扫描";
    [self.view addSubview:labIntroudction];
    self.tiShiView = labIntroudction;
}

- (void)setCorderBounds:(CAShapeLayer *)layer {

    CGPathRef bound = CGPathCreateCopyByStrokingPath(layer.path, nil, layer.lineWidth, kCGLineCapButt, kCGLineJoinMiter, layer.miterLimit);
    layer.bounds = CGPathGetBoundingBox(bound);
    CGPathRelease(bound);
}

- (void)setCornerBorder:(CAShapeLayer *)layer {
    
    layer.lineWidth = Corner_Border_Width;
    layer.strokeColor = [UIColor greenColor].CGColor;
    layer.fillColor = [UIColor clearColor].CGColor;
}

#pragma mark - Actions

- (void)startLineScanning {

    _lineTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f / 20 target:self selector:@selector(animationLine) userInfo:nil repeats:YES];
    
    [_session startRunning];
}

- (void)stopLineScanning {

    if (_lineTimer)
    {
        [_lineTimer invalidate];
        _lineTimer = nil;
    }
    
    [_session stopRunning];
}

#pragma mark - Private Method

- (void)createGradient:(UIView *)view {

    //TODO
}

static BOOL flag = YES;

- (void)animationLine {

    __block CGRect frame = _line.frame;
    
    if (flag)
    {
        frame.origin.y = _scanCropView.frame.origin.y;
        flag = NO;
        
        [UIView animateWithDuration:1.0 / 20 animations:^{
            
            frame.origin.y += 5;
            _line.frame = frame;
            
        } completion:nil];
    }
    else
    {
        if (_line.frame.origin.y >= _scanCropView.frame.origin.y)
        {
            if (_line.frame.origin.y >= _scanCropView.frame.origin.y + _scanCropView.frame.size.height - _line.frame.size.height)
            {
                frame.origin.y = _scanCropView.frame.origin.y;
                _line.frame = frame;
                
                flag = YES;
            }
            else
            {
                [UIView animateWithDuration:1.0 / 20 animations:^{
                    
                    frame.origin.y += 5;
                    _line.frame = frame;
                    
                } completion:nil];
            }
        }
        else
        {
            flag = !flag;
        }
    }
}
-(BOOL) prefersStatusBarHidden{
    return YES;
}
#pragma mark - AVCaptureMetadataOutputObjectsDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {

    NSString *stringValue;
    if (metadataObjects.count > 0 )
    {
        // 停止扫描
        [self stopLineScanning];
        AVMetadataMachineReadableCodeObject * metadataObject = [metadataObjects objectAtIndex:0];
        NSArray *stringArray = [metadataObject.stringValue componentsSeparatedByString:@","];
        stringValue = [stringArray lastObject];
        NSLog(@"%@",metadataObject);
        [self dismissViewControllerAnimated:YES completion:nil];
        if ([self.delegate respondsToSelector:@selector(scanView:didScanedCode:)]) {
             [self.delegate scanView:self didScanedCode:stringValue];
        }
       
    }
}
#pragma mark  自定义图层
-(void) setupCustomView{
    CGRect frame = self.backgroundView.frame;
//    self.backgroundView  注意尺寸即可
    //1...返回键
    UIButton  *backBtn = [[UIButton alloc]initWithFrame:CGRectMake(30, 25, 35, 35)];
    [backBtn setBackgroundImage:[UIImage imageNamed:@"01"] forState:UIControlStateNormal];
    [backBtn addTarget:self action:@selector(clickBackBtn) forControlEvents:UIControlEventTouchUpInside];
    [self.backgroundView addSubview:backBtn];
    
    //2....手电筒 🔦
    UIButton  *flashlightBtn = [[UIButton alloc]initWithFrame:CGRectMake(frame.size.width - 35 -30, 25, 35, 35)];
    [flashlightBtn setBackgroundImage:[UIImage imageNamed:@"03"] forState:UIControlStateNormal];
    [flashlightBtn addTarget:self action:@selector(clickFlashlightBtn) forControlEvents:UIControlEventTouchUpInside];
    [self.backgroundView addSubview:flashlightBtn];
    
    //工具条背景
    UIView *toolBar = [[UIView alloc] initWithFrame:CGRectMake(frame.origin.x, frame.size.height - 54, frame.size.width, 54)];
    toolBar.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.7];
    
    UIButton *btn = [[UIButton alloc]initWithFrame:CGRectMake(0, 0, 45, 45)];
    [btn setBackgroundImage:[UIImage imageNamed:@"3"] forState:UIControlStateNormal];
    [btn setBackgroundImage:[UIImage imageNamed:@"3-1"] forState:UIControlStateSelected];
    btn.selected = YES;
    btn.center = CGPointMake((frame.size.width*0.5-45)*0.5, CGRectGetHeight(toolBar.frame)*0.5);
    [btn addTarget:self action:@selector(QRCodeFrameTransform:) forControlEvents:UIControlEventTouchUpInside];
    [toolBar addSubview:btn];
    self.QRCodeBtn = btn;
    
    UIButton *btn2 = [[UIButton alloc]initWithFrame:CGRectMake(0, 0, 45, 45)];
    [btn2 setBackgroundImage:[UIImage imageNamed:@"02"] forState:UIControlStateNormal];
    [btn2 setBackgroundImage:[UIImage imageNamed:@"02-1"] forState:UIControlStateSelected];
    btn2.center = CGPointMake((frame.size.width*0.5+45+frame.size.width)*0.5, CGRectGetHeight(toolBar.frame)*0.5);
    [btn2 addTarget:self action:@selector(barCodeFrameTransform:) forControlEvents:UIControlEventTouchUpInside];
    [toolBar addSubview:btn2];
    self.BarCodeBtn = btn2;
    
//    [self.backgroundView addSubview:toolBar];
    
}
/**
 *  点击返回按钮
 */
-(void) clickBackBtn{
    [self dismissViewControllerAnimated:YES completion:nil];
    [self stopFlashlight];
}
/**
 *  手电筒 🔦
 */
-(void) clickFlashlightBtn{
    if (!self.isOpenFlashlight) { //开闪光灯
        self.isOpenFlashlight = YES;
        if([self.device hasTorch] && [self.device hasFlash])
        {
            if(self.device.torchMode == AVCaptureTorchModeOff)
            {
                [self.session beginConfiguration];
                [self.device lockForConfiguration:nil];
                [self.device setTorchMode:AVCaptureTorchModeOn];
                [self.device setFlashMode:AVCaptureFlashModeOn];
                [self.device unlockForConfiguration];
                [self.session commitConfiguration];
            }
        }
        [self.session startRunning];
    }else{
        [self stopFlashlight];
//        [self.session stopRunning];
      
    }
}
-(void) stopFlashlight{
    self.isOpenFlashlight = NO;
    [self.session beginConfiguration];
    [self.device lockForConfiguration:nil];
    if(self.device.torchMode == AVCaptureTorchModeOn)
    {
        [self.device setTorchMode:AVCaptureTorchModeOff];
        [self.device setFlashMode:AVCaptureFlashModeOff];
    }
    [self.device unlockForConfiguration];
    [self.session commitConfiguration];
}
-(void) QRCodeFrameTransform:(UIButton*)sender{
   
    self.readerViewFrame = CGRectMake((Screen_Width - Code_Size.width) / 2,(Screen_Height - Code_Size.height) / 2-30, Code_Size.width, Code_Size.height);
    self.tiShiView.text = @"将二维码置于框内,即可自动扫描";
    self.QRCodeBtn.selected = YES;
    self.BarCodeBtn.selected = NO;
//    if (!self.isQRCode) {
//        self.isQRCode = YES;
//        self.QRCodeBtn.selected = NO;
//         CGFloat scale = 0.6;
//        self.readerViewFrame = CGRectMake((Screen_Width - Code_Size.width) / 2,(Screen_Height - Code_Size.height*scale) / 2  , Code_Size.width, Code_Size.height*scale);
//        self.tiShiView.text = @"将条形码置于框内,即可自动扫描";
//    }else{
//        self.isQRCode = NO;
//        self.BarCodeBtn.selected = YES;
//        
//        self.readerViewFrame = CGRectMake((Screen_Width - Code_Size.width) / 2,(Screen_Height - Code_Size.height) / 2-30, Code_Size.width, Code_Size.height);
//        self.tiShiView.text = @"将二维码置于框内,即可自动扫描";
//    }
}
-(void) barCodeFrameTransform:(UIButton*)sender{
 
    CGFloat scale = 0.6;
    self.readerViewFrame = CGRectMake((Screen_Width - Code_Size.width) / 2,(Screen_Height - Code_Size.height*scale) / 2  , Code_Size.width, Code_Size.height*scale);
    self.tiShiView.text = @"将条形码置于框内,即可自动扫描";
    
    self.QRCodeBtn.selected = NO;
    self.BarCodeBtn.selected = YES;
}
@end
