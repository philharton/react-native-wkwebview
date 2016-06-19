#import "RCTWKWebViewManager.h"

#import "RCTBridge.h"
#import "RCTUIManager.h"
#import "RCTWKWebView.h"
#import "UIView+React.h"

#import <WebKit/WebKit.h>

@interface RCTWKWebViewManager () <RCTWKWebViewDelegate>

@end

@implementation RCTWKWebViewManager
{
  NSConditionLock *_shouldStartLoadLock;
  BOOL _shouldStartLoad;
}

RCT_EXPORT_MODULE()

- (UIView *)view
{
  RCTWKWebView *webView = [RCTWKWebView new];
  webView.delegate = self;
  return webView;
}

RCT_EXPORT_VIEW_PROPERTY(source, NSDictionary)
RCT_REMAP_VIEW_PROPERTY(bounces, _webView.scrollView.bounces, BOOL)
RCT_REMAP_VIEW_PROPERTY(scrollEnabled, _webView.scrollView.scrollEnabled, BOOL)
RCT_EXPORT_VIEW_PROPERTY(injectedJavaScript, NSString)
RCT_EXPORT_VIEW_PROPERTY(contentInset, UIEdgeInsets)
RCT_EXPORT_VIEW_PROPERTY(automaticallyAdjustContentInsets, BOOL)
RCT_EXPORT_VIEW_PROPERTY(onBridgeMessage, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onLoadingStart, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onLoadingFinish, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onLoadingError, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onShouldStartLoadWithRequest, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onProgress, RCTDirectEventBlock)

RCT_EXPORT_METHOD(goBack:(nonnull NSNumber *)reactTag)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RCTWKWebView *> *viewRegistry) {
    RCTWKWebView *view = viewRegistry[reactTag];
    if (![view isKindOfClass:[RCTWKWebView class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting RCTWKWebView, got: %@", view);
    } else {
      [view goBack];
    }
  }];
}

RCT_EXPORT_METHOD(goForward:(nonnull NSNumber *)reactTag)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RCTWKWebView *> *viewRegistry) {
    RCTWKWebView *view = viewRegistry[reactTag];
    if (![view isKindOfClass:[RCTWKWebView class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting RCTWKWebView, got: %@", view);
    } else {
      [view goForward];
    }
  }];
}

RCT_EXPORT_METHOD(reload:(nonnull NSNumber *)reactTag)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RCTWKWebView *> *viewRegistry) {
    RCTWKWebView *view = viewRegistry[reactTag];
    if (![view isKindOfClass:[RCTWKWebView class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting RCTWKWebView, got: %@", view);
    } else {
      [view reload];
    }
  }];
}

RCT_EXPORT_METHOD(stopLoading:(nonnull NSNumber *)reactTag)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RCTWKWebView *> *viewRegistry) {
    RCTWKWebView *view = viewRegistry[reactTag];
    if (![view isKindOfClass:[RCTWKWebView class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting RCTWKWebView, got: %@", view);
    } else {
      [view stopLoading];
    }
  }];
}

RCT_EXPORT_METHOD(loadUrl:(nonnull NSNumber *)reactTag
                  value:(NSString*)url)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RCTWKWebView *> *viewRegistry) {
    RCTWKWebView *view = viewRegistry[reactTag];
    if (![view isKindOfClass:[RCTWKWebView class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting RCTWKWebView, got: %@", view);
    } else {
      [view loadUrl: url];
    }
  }];
}

RCT_EXPORT_METHOD(evaluateJavascript:(nonnull NSNumber *)reactTag
                 value:(NSString*)script
                 callback:(RCTResponseSenderBlock)callback)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RCTWKWebView *> *viewRegistry) {
    RCTWKWebView *view = viewRegistry[reactTag];
    if (![view isKindOfClass:[RCTWKWebView class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting RCTWKWebView, got: %@", view);
    } else {
      [view evaluateJavascript: script completionHandler:^(id result, NSError *error) {
        NSString *resultAsString = [NSString stringWithFormat:@"%@", result];
        callback(@[[NSNull null], resultAsString]);
      }];
    }
  }];
}

RCT_EXPORT_METHOD(captureAreaToPNGFile:(nonnull NSNumber *)reactTag
                 path:(NSString*)path 
                 left:(nonnull NSNumber *)left
                 top:(nonnull NSNumber *)top
                 width:(nonnull NSNumber *)width
                 height:(nonnull NSNumber *)height
                 callback:(RCTResponseSenderBlock)callback)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RCTWKWebView *> *viewRegistry) {
    RCTWKWebView *view = viewRegistry[reactTag];
    if (![view isKindOfClass:[RCTWKWebView class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting RCTWKWebView, got: %@", view);
    } else {
      BOOL result = [view captureAreaToPNGFileWithPath: path atXPosition:left atYPosition:top withWidth:width withHeight:height];
      if (result) {
        callback(@[[NSNull null], @"true"]);
      } else {
        callback(@[[NSNull null], @"false"]);
      }
    }
  }];
}

#pragma mark - Exported synchronous methods

- (BOOL)webView:(__unused RCTWKWebView *)webView
shouldStartLoadForRequest:(NSMutableDictionary<NSString *, id> *)request
   withCallback:(RCTDirectEventBlock)callback
{
  _shouldStartLoadLock = [[NSConditionLock alloc] initWithCondition:arc4random()];
  _shouldStartLoad = YES;
  request[@"lockIdentifier"] = @(_shouldStartLoadLock.condition);
  callback(request);
  
  // Block the main thread for a maximum of 250ms until the JS thread returns
  if ([_shouldStartLoadLock lockWhenCondition:0 beforeDate:[NSDate dateWithTimeIntervalSinceNow:.25]]) {
    BOOL returnValue = _shouldStartLoad;
    [_shouldStartLoadLock unlock];
    _shouldStartLoadLock = nil;
    return returnValue;
  } else {
    RCTLogWarn(@"Did not receive response to shouldStartLoad in time, defaulting to YES");
    return YES;
  }
}

RCT_EXPORT_METHOD(startLoadWithResult:(BOOL)result lockIdentifier:(NSInteger)lockIdentifier)
{
  if ([_shouldStartLoadLock tryLockWhenCondition:lockIdentifier]) {
    _shouldStartLoad = result;
    [_shouldStartLoadLock unlockWithCondition:0];
  } else {
    RCTLogWarn(@"startLoadWithResult invoked with invalid lockIdentifier: "
               "got %zd, expected %zd", lockIdentifier, _shouldStartLoadLock.condition);
  }
}

@end
