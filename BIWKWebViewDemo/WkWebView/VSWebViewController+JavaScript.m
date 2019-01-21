//
//  VSWebViewController+JavaScript.m
//  Venus
//
//  Created by wanghouwen on 2017/12/15.
//  Copyright © 2017年 wanghouwen. All rights reserved.
//

#import "VSWebViewController+JavaScript.h"

@implementation VSWebViewController (JavaScript)

// 注入JS 脚本
- (void)evaluateJavaScript:(NSString *)jsString complete:(void (^ _Nullable)(id _Nullable value, BOOL isJSValue, NSError * _Nullable error, VSWebViewController *webVC))complete {
    
    __weak typeof(self) ws = self;
    
    if (kWebKitAvailable) {
        
        [self.wkWebView evaluateScript:jsString complete:^(id _Nullable value, NSError * _Nullable error) {
            __strong typeof(ws) ss = ws;
            performBlock(complete, value, NO, error, ss);
        }];
        
    } else {
        
        [self.webView evaluateScript:jsString withSourceURL:nil complete:^(JSValue * _Nullable value, NSError * _Nullable error) {
            __strong typeof(ws) ss = ws;
            performBlock(complete, value, YES, error, ss);
        }];
    }
}

// OC调用JS方法
- (void)callJSFunction:(NSString * __nonnull)functionName arguments:(NSArray *_Nullable)arguments complete:(void (^ _Nullable)(id _Nullable value, BOOL isJSValue, NSError * _Nullable error, VSWebViewController *webVC))complete {
    
    __weak typeof(self) weakSelf = self;
    
    if (kWebKitAvailable) {
        [self.wkWebView callJSFunction:functionName arguments:arguments complete:^(id  _Nullable value, NSError * _Nullable error) {
            __strong typeof(self) strongSelf = weakSelf;
            !complete ?: complete(value, NO, error, strongSelf);
        }];
    } else {
        [self.webView callJSFunction:functionName arguments:arguments complete:^(JSValue * _Nullable value, NSError * _Nullable error) {
            __strong typeof(self) strongSelf = weakSelf;
            !complete ?: complete(value, YES, error, strongSelf);
        }];
    }
}

/*  添加接收JS消息的block
 *  web端通过 window.webkit.messageHandlers.<name>.postMessage(<messageBody>)发送消息
 *  message数据类型: NSNumber, NSString, NSDate, NSArray, NSDictionary, and NSNull
 */
- (void)addScriptMessageHandlerForName:(NSString *)name handler:(void(^)(VSWebViewController *webVC, id message, NSString *name))handler {
    __weak typeof(self) ws = self;
    [self.wkWebView addScriptMessageHandlerForName:name handler:^(WKWebView * _Nonnull web, WKUserContentController * _Nonnull userContentController, WKScriptMessage * _Nonnull message) {
        __strong typeof(ws) ss = ws;
        !handler ?: handler(ss, message.body, message.name);
    }];
}

// 输出OC对象的方法供JS调用
- (void)exportObjectCMethodsForObject:(NSObject <JSExport>*)obj jsObjectName:(NSString *)name {
    [self.webView exportObjectCMethodsForObject:obj jsObjectName:name];
}

@end

@implementation VSWebViewController (Utils)

- (void)bodyTextSizeScaling:(double)scaling complete:(void (^ _Nullable)(id _Nullable value, BOOL isJSValue, NSError * _Nullable error, VSWebViewController *webViewController))complete {
    
    NSString *js = [NSString stringWithFormat:@"document.getElementsByTagName('body')[0].style.webkitTextSizeAdjust= '%@%@'" , @(scaling * 100.0), @"%"];
    
    [self evaluateJavaScript:js complete:complete];
}

@end
