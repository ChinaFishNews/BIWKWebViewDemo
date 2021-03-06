//
//  WKWebView+Category.m
//  Venus
//
//  Created by houwen.wang on 2016/6/13.
//  Copyright © 2016年 houwen.wang. All rights reserved.
//

#import "WKWebView+Category.h"
#import "NSObject+Category.h"

@implementation VSScriptMessageHandler

#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if (self.scriptMessageHandler) {
        self.scriptMessageHandler(userContentController, message);
    }
}

@end

@implementation WKWebView (Category)

// 注入JS 脚本
- (void)evaluateScript:(NSString *)script complete:(void (^ _Nullable)(_Nullable id returnValue, NSError * _Nullable error))complete {
    [self evaluateJavaScript:script completionHandler:complete];
}

// 注入JS 脚本
- (void)addUserScript:(NSString *)script injectionTime:(WKUserScriptInjectionTime)injectionTime forMainFrameOnly:(BOOL)forMainFrameOnly {
    WKUserScript *s = [[WKUserScript alloc] initWithSource:script injectionTime:injectionTime forMainFrameOnly:forMainFrameOnly];
    [self.configuration.userContentController addUserScript:s];
}

@end

@implementation WKWebView (SendMessage)

// OC调用JS方法
- (void)callJSFunction:(NSString * __nonnull)functionName arguments:(NSArray *_Nullable)arguments complete:(void (^ _Nullable)(id _Nullable returnValue, NSError * _Nullable error))complete {
    
    if (functionName == nil) {
        if (complete) {
            complete(nil, [NSError errorWithDomain:@"JS方法名不能nil" code:VSEvaluateJavaScriptErrorUndefinedFunctionName userInfo:nil]);
        }
        return;
    }
    
    NSMutableString *argsString = [NSMutableString string];
    
    for (id arg in arguments) {
        
        NSUInteger index = [arguments indexOfObject:arg];
        
        if ([arg isKindOfClass:[NSString class]]) {
            [argsString appendString:[NSString stringWithFormat:@"%@'%@'", (index == 0 ? @"" : @", "), arg]];
        } else {
            [argsString appendString:[NSString stringWithFormat:@"%@%@", (index == 0 ? @"" : @", "), arg]];
        }
    }
    [self evaluateJavaScript:[NSString stringWithFormat:@"%@(%@)", functionName, argsString] completionHandler:complete];
}

- (NSMutableDictionary <NSString *, NSMutableSet *>*)scriptMessageHandlerMap {
    NSMutableDictionary *map = objc_getAssociatedObject(self, _cmd);
    if (map == nil) {
        map = [NSMutableDictionary dictionary];
        [self setScriptMessageHandlerMap:map];
    }
    return map;
}

