//
//  VSWebViewController.m
//  Venus
//
//  Created by houwen.wang on 16/4/25.
//  Copyright © 2016年 houwen.wang. All rights reserved.
//

#import "VSWebViewController.h"

#define kErrorHtmlString (@"<!DOCTYPE html> <html> <head> <meta charset=\"UTF-8\"> <title></title> </head> <body> </body></html>")

@interface VSWebViewController ()

@property (nonatomic, strong) UIProgressView *progressView;

// WKWebView
@property (nonatomic, strong) WKWebViewConfiguration *wkWebViewConfiguration;
@property (nonatomic, strong) WKWebView *wkWebView;

// UIWebView
@property (nonatomic, strong) UIWebView *webView;

//@property (nonatomic, strong) VSNetworkErrorView *networkErrorView;

@end

@implementation VSWebViewController

#pragma mark - initialize

- (instancetype)init {
    if (self = [super init]) {
        self.hidesBottomBarWhenPushed = YES; // 默认隐藏 bottom bar
    }
    return self;
}

+ (instancetype)webViewControllerWithURL:(NSString * _Nullable)URL {
    return [[self alloc] initWithURL:URL];
}

- (instancetype)initWithURL:(NSString * _Nullable)URL {
    if (self = [self init]) {
        self.URLString = URL;
    }
    return self;
}

#pragma mark - life cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    [self callBackLoadStatusWithStatus:VSWebViewLoadStatusUnLoad error:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    UIView *webView = kWebKitAvailable ? self.wkWebView : self.webView;
    
    if (!webView.superview) {
        [self.view addSubview:webView];
    }
    
    if (!self.progressView.superview) {
        [self.view addSubview:_progressView];
    }
}

#pragma mark - layout

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    UIView *webView = kWebKitAvailable ? self.wkWebView : self.webView;
    webView.frame = self.view.bounds;
    
    _progressView.frame = CGRectMake(0, 0, webView.bounds.size.width, 5.f);
}

#pragma mark - load

- (void)reload {
    kWebKitAvailable ? [_wkWebView reload] : [_webView reload];
}

- (void)reloadFromOrigin {
    kWebKitAvailable ? [_wkWebView reloadFromOrigin] : [self setURLString:_URLString];
}

- (void)stopLoading {
    kWebKitAvailable ? [_wkWebView stopLoading] : [_webView stopLoading];
}

#pragma mark - navigation

- (BOOL)canGoBack {
    return kWebKitAvailable ? _wkWebView.canGoBack : _webView.canGoBack;
}

- (BOOL)canGoForward {
    return kWebKitAvailable ? _wkWebView.canGoForward : _webView.canGoForward;
}

- (void)goBack {
    kWebKitAvailable ? [_wkWebView goBack] : [_webView goBack];
}

- (void)goForward {
    kWebKitAvailable ? [_wkWebView goForward] : [_webView goForward];
}

#pragma mark - setter

- (void)setURLString:(NSString *)URLString {
    
    _URLString = [URLString copy];
    
    NSString *timeStamp = @"timeStamp_t=";
    
    NSString *URLSting_t = [URLString copy];
    
    if ([URLSting_t rangeOfString:timeStamp].location == NSNotFound) {
        
        if (![URLSting_t containsString:@"?"]) {
            URLSting_t = [URLSting_t stringByAppendingString:[NSString stringWithFormat:@"?%@%@", timeStamp, @([[NSDate date] timeIntervalSince1970])]];
        } else {
            URLSting_t = [URLSting_t stringByAppendingString:[NSString stringWithFormat:@"&%@%@", timeStamp, @([[NSDate date] timeIntervalSince1970])]];
        }
    }
    
    [self loadRequest:[NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLSting_t] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30]];
}

- (void)setHTMLString:(NSString *)HTMLString {
    _HTMLString = [HTMLString copy];
    [self loadHTMLStringWithHTMLString:HTMLString];
}

#pragma mark - load content

