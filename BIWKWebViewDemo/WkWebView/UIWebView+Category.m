//
//  UIWebView+Category.m
//  Venus
//
//  Created by houwen.wang on 2016/6/12.
//  Copyright © 2016年 houwen.wang. All rights reserved.
//

#import "UIWebView+Category.h"
#import "NSObject+Category.h"

@class WebView;             /* : WAKView : WAKResponder : NSObject */
@class UIWebBrowserView;    /* : UIWebDocumentView : UIWebTiledView : UIView */
@class WebFrame;            /* : NSObject */
@class VSWebFrame;

@interface VSWebFrame : NSObject

@property (nonatomic, copy) NSString * name;                        //
@property (nonatomic, assign) BOOL isMainFrame;                     //
@property (nonatomic, weak) WebFrame * parentFrame;                 //
@property (nonatomic, weak) NSArray <WebFrame *>* childFrames;      //
@property (nonatomic, weak) JSContext * globalContext;              //
@property (nonatomic, weak) JSContext * javaScriptContext;          //

@end

@implementation VSWebFrame
@end

@implementation UIWebView (Category)

// JS执行环境
- (JSContext *)jsContext {
    JSContext *jsc = [self valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"];
    return jsc;
}

// 注入JS 脚本
- (void)evaluateScript:(NSString *)script withSourceURL:(NSURL *_Nullable)sourceURL complete:(void (^ _Nullable)(JSValue * _Nullable returnValue, NSError * _Nullable error))complete {
    
    JSContext *context = self.jsContext;
    
    __block BOOL didException = false;
    context.exceptionHandler = ^(JSContext *context, JSValue *exception) {
        context.exception = exception;
        didException = true;
        if (complete) {
            complete(nil, [NSError errorWithDomain:exception.description code:VSEvaluateJavaScriptErrorUnknown userInfo:exception.toDictionary]);
        }
    };
    
    JSValue *returnValue = [context evaluateScript:script withSourceURL:sourceURL];
    if (!didException) {
        if (complete) {
            complete(returnValue, nil);
        }
    }
}

@end

@implementation UIWebView (SendMessage)

// OC调用JS方法
- (void)callJSFunction:(NSString * __nonnull)functionName arguments:(NSArray *_Nullable)arguments complete:(void (^ _Nullable)(JSValue * _Nullable returnValue, NSError * _Nullable error))complete {
    
    if (functionName == nil) {
        if (complete) {
            complete(nil, [NSError errorWithDomain:@"JS方法名不能nil" code:VSEvaluateJavaScriptErrorUndefinedFunctionName userInfo:nil]);
        }
        return;
    }
    
    __block BOOL didException = false;
    self.jsContext.exceptionHandler = ^(JSContext *context, JSValue *exception) {
        context.exception = exception;
        didException = true;
        if (complete) {
            complete(nil, [NSError errorWithDomain:exception.description code:VSEvaluateJavaScriptErrorUnknown userInfo:exception.toDictionary]);
        }
    };
    
    JSValue *function = self.jsContext[functionName];
    if ([function isObject]) {
        JSValue *returnValue = [function callWithArguments:arguments];
        if (!didException) {
            if (complete) {
                complete(returnValue, nil);
            }
        }
    } else {
        if (complete) {
            complete(nil, [NSError errorWithDomain:@"JS方法名不存在" code:VSEvaluateJavaScriptErrorUndefinedFunctionName userInfo:@{@"functionName" : functionName}]);
        }
    }
}

// 替换JS方法的实现, functionName: 方法名, implementationBlock:新的实现, args:JS传递的参数, currentThis:js's this
// 如果JS未定义此方法， 此方法将会被添加
- (void)replaceJSFunction:(NSString * __nonnull)functionName implementationBlock:(id (^)(NSArray <JSValue *>* _Nullable args, JSValue *currentThis))block {
    
    if (functionName) {
        self.jsContext[functionName] = ^ id (void) {
            NSArray <JSValue *>*args_t = [JSContext currentArguments];
            JSValue *currentThis = [JSContext currentThis];
            if (block) {
                return block(args_t, currentThis);
            } else {
                return nil;
            }
        };
    }
}

// 输出OC对象的方法供JS调用
- (void)exportObjectCMethodsForObject:(NSObject <JSExport>*)obj jsObjectName:(NSString *)name {
    if (obj && name) {
        self.jsContext[name] = obj;
    }
}

// 移除OC输出的供JS调用的方法
- (void)unExportObjectCMethodsForJsObjectName:(NSString *)name {
    if (name) {
        self.jsContext[name] = nil;
    }
}

@end

@implementation UIWebView (Hooks)

- (id<VSUIWebViewHookDelegate>)hookDelegate {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setHookDelegate:(id<VSUIWebViewHookDelegate>)hookDelegate {
    objc_setAssociatedObject(self, @selector(hookDelegate), hookDelegate, OBJC_ASSOCIATION_ASSIGN);
}

+ (void)load {
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *sel = [NSString stringWithFormat:@"%@:%@:%@", @"webView", @"didReceiveTitle", @"forFrame"];
        [self exchangeImplementations:NSSelectorFromString(sel)
                          otherMethod:@selector(vs_webView:didReceiveNewTitle:forFrame:)
                           isInstance:YES];
    });
    
#pragma clang diagnostic pop
    
}