- (void)setScriptMessageHandlerMap:(NSMutableDictionary <NSString *, NSMutableSet *>*)scriptMessageHandlerMap {
    objc_setAssociatedObject(self, @selector(scriptMessageHandlerMap), scriptMessageHandlerMap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

/*  添加接收JS消息的block
 *  web端通过 window.webkit.messageHandlers.<name>.postMessage(<messageBody>)发送消息
 *  可接受的数据类型: NSNumber, NSString, NSDate, NSArray, NSDictionary, and NSNull
 */
- (void)addScriptMessageHandlerForName:(NSString *)name handler:(void(^)(WKWebView *web, WKUserContentController *userContentController, WKScriptMessage *message))handler {
    
    if (name && handler) {
        
        NSMutableDictionary <NSString *, NSMutableSet *> *scriptMessageHandlerMap = [self scriptMessageHandlerMap];
        NSMutableSet *handlers = scriptMessageHandlerMap[name];
        if (handlers == nil) {
            handlers = [NSMutableSet set];
            scriptMessageHandlerMap[name] = handlers;
        }
        [handlers addObject:handler];
        
        VSScriptMessageHandler *handler_t = objc_getAssociatedObject(self, _cmd);
        
        if (handler_t == nil) {
            handler_t = [[VSScriptMessageHandler alloc] init];
            objc_setAssociatedObject(self, _cmd, handler_t, OBJC_ASSOCIATION_RETAIN);
            
            __weak typeof(self) ws = self;
            handler_t.scriptMessageHandler = ^(WKUserContentController *userContentController, WKScriptMessage *message) {
                __strong typeof(ws) ss = ws;
                
                NSMutableSet *handlers = [ss scriptMessageHandlerMap][message.name];
                
                for (void(^handler)(WKWebView *web, WKUserContentController *userContentController, WKScriptMessage *message) in handlers) {
                    handler(ss, userContentController, message);
                }
                
            };
        }
        
        [self.configuration.userContentController addScriptMessageHandler:handler_t name:name];
    }
}

// 移除接收JS消息的对象
- (void)removeScriptMessageHandlerForName:(NSString *)name {
    [self.configuration.userContentController removeScriptMessageHandlerForName:name];
}

@end

@implementation WKWebView (Hooks)

- (BOOL)_didObserveNewTitle {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)set_didObserveNewTitle:(BOOL)_didObserveNewTitle {
    objc_setAssociatedObject(self, @selector(_didObserveNewTitle), @(_didObserveNewTitle), OBJC_ASSOCIATION_ASSIGN);
}

- (id<VSWKWebViewHookDelegate>)hookDelegate {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setHookDelegate:(id<VSWKWebViewHookDelegate>)hookDelegate {
    
    objc_setAssociatedObject(self, @selector(hookDelegate), hookDelegate, OBJC_ASSOCIATION_ASSIGN);
    
    if (!self._didObserveNewTitle && hookDelegate) {
        
        __weak typeof(self) ws = self;
        [self observeValueForKeyPath:@"title" options:NSKeyValueObservingOptionNew context:nil changeBlock:^(NSString *keyPath, id object, NSDictionary<NSKeyValueChangeKey,id> *change, void * context) {
            if (ws.hookDelegate && [(NSObject *)self.hookDelegate respondsToSelector:@selector(webView:didReceiveNewTitle:)]) {
                [ws.hookDelegate webView:ws didReceiveNewTitle:object];
            }
        }];
        
        [self set_didObserveNewTitle:YES];
    }
}

@end

NSString *const WKWebViewCookieFunctionName_GetCookies       = @"__native_injection_getCookies";
NSString *const WKWebViewCookieFunctionName_GetCookie        = @"__native_injection_getCookie";
NSString *const WKWebViewCookieFunctionName_SetCookie        = @"__native_injection_setCookie";
NSString *const WKWebViewCookieFunctionName_DeleteCookie     = @"__native_injection_deleteCookie";
NSString *const WKWebViewCookieFunctionName_DeleteAllCookies = @"__native_injection_deleteAllCookies";

@implementation WKWebView (VSHTTPCookieRuntimeSupport)

// 注入cookie相关js
- (void)injectionCookieScriptIfNeededWithComplete:(void (^)(void))complete {
    
    __weak typeof(self) ws = self;
    [self callJSFunction:WKWebViewCookieFunctionName_GetCookies arguments:nil complete:^(id  _Nullable returnValue, NSError * _Nullable error) {
        
        if (error) {
            
            NSURL *jsURL = [[NSBundle mainBundle] URLForResource:@"JSBundle.bundle/cookie" withExtension:@"js"];
            NSString *cookieFunctions = [NSString stringWithContentsOfURL:jsURL encoding:NSUTF8StringEncoding error:NULL];
            
            [ws evaluateScript:cookieFunctions complete:^(id  _Nullable returnValue, NSError * _Nullable error) {
                !complete ?: complete();
            }];
            
        } else {
            !complete ?: complete();
        }
        
    }];
}

- (void)getCookiesWithComplete:(void(^_Nullable)(NSDictionary <NSString *, NSString *>*cookies))complete {
    
    __weak typeof(self) ws = self;
    [self injectionCookieScriptIfNeededWithComplete:^{
        
        [ws callJSFunction:WKWebViewCookieFunctionName_GetCookies arguments:nil complete:^(NSArray <NSString *>* _Nullable value, NSError * _Nullable error) {
            if (complete) {
                NSMutableDictionary *dic = [NSMutableDictionary dictionary];
                for (NSString *cookie in value) {
                    NSArray <NSString *>* cookie_t = [cookie componentsSeparatedByString:@"="];
                    dic[[cookie_t[0] stringByReplacingOccurrencesOfString:@" " withString:@""]] = [cookie_t[1] stringByReplacingOccurrencesOfString:@" " withString:@""];
                }
                complete([NSDictionary dictionaryWithDictionary:dic]);
            }
        }];
        
    }];
}

- (void)getCookieForName:(NSString *)name complete:(void(^_Nullable)(NSString *cookie))complete {
    
    __weak typeof(self) ws = self;
    [self injectionCookieScriptIfNeededWithComplete:^{
        
        [ws callJSFunction:WKWebViewCookieFunctionName_GetCookie arguments:@[name ? : @""] complete:^(id  _Nullable value, NSError * _Nullable error) {
            if (complete) {
                complete(value);
            }
        }];
        
    }];
}

- (void)setCookieForName:(NSString *)name value:(NSString *)value validSeconds:(NSInteger)validSeconds complete:(void(^_Nullable)(void))complete {
    
    __weak typeof(self) ws = self;
    [self injectionCookieScriptIfNeededWithComplete:^{
        
        [ws callJSFunction:WKWebViewCookieFunctionName_SetCookie arguments:@[name ? : @"", value ? : @"", @(validSeconds)] complete:^(id  _Nullable value, NSError * _Nullable error) {
            if (complete) {
                complete();
            }
        }];
        
    }];
}

- (void)deleteCookieForName:(NSString *)name complete:(void(^_Nullable)(void))complete {
    
    __weak typeof(self) ws = self;
    [self injectionCookieScriptIfNeededWithComplete:^{
        
        [ws callJSFunction:WKWebViewCookieFunctionName_DeleteCookie arguments:@[name ? : @""] complete:^(id  _Nullable value, NSError * _Nullable error) {
            if (complete) {
                complete();
            }
        }];
        
    }];
}

- (void)deleteAllCookiesWithComplete:(void(^_Nullable)(void))complete {
    
    __weak typeof(self) ws = self;
    [self injectionCookieScriptIfNeededWithComplete:^{
        
        [ws callJSFunction:WKWebViewCookieFunctionName_DeleteAllCookies arguments:nil complete:^(id  _Nullable value, NSError * _Nullable error) {
            if (complete) {
                complete();
            }
        }];
        
    }];
}

@end
