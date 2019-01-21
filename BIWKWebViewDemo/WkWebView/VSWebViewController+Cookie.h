//
//  VSWebViewController+Cookie.h
//  Venus
//
//  Created by Wang,Houwen on 2018/9/5.
//  Copyright © 2018年 Li,Xi(Speech). All rights reserved.
//

#import "VSWebViewController.h"

@interface VSWebViewController (Cookie) <VSHTTPCookieRuntimeSupport>

// 添加全局 cookies
+ (void)addGlobalCookies:(NSDictionary <NSString *, NSString *>*)cookies;

// 修改全局 cookie, if not exist, add
+ (void)setGlobalCookie:(NSString *)cookie forName:(NSString *)name;

// 删除全局cookies
+ (void)removeAllGlobalCookies;

// 添加 cookies
- (void)addCookies:(NSDictionary <NSString *, NSString *>*)cookies;

// 修改 cookie, if not exist, add
- (void)setCookie:(NSString *)cookie forName:(NSString *)name;

// 删除所有cookie, 全局 cookie 下一次还会被加载
- (void)removeAllCookies;

#pragma mark - rumtime cookie support

- (void)getCookiesWithComplete:(void(^_Nullable)(NSDictionary <NSString *, NSString *>*cookies))complete;
- (void)getCookieForName:(NSString *)name complete:(void(^_Nullable)(NSString *cookie))complete;

- (void)setCookieForName:(NSString *)name value:(NSString *)value validSeconds:(NSInteger)validSeconds complete:(void(^_Nullable)(void))complete;

- (void)deleteCookieForName:(NSString *)name complete:(void(^_Nullable)(void))complete;
- (void)deleteAllCookiesWithComplete:(void(^_Nullable)(void))complete;

@end
