//
//  VSWebViewController+UIGestureRecognizer.h
//  Venus
//
//  Created by Wang,Houwen on 2018/9/5.
//  Copyright © 2018年 Li,Xi(Speech). All rights reserved.
//

#import "VSWebViewController.h"
#import "VSWebViewController+JavaScript.h"

@protocol VSWebViewControllerGestureDelegate

@optional

- (void)webView:(VSWebViewController *)webVC longPressAtImageSource:(NSString *)imageURL;

@end

@interface VSWebViewController (UIGestureRecognizer)

@property (nonatomic, weak) id <VSWebViewControllerGestureDelegate> gestureDelegate;

@property (nonatomic, assign) BOOL supportLongPressSavaImage;                              // default is NO
@property (nonatomic, strong, readonly) UILongPressGestureRecognizer *longPressGesture;    //

@end