// 加载 request
- (void)loadRequest:(NSURLRequest *)request {
    [self stopLoading];
    kWebKitAvailable ? [self.wkWebView loadRequest:request] : [self.webView loadRequest:request];
}

- (void)loadHTMLStringWithHTMLString:(NSString *)htmlString {
    [self stopLoading];
    kWebKitAvailable ? [self.wkWebView loadHTMLString:htmlString baseURL:nil] : [self.webView loadHTMLString:htmlString baseURL:nil];
}

#pragma mark - WKNavigationDelegate & WKUIDelegate

//  加载状态回调

// 页面开始加载时调用
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation {
    [self callBackLoadStatusWithStatus:VSWebViewLoadStatusLoading error:nil];
}

// 当内容开始返回时调用
- (void)webView:(WKWebView *)webView didCommitNavigation:(null_unspecified WKNavigation *)navigation {
}

// 页面加载完成之后调用
- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
    [self handleWebViewDidEndLoad:webView error:nil];
}

// 页面加载失败时调用
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(nonnull NSError *)error {
    [self handleWebViewDidEndLoad:webView error:error];
}

//  页面跳转代理方法

// 接收到服务器跳转请求之后调用
- (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation {
}

// 在发送请求之前，决定是否跳转
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    
    BOOL shouldStart = [self callBackShouldStartLoadWithRequest:navigationAction.request navigationType:navigationAction.navigationType];
    decisionHandler(shouldStart ? WKNavigationActionPolicyAllow : WKNavigationActionPolicyCancel);
}

// 在收到响应后，决定是否跳转
- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    decisionHandler(WKNavigationResponsePolicyAllow);
}

- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame complete:(void (^)(void))complete {
}

- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame complete:(void (^)(BOOL))complete {
}

- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame complete:(void (^)(NSString * _Nullable))complete {
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidStartLoad:(UIWebView *)webView {
    [self callBackLoadStatusWithStatus:VSWebViewLoadStatusLoading error:nil];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [self handleWebViewDidEndLoad:webView error:nil];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    [self handleWebViewDidEndLoad:webView error:error];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    return [self callBackShouldStartLoadWithRequest:request navigationType:navigationType];
}

#pragma mark - VSUIWebViewHookDelegate

- (void)webView:(UIWebView *)webview didReceiveNewTitle:(NSString *)newTitle isMainFrame:(BOOL)isMainFrame {
    [self callBackDidReceiveNewTitle:newTitle isMainFrame:isMainFrame];
}

- (void)webView:(UIWebView *)webview javaScriptContextDidChanged:(JSContext *)newJSContext isMainFrame:(BOOL)isMainFrame {
}

#pragma mark - private methods

- (void)callBackDidReceiveNewTitle:(NSString *)title isMainFrame:(BOOL)isMain {
    if (_delegate && [_delegate respondsToSelector:@selector(webView:didReceiveNewTitle:isMainFrame:)]) {
        [_delegate webView:self didReceiveNewTitle:title isMainFrame:isMain];
    }
    
    // 更新标题
    if (![self.title isEqualToString:title]) {
        self.title = title;
    }
}

// 加载状态回调
- (void)callBackLoadStatusWithStatus:(VSWebViewLoadStatus)status error:(NSError *)error {
    
    !_loadStatusBlock ?: _loadStatusBlock(self, _identifier, status, error);
    
    if (status == VSWebViewLoadStatusLoading) {
        
        if (_delegate && [_delegate respondsToSelector:@selector(webViewControllerDidStartLoading:)]) {
            [_delegate webViewControllerDidStartLoading:self];
        }
        
        [self showNetworkErrorView:NO];
        
    } else if (status == VSWebViewLoadStatusSuccess || status == VSWebViewLoadStatusFailed) {
        
        if (_delegate && [_delegate respondsToSelector:@selector(webViewControllerDidEndLoading:error:)]) {
            [_delegate webViewControllerDidEndLoading:self error:error];
        }
    }
}

- (BOOL)callBackShouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(NSInteger)type {
    
    NSDictionary <NSNumber *, NSNumber *>*typeMap = nil;
    
    if (kWebKitAvailable) {
        typeMap = @{@(WKNavigationTypeLinkActivated) : @(VSWebViewNavigationTypeLinkClicked),
                    @(WKNavigationTypeFormSubmitted) : @(VSWebViewNavigationTypeFormSubmitted),
                    @(WKNavigationTypeBackForward) : @(VSWebViewNavigationTypeBackForward),
                    @(WKNavigationTypeReload) : @(VSWebViewNavigationTypeReload),
                    @(WKNavigationTypeFormResubmitted) : @(VSWebViewNavigationTypeFormResubmitted),
                    @(WKNavigationTypeOther) : @(VSWebViewNavigationTypeOther)};
        
    } else {
        typeMap = @{@(UIWebViewNavigationTypeLinkClicked) : @(VSWebViewNavigationTypeLinkClicked),
                    @(UIWebViewNavigationTypeFormSubmitted) : @(VSWebViewNavigationTypeFormSubmitted),
                    @(UIWebViewNavigationTypeBackForward) : @(VSWebViewNavigationTypeBackForward),
                    @(UIWebViewNavigationTypeReload) : @(VSWebViewNavigationTypeReload),
                    @(UIWebViewNavigationTypeFormResubmitted) : @(VSWebViewNavigationTypeFormResubmitted),
                    @(UIWebViewNavigationTypeOther) : @(VSWebViewNavigationTypeOther)};
    }
    
    SEL selector = @selector(webViewControllerShouldStartLoad:request:navigationType:);
    
    if (_delegate &&[_delegate respondsToSelector:selector]) {
        
        return [_delegate webViewControllerShouldStartLoad:self
                                                   request:request
                                            navigationType:typeMap[@(type)].integerValue];
    }
    
    return YES;
}

- (void)handleWebViewDidEndLoad:(UIView *)webView error:(NSError *)error {
    
    // 错误
    if (error) {
        
        // 请求被取消
        if (error.code == NSURLErrorCancelled) {
            return;
        }
        
        BOOL canShowBadNetworkView = [[error.userInfo[NSURLErrorFailingURLStringErrorKey] stringByReplacingOccurrencesOfString:@"/" withString:@""]
                                      rangeOfString:[_URLString stringByReplacingOccurrencesOfString:@"/" withString:@""]].length;
        
        if (canShowBadNetworkView) {
            [self showNetworkErrorView:YES];
        }
        
        [self callBackLoadStatusWithStatus:VSWebViewLoadStatusFailed error:error];
    } else {
        
        [self showNetworkErrorView:NO];
        
        if ([_HTMLString isEqualToString:kErrorHtmlString]) {
            _HTMLString = nil;
        }
        
        [self callBackLoadStatusWithStatus:VSWebViewLoadStatusSuccess error:error];
    }
}

- (void)addProgressObserverForWebView:(id)webView {
    
    if (kWebKitAvailable && ![webView isKindOfClass:[WKWebView class]]) return;
    if (!kWebKitAvailable && ![webView isKindOfClass:[UIWebView class]]) return;
    
    __weak typeof(self) ws = self;
    [webView observeValueForKeyPath:@"estimatedProgress"
                            options:NSKeyValueObservingOptionNew
                            context:nil
                        changeBlock:^(NSString * _Nonnull keyPath,
                                      id  _Nonnull object,
                                      NSDictionary<NSKeyValueChangeKey,id> * _Nonnull change,
                                      void * _Nullable context) {
                            
                            double newProgress = [[change objectForKey:NSKeyValueChangeNewKey] doubleValue];
                            
                            if (ws.progressView.progress != newProgress) {
                                !ws.progressView.hidden ?: [ws.progressView setHidden:NO];
                                [ws.progressView setProgress:newProgress animated:YES];
                            }
                            
                            if (newProgress == 1.f) {
                                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                    ws.progressView.hidden ?: [ws.progressView setHidden:YES];
                                    [ws.progressView setProgress:0.f animated:NO];
                                });
                            }
                        }];
}

