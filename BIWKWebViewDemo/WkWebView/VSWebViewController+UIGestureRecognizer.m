//
//  VSWebViewController+UIGestureRecognizer.m
//  Venus
//
//  Created by Wang,Houwen on 2018/9/5.
//  Copyright © 2018年 Li,Xi(Speech). All rights reserved.
//

#import "VSWebViewController+UIGestureRecognizer.h"

@implementation VSWebViewController (UIGestureRecognizer)

- (UILongPressGestureRecognizer *)longPressGesture {
    UILongPressGestureRecognizer *ges = objc_getAssociatedObject(self, _cmd);
    if (ges == nil) {
        ges = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressGesture:)];
        [self setLongPressGesture:ges];
    }
    return ges;
}

- (void)setLongPressGesture:(UILongPressGestureRecognizer * _Nonnull)longPressGesture {
    objc_setAssociatedObject(self, @selector(longPressGesture), longPressGesture, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)supportLongPressSavaImage {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setSupportLongPressSavaImage:(BOOL)supportLongPressSavaImage {
    
    if (self.supportLongPressSavaImage != supportLongPressSavaImage) {
        
        objc_setAssociatedObject(self, @selector(supportLongPressSavaImage), @(supportLongPressSavaImage), OBJC_ASSOCIATION_ASSIGN);
        
        UIView *webView = kWebKitAvailable ? self.wkWebView : self.webView;
        
        if (supportLongPressSavaImage) {
            [webView addGestureRecognizer:self.longPressGesture];
        } else {
            [webView removeGestureRecognizer:self.longPressGesture];
        }
    }
}

- (id<VSWebViewControllerGestureDelegate>)gestureDelegate {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setGestureDelegate:(id<VSWebViewControllerGestureDelegate>)gestureDelegate {
    objc_setAssociatedObject(self, @selector(gestureDelegate), gestureDelegate, OBJC_ASSOCIATION_ASSIGN);
}

- (void)handleLongPressGesture:(UILongPressGestureRecognizer*)recognizer {
    
    CGPoint touchPoint = [recognizer locationInView:self.wkWebView];
    NSString *js = [NSString stringWithFormat:@"document.elementFromPoint(%f, %f).src", touchPoint.x, touchPoint.y];
    
    __weak typeof(self) weakSelf = self;
    
    [self evaluateJavaScript:js complete:^(id  _Nullable value, BOOL isJSValue, NSError * _Nullable error, VSWebViewController * _Nonnull webVC) {
        if (!error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf.gestureDelegate && [((NSObject *)strongSelf.gestureDelegate) respondsToSelector:@selector(webView:longPressAtImageSource:)]) {
                [strongSelf.gestureDelegate webView:weakSelf longPressAtImageSource:(isJSValue ? [(JSValue *)value toString] : value)];
            }
        }
    }];
}

@end
