#import "RCTView.h"

@class RCTWKWebView;

/**
 * Special scheme used to pass messages to the injectedJavaScript
 * code without triggering a page load. Usage:
 *
 *   window.location.href = RCTJSNavigationScheme + '://hello'
 */
extern NSString *const RCTJSNavigationScheme;

@protocol RCTWKWebViewDelegate <NSObject>

- (BOOL)webView:(RCTWKWebView *)webView
shouldStartLoadForRequest:(NSMutableDictionary<NSString *, id> *)request
   withCallback:(RCTDirectEventBlock)callback;

@end

@interface RCTWKWebView : RCTView

@property (nonatomic, weak) id<RCTWKWebViewDelegate> delegate;

@property (nonatomic, copy) NSDictionary *source;
@property (nonatomic, assign) UIEdgeInsets contentInset;
@property (nonatomic, assign) BOOL automaticallyAdjustContentInsets;
@property (nonatomic, copy) NSString *injectedJavaScript;

- (void)goForward;
- (void)goBack;
- (void)reload;
- (void)stopLoading;
- (void)loadUrl:(NSString *)url;
- (void)evaluateJavascript:(NSString *)script completionHandler:(void (^)(id,
                                     NSError *error))handler;
- (BOOL)captureAreaToPNGFileWithPath:(NSString *)path atXPosition:(nonnull NSNumber *)left atYPosition:(nonnull NSNumber *)top withWidth:(nonnull NSNumber *)width withHeight:(nonnull NSNumber *)height;

@end