- (void)vs_webView:(WebView *)webview didReceiveNewTitle:(NSString *)title forFrame:(WebFrame *)frame {
    [self vs_webView:webview didReceiveNewTitle:title forFrame:frame];
    if (self.hookDelegate && [(NSObject *)self.hookDelegate respondsToSelector:@selector(webView:didReceiveNewTitle:isMainFrame:)]) {
        VSWebFrame *frame_t = [self parserWebFrameProperties:frame];
        [self.hookDelegate webView:self didReceiveNewTitle:title isMainFrame:frame_t.isMainFrame];
    }
}

#pragma mark - private

- (VSWebFrame *)parserWebFrameProperties:(WebFrame *)frame {
    NSDictionary *dic = ((NSObject *)frame).keyValueDictionary;
    
    VSWebFrame *frame_t = [[VSWebFrame alloc] init];
    frame_t.name = dic[@"name"];
    frame_t.parentFrame = dic[@"parentFrame"];
    frame_t.childFrames = dic[@"childFrames"];
    frame_t.globalContext = dic[@"globalContext"];
    frame_t.javaScriptContext = dic[@"javaScriptContext"];
    frame_t.isMainFrame = [[(NSObject *)frame performSelector:@selector(isMainFrame)] boolValue];
    
    return frame_t;
}

@end

NSString *const UIWebViewCookieFunctionName_GetCookies          = @"__native_injection_getCookies";
NSString *const UIWebViewCookieFunctionName_GetCookie           = @"__native_injection_getCookie";
NSString *const UIWebViewCookieFunctionName_SetCookie           = @"__native_injection_setCookie";
NSString *const UIWebViewCookieFunctionName_DeleteCookie        = @"__native_injection_deleteCookie";
NSString *const UIWebViewCookieFunctionName_DeleteAllCookies    = @"__native_injection_deleteAllCookies";

@implementation UIWebView (VSHTTPCookieRuntimeSupport)

// 注入cookie相关js
- (void)injectionCookieScriptIfNeededWithComplete:(void (^)(void))complete {
    
    JSValue *jsValue = self.jsContext[UIWebViewCookieFunctionName_GetCookies];
    
    if ([jsValue isUndefined] || [jsValue isNull] || ![jsValue isObject]) {
        
        NSURL *jsURL = [[NSBundle mainBundle] URLForResource:@"JSBundle.bundle/cookie" withExtension:@"js"];
        NSString *cookieFunctions = [NSString stringWithContentsOfURL:jsURL encoding:NSUTF8StringEncoding error:NULL];
        
        [self evaluateScript:cookieFunctions withSourceURL:nil complete:^(JSValue * _Nullable returnValue, NSError * _Nullable error) {
            !complete ?: complete();
        }];
        
    } else {
        !complete ?: complete();
    }
}

- (void)getCookiesWithComplete:(void(^_Nullable)(NSDictionary <NSString *, NSString *>*cookies))complete {
    
    __weak typeof(self) ws = self;
    [self injectionCookieScriptIfNeededWithComplete:^{
        
        [ws callJSFunction:UIWebViewCookieFunctionName_GetCookies arguments:nil complete:^(JSValue * _Nullable value, NSError * _Nullable error) {
            if (complete) {
                NSMutableDictionary *dic = [NSMutableDictionary dictionary];
                for (NSString *cookie in [value toArray]) {
                    if ([cookie containsString:@"="] && cookie.length > 2) {
                        NSArray <NSString *>* cookie_t = [cookie componentsSeparatedByString:@"="];
                        dic[[cookie_t[0] stringByReplacingOccurrencesOfString:@" " withString:@""]] = [cookie_t[1] stringByReplacingOccurrencesOfString:@" " withString:@""];
                    }
                }
                complete([NSDictionary dictionaryWithDictionary:dic]);
            }
            
        }];
    }];
    
}

- (void)getCookieForName:(NSString *)name complete:(void(^_Nullable)(NSString *cookie))complete {
    
    __weak typeof(self) ws = self;
    [self injectionCookieScriptIfNeededWithComplete:^{
        
        [ws callJSFunction:UIWebViewCookieFunctionName_GetCookie arguments:@[name ? : @""] complete:^(JSValue * _Nullable value, NSError * _Nullable error) {
            if (complete) {
                complete([value toString]);
            }
        }];
        
    }];
}

- (void)setCookieForName:(NSString *)name value:(NSString *)value validSeconds:(NSInteger)validSeconds complete:(void(^_Nullable)(void))complete {
    
    __weak typeof(self) ws = self;
    [self injectionCookieScriptIfNeededWithComplete:^{
        
        [ws callJSFunction:UIWebViewCookieFunctionName_SetCookie arguments:@[name ? : @"", value ? : @"", @(validSeconds)] complete:^(JSValue * _Nullable value, NSError * _Nullable error) {
            if (complete) {
                complete();
            }
        }];
        
    }];
}

- (void)deleteCookieForName:(NSString *)name complete:(void(^_Nullable)(void))complete {
    
    __weak typeof(self) ws = self;
    [self injectionCookieScriptIfNeededWithComplete:^{
        
        [ws callJSFunction:UIWebViewCookieFunctionName_DeleteCookie arguments:@[name ? : @""] complete:^(JSValue * _Nullable value, NSError * _Nullable error) {
            if (complete) {
                complete();
            }
        }];
        
    }];
}

- (void)deleteAllCookiesWithComplete:(void(^_Nullable)(void))complete {
    
    __weak typeof(self) ws = self;
    [self injectionCookieScriptIfNeededWithComplete:^{
        
        [ws callJSFunction:UIWebViewCookieFunctionName_DeleteAllCookies arguments:nil complete:^(JSValue * _Nullable value, NSError * _Nullable error) {
            if (complete) {
                complete();
            }
        }];
        
    }];
}

@end
