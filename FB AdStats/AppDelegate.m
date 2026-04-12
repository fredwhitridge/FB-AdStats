// AppDelegate.m
// Entry point — routes to TokenSetupViewController if no credentials are stored,
// or directly to FacebookAdsViewController if credentials exist in Keychain.

#import "AppDelegate.h"
#import "KeychainHelper.h"
#import "Constants.h"
#import "TokenSetupViewController.h"
#import "FacebookAdsViewController.h"

@interface AppDelegate ()
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    return YES;
}
@end
