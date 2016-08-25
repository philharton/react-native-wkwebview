#import "RCTWKWebView.h"

#import <WebKit/WebKit.h>
#import <UIKit/UIKit.h>

#import "RCTAutoInsetsProtocol.h"
#import "RCTConvert.h"
#import "RCTEventDispatcher.h"
#import "RCTLog.h"
#import "RCTUtils.h"
#import "RCTView.h"
#import "UIView+React.h"

@interface RCTWKWebView () <WKNavigationDelegate, RCTAutoInsetsProtocol>

@property (nonatomic, copy) RCTDirectEventBlock onBridgeMessage;
@property (nonatomic, copy) RCTDirectEventBlock onLoadingStart;
@property (nonatomic, copy) RCTDirectEventBlock onLoadingFinish;
@property (nonatomic, copy) RCTDirectEventBlock onLoadingError;
@property (nonatomic, copy) RCTDirectEventBlock onShouldStartLoadWithRequest;
@property (nonatomic, copy) RCTDirectEventBlock onProgress;

@end

@implementation RCTWKWebView
{
  WKWebView *_webView;
  NSString *_injectedJavaScript;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if ((self = [super initWithFrame:frame])) {
    super.backgroundColor = [UIColor clearColor];
    _automaticallyAdjustContentInsets = YES;
    _contentInset = UIEdgeInsetsZero;

    // from: http://www.joshuakehn.com/2014/10/29/using-javascript-with-wkwebview-in-ios-8.html
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc]init];
    WKUserContentController* controller = [[WKUserContentController alloc]init];
    [controller addScriptMessageHandler:self name:@"observe"];
    config.userContentController= controller;
    config.allowsInlineMediaPlayback = YES;
    config.requiresUserActionForMediaPlayback = NO;

    _webView = [[WKWebView alloc] initWithFrame:self.bounds configuration:config];
    _webView.navigationDelegate = self;
    [_webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
    [self addSubview:_webView];
  }
  return self;
}

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message
{
  if (_onBridgeMessage) {
    NSMutableDictionary *event = [NSMutableDictionary
      dictionaryWithDictionary:@{
      @"message": message.body
    }];
    _onBridgeMessage(event);
  }
}

RCT_NOT_IMPLEMENTED(- (instancetype)initWithCoder:(NSCoder *)aDecoder)