- (void)showNetworkErrorView:(BOOL)show {
    
//    if (show) {
//
//        if (!self.networkErrorView.superview) {
//            UIView *webView = kWebKitAvailable ? self.wkWebView : self.webView;
//            [webView addSubview:self.networkErrorView];
//        }
//
//        UIView *webView = kWebKitAvailable ? self.wkWebView : self.webView;
//        self.networkErrorView.frame = webView.bounds;
//
//        VSNetworkAPIErrors errorType = ([AFNetworkReachabilityManager sharedManager].networkReachabilityStatus == AFNetworkReachabilityStatusNotReachable ? VSNetworkAPINotReachableError : VSNetworkAPIUnknowError);
//
//        self.networkErrorView.errorType = errorType;
//        self.networkErrorView.hidden = NO;
//
//    } else {
//        _networkErrorView.hidden = YES;
//    }
}

#pragma mark - other

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    return YES;
}

#pragma mark - lazy load

- (WKWebViewConfiguration *)wkWebViewConfiguration {
    
    if (!kWebKitAvailable) return nil;
    
    if (!_wkWebViewConfiguration) {
        _wkWebViewConfiguration = [[WKWebViewConfiguration alloc] init];
        
        if (@available(iOS 10.0, *)) {
            _wkWebViewConfiguration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeAll;
            _wkWebViewConfiguration.dataDetectorTypes = WKDataDetectorTypeAll;
        }
    }
    return _wkWebViewConfiguration;
}

- (WKWebView *)wkWebView {
    
    if (!kWebKitAvailable) return nil;
    
    if (!_wkWebView) {
        _wkWebView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:self.wkWebViewConfiguration];
        _wkWebView.UIDelegate = self;
        _wkWebView.navigationDelegate = self;
        _wkWebView.backgroundColor = [UIColor whiteColor];
        
        __weak typeof(self) ws = self;
        [_wkWebView observeValueForKeyPath:@"title" options:NSKeyValueObservingOptionNew context:nil changeBlock:^(NSString *keyPath, id object, NSDictionary<NSKeyValueChangeKey,id> *change, void *context) {
            __strong typeof(ws) ss = ws;
            [ss callBackDidReceiveNewTitle:change[NSKeyValueChangeNewKey] isMainFrame:YES];
        }];
        
        [self addProgressObserverForWebView:_wkWebView]; // 监听加载进度
    }
    return _wkWebView;
}

- (UIWebView *)webView {
    
    if (kWebKitAvailable) return nil;
    
    if (!_webView) {
        _webView = [[UIWebView alloc] init];
        _webView.delegate = self;
        _webView.hookDelegate = self;
        _webView.scalesPageToFit = YES;
        _webView.dataDetectorTypes = UIDataDetectorTypeAll;
        _webView.backgroundColor = [UIColor whiteColor];
        
        [self addProgressObserverForWebView:_webView]; // 监听加载进度
    }
    return _webView;
}

- (UIProgressView *)progressView {
    if (!_progressView) {
        _progressView = [[UIProgressView alloc] init];
        _progressView.progressTintColor = [UIColor colorWithRed:51/255.f green:136/255.f blue:255/255.f alpha:1.f];
        _progressView.trackTintColor = [UIColor clearColor];
    }
    return _progressView;
}

//- (VSNetworkErrorView *)networkErrorView {
//    if (!_networkErrorView) {
//        _networkErrorView = [VSNetworkErrorView new];
//        
//        __weak typeof(self) ws = self;
//        _networkErrorView.didTouched = ^(VSNetworkErrorView *errorView) {
//            ws.URLString = ws.URLString;
//        };
//    }
//    return _networkErrorView;
//}

#pragma mark - other

- (void)dealloc {
    UIView *webView = kWebKitAvailable ? _wkWebView : _webView;
    [webView removeObserveValueForBlock:NULL keyPath:@"estimatedProgress" context:nil];
}

@end
