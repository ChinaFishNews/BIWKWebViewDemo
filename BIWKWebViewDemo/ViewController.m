//
//  ViewController.m
//  BIWKWebViewDemo
//
//  Created by xinwen on 2019/1/21.
//  Copyright © 2019年 baidu. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"html"];
    [self.wkWebView loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath: path]]];
}

// oc调用js无参
- (IBAction)ocCallJsNoParams:(id)sender {
//    [self.wkWebView callJSFunction:@"ocCallJsNoParamsFunction" arguments:@[] complete:^(id  _Nullable returnValue, NSError * _Nullable error) {
//        NSLog(@"error=%@",error);
//    }];
//    [self.wkWebView evaluateJavaScript:[NSString stringWithFormat:@"%@();", @"ocCallJsNoParamsFunction"] completionHandler:nil];
    NSString *js = [NSString stringWithFormat:@"ocCallJsNoParamsFunction();"];
    [self.wkWebView evaluateScript:js complete:^(id  _Nullable returnValue, NSError * _Nullable error) {
        NSLog(@"returnValue=%@",returnValue);
        NSLog(@"error=%@",error);
    }];
}

// oc调用js有参
- (IBAction)ocCallJsHasParams:(id)sender {
    NSString *js = [NSString stringWithFormat:@"ocCallJsHasParamsFunction('%@','%@');",@"这是",@"http://www.baidu.com"];
    [self.wkWebView evaluateJavaScript:js completionHandler:^(id _Nullable returnValue , NSError * _Nullable error) {
            NSLog(@"error=%@",error);
    }];
//    [self.wkWebView evaluateJavaScript:js complete:^(id  _Nullable returnValue, NSError * _Nullable error) {
//        NSLog(@"returnValue=%@",returnValue);
//        NSLog(@"error=%@",error);
//    }];
}


@end
