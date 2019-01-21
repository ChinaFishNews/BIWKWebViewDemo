//
//  VSWebViewController+JavaScript.h
//  Venus
//
//  Created by wanghouwen on 2017/12/15.
//  Copyright © 2017年 wanghouwen. All rights reserved.
//

#import "VSWebViewController.h"
#import "UIWebView+Category.h"
#import "WKWebView+Category.h"
#import <JavaScriptCore/JavaScriptCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface VSWebViewController (JavaScript)

// 注入JS 脚本
- (void)evaluateJavaScript:(NSString *)jsString complete:(void (^ _Nullable)(id _Nullable value, BOOL isJSValue, NSError * _Nullable error, VSWebViewController *webVC))complete;

// OC调用JS方法(直接使用方法名，不需要在方法名后加括号)
- (void)callJSFunction:(NSString * __nonnull)functionName arguments:(NSArray *_Nullable)arguments complete:(void (^ _Nullable)(id _Nullable value, BOOL isJSValue, NSError * _Nullable error, VSWebViewController *webVC))complete;

/*  添加接收JS消息的block
 *  web端通过 window.webkit.messageHandlers.<name>.postMessage(<messageBody>)发送消息
 *  message 数据类型: NSNumber, NSString, NSDate, NSArray, NSDictionary, and NSNull
 */
- (void)addScriptMessageHandlerForName:(NSString *)name handler:(void(^)(VSWebViewController *webVC, id message, NSString *name))handler API_AVAILABLE(macosx(10.10), ios(8.0));

// 输出OC对象的方法供JS调用
- (void)exportObjectCMethodsForObject:(NSObject <JSExport>*)obj jsObjectName:(NSString *)name NS_DEPRECATED_IOS(2_0, 7_0);

@end

@interface VSWebViewController (Utils)

// body 字体缩放
- (void)bodyTextSizeScaling:(double)scaling complete:(void (^ _Nullable)(id _Nullable value, BOOL isJSValue, NSError * _Nullable error, VSWebViewController *webVC))complete;

@end

NS_ASSUME_NONNULL_END