- (void)loadRequest:(NSURLRequest *)request {
  if (request.URL && _sendCookies) {
    NSDictionary *cookies = [NSHTTPCookie requestHeaderFieldsWithCookies:[[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:request.URL]];
    if ([cookies objectForKey:@"Cookie"]) {
      NSMutableURLRequest *mutableRequest = request.mutableCopy;
      [mutableRequest addValue:cookies[@"Cookie"] forHTTPHeaderField:@"Cookie"];
      request = mutableRequest;
    }
  }

  [_webView loadRequest:request];
}

- (void)goForward
{
  [_webView goForward];
}

- (void)goBack
{
  [_webView goBack];
}

- (void)reload
{
  NSURLRequest *request = [RCTConvert NSURLRequest:self.source];
  if (request.URL && !_webView.URL.absoluteString.length) {
    [self loadRequest:request];
  }
  else {
    [_webView reload];
  }
}

- (void)stopLoading
{
  [_webView stopLoading];
}

- (void)loadUrl:(NSString *)url
{
  NSURL *nsUrl = [NSURL URLWithString: url]; 
  NSURLRequest *request = [NSURLRequest requestWithURL:nsUrl]; 
  [_webView loadRequest:request];
}

- (void)evaluateJavascript:(NSString *)script completionHandler:(void (^)(id,
                                     NSError *error))handler
{
  [_webView evaluateJavaScript:script completionHandler:handler];
}

- (BOOL)captureAreaToPNGFileWithPath:(NSString *)path atXPosition:(nonnull NSNumber *)left atYPosition:(nonnull NSNumber *)top withWidth:(nonnull NSNumber *)width withHeight:(nonnull NSNumber *)height
{
  CGSize size = CGSizeMake(width.floatValue, height.floatValue);
  UIGraphicsBeginImageContextWithOptions(size, self.opaque, 0.0f);
  CGRect bounds = CGRectOffset(self.bounds, -left.floatValue, 0);
  [self drawViewHierarchyInRect:bounds afterScreenUpdates:NO];
  UIImage * snapshotImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  NSData *binaryImageData = UIImagePNGRepresentation(snapshotImage);
  return [binaryImageData writeToFile:path atomically:YES];
}

- (void)setSource:(NSDictionary *)source
{
  if (![_source isEqualToDictionary:source]) {
    _source = [source copy];

    // Check for a static html source first
    NSString *html = [RCTConvert NSString:source[@"html"]];
    if (html) {
      NSURL *baseURL = [RCTConvert NSURL:source[@"baseUrl"]];
      if (!baseURL) {
        baseURL = [NSURL URLWithString:@"about:blank"];
      }
      [_webView loadHTMLString:html baseURL:baseURL];
      return;
    }

    NSURLRequest *request = [RCTConvert NSURLRequest:source];
    // Because of the way React works, as pages redirect, we actually end up
    // passing the redirect urls back here, so we ignore them if trying to load
    // the same url. We'll expose a call to 'reload' to allow a user to load
    // the existing page.
    if ([request.URL isEqual:_webView.URL]) {
      return;
    }
    if (!request.URL) {
      // Clear the webview
      [_webView loadHTMLString:@"" baseURL:nil];
      return;
    }
    [self loadRequest:request];
  }
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  _webView.frame = self.bounds;
}

- (void)setContentInset:(UIEdgeInsets)contentInset
{
  _contentInset = contentInset;
  [RCTView autoAdjustInsetsForView:self
                    withScrollView:_webView.scrollView
                      updateOffset:NO];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
  CGFloat alpha = CGColorGetAlpha(backgroundColor.CGColor);
  self.opaque = _webView.opaque = (alpha == 1.0);
  _webView.backgroundColor = backgroundColor;
}

- (UIColor *)backgroundColor
{
  return _webView.backgroundColor;
}

- (NSMutableDictionary<NSString *, id> *)baseEvent
{
  NSMutableDictionary<NSString *, id> *event = [[NSMutableDictionary alloc] initWithDictionary:@{
    @"url": _webView.URL.absoluteString ?: @"",
    @"loading" : @(_webView.loading),
    @"title": _webView.title,
    @"canGoBack": @(_webView.canGoBack),
    @"canGoForward" : @(_webView.canGoForward),
  }];

  return event;
}

- (void)refreshContentInset
{
  [RCTView autoAdjustInsetsForView:self
                    withScrollView:_webView.scrollView
                      updateOffset:YES];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  if ([keyPath isEqualToString:@"estimatedProgress"]) {
    if (!_onProgress) {
      return;
    }
    _onProgress(@{@"progress": [change objectForKey:NSKeyValueChangeNewKey]});
  }
}

- (void)dealloc
{
  @try {
    [_webView removeObserver:self forKeyPath:@"estimatedProgress"];
  }
  @catch (NSException * __unused exception) {}
}

#pragma mark - WKNavigationDelegate methods

- (void)webView:(__unused WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
  NSURLRequest *request = navigationAction.request;
  NSURL* url = request.URL;
  NSString* scheme = url.scheme;

  BOOL isJSNavigation = [scheme isEqualToString:RCTJSNavigationScheme];

  // http://stackoverflow.com/questions/25713069/why-is-wkwebview-not-opening-links-with-target-blank
  // https://github.com/sticksen/STKWebKitViewController/blob/f4a39fcefcae24e2f82c45fd43e9a19cc09a29e4/Pod/Classes/STKWebKitViewController.m
  if (!navigationAction.targetFrame) {
    [webView loadRequest:navigationAction.request];
    return decisionHandler(WKNavigationActionPolicyAllow);
  }

  // skip this for the JS Navigation handler
  if (!isJSNavigation && _onShouldStartLoadWithRequest) {
    NSMutableDictionary<NSString *, id> *event = [self baseEvent];
    [event addEntriesFromDictionary: @{
      @"url": (request.URL).absoluteString,
      @"navigationType": @(navigationAction.navigationType)
    }];
    if (![self.delegate webView:self
      shouldStartLoadForRequest:event
                   withCallback:_onShouldStartLoadWithRequest]) {
      return decisionHandler(WKNavigationActionPolicyCancel);
    }
  }

  if (_onLoadingStart) {
    // We have this check to filter out iframe requests and whatnot
    BOOL isTopFrame = [url isEqual:request.mainDocumentURL];
    if (isTopFrame) {
      NSMutableDictionary<NSString *, id> *event = [self baseEvent];
      [event addEntriesFromDictionary: @{
        @"url": url.absoluteString,
        @"navigationType": @(navigationAction.navigationType)
      }];
      _onLoadingStart(event);
    }
  }

  if (isJSNavigation) {
    decisionHandler(WKNavigationActionPolicyCancel);
  }
  else if (navigationAction.targetFrame && ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"])) {
    decisionHandler(WKNavigationActionPolicyAllow);
  }
  else {
    if (![scheme isEqualToString:@"about"]) {
        [[UIApplication sharedApplication] openURL:url];
    }
    decisionHandler(WKNavigationActionPolicyAllow);
  }
}

- (void)webView:(__unused WKWebView *)webView didFailProvisionalNavigation:(__unused WKNavigation *)navigation withError:(NSError *)error
{
  if (_onLoadingError) {
    if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) {
      // NSURLErrorCancelled is reported when a page has a redirect OR if you load
      // a new URL in the WebView before the previous one came back. We can just
      // ignore these since they aren't real errors.
      // http://stackoverflow.com/questions/1024748/how-do-i-fix-nsurlerrordomain-error-999-in-iphone-3-0-os
      return;
    }

    NSMutableDictionary<NSString *, id> *event = [self baseEvent];
    [event addEntriesFromDictionary:@{
      @"domain": error.domain,
      @"code": @(error.code),
      @"description": error.localizedDescription,
    }];
    _onLoadingError(event);
  }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(__unused WKNavigation *)navigation
{
  if (_injectedJavaScript != nil) {
    [webView evaluateJavaScript:_injectedJavaScript completionHandler:^(id result, NSError *error) {
      NSMutableDictionary<NSString *, id> *event = [self baseEvent];
      event[@"jsEvaluationValue"] = [NSString stringWithFormat:@"%@", result];
      _onLoadingFinish(event);
    }];
  }
  // we only need the final 'finishLoad' call so only fire the event when we're actually done loading.
  else if (_onLoadingFinish && !webView.loading && ![webView.URL.absoluteString isEqualToString:@"about:blank"]) {
    _onLoadingFinish([self baseEvent]);
  }
}

@end
