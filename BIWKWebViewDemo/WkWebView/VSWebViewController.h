//
//  VSWebViewController.h
//  Venus
//
//  Created by houwen.wang on 16/4/25.
//  Copyright © 2016年 houwen.wang. All rights reserved.
//
//  内嵌webview的视图控制器

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "UIWebView+Category.h"
#import "WKWebView+Category.h"
#import "NSObject+Category.h"

@class VSWebViewController;

#define kWebKitAvailable (NSClassFromString(@"WKWebView") ? YES : NO)

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, VSWebViewLoadStatus) {
    VSWebViewLoadStatusUnLoad,
    VSWebViewLoadStatusLoading,
    VSWebViewLoadStatusSuccess,
    VSWebViewLoadStatusFailed,
};

typedef NS_ENUM(NSInteger, VSWebViewNavigationType) {
    VSWebViewNavigationTypeLinkClicked,
    VSWebViewNavigationTypeFormSubmitted,
    VSWebViewNavigationTypeBackForward,
    VSWebViewNavigationTypeReload,
    VSWebViewNavigationTypeFormResubmitted,
    VSWebViewNavigationTypeOther
};

typedef void (^VSWebViewLoadStatusBlock)(__kindof VSWebViewController *webVC, NSString *__nullable identifier, VSWebViewLoadStatus status, NSError *__nullable error);

@protocol VSWebViewControllerDelegate;

@interface VSWebViewController : UIViewController <WKUIDelegate, WKNavigationDelegate, UIWebViewDelegate, VSUIWebViewHookDelegate>

@property (nonatomic, copy, nullable) NSString *URLString;
@property (nonatomic, copy, nullable) NSString *HTMLString;

@property (nonatomic, copy, nullable) NSString *identifier;

@property (nonatomic, weak) id <VSWebViewControllerDelegate> delegate;
@property (nonatomic, copy) VSWebViewLoadStatusBlock loadStatusBlock;

// WKWebView
// kWebKitAvailable is YES return instance, otherwise return nil
@property (nonatomic, strong, readonly) WKWebView *wkWebView;
@property (nonatomic, strong, readonly) WKWebViewConfiguration *wkWebViewConfiguration;

// UIWebView
// kWebKitAvailable is NO return instance, otherwise return nil
@property (nonatomic, strong, readonly) UIWebView *webView;

+ (instancetype)webViewControllerWithURL:(NSString * _Nullable)URL;

- (instancetype)initWithURL:(NSString * _Nullable)URL;

// load
- (void)reload;
- (void)reloadFromOrigin;
- (void)stopLoading;

// navigation

@property (nonatomic, readonly) BOOL canGoBack;
@property (nonatomic, readonly) BOOL canGoForward;

- (void)goBack;
- (void)goForward;

@end

@protocol VSWebViewControllerDelegate <NSObject>

@optional

- (BOOL)webViewControllerShouldStartLoad:(VSWebViewController *)webVC request:(NSURLRequest *)request navigationType:(VSWebViewNavigationType)type;
- (void)webViewControllerDidStartLoading:(VSWebViewController *)webVC;
- (void)webViewControllerDidEndLoading:(VSWebViewController *)webVC error:(NSError *)error;
- (void)webView:(VSWebViewController *)webVC didReceiveNewTitle:(NSString *)newTitle isMainFrame:(BOOL)isMain;

@end

NS_ASSUME_NONNULL_END
