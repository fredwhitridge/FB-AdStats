// TokenSetupViewController.h
#import <UIKit/UIKit.h>

/// Shown when no token/account-ID is found in Keychain.
/// User pastes their FB access token and ad account ID, then taps Save.
@interface TokenSetupViewController : UIViewController
- (UILabel *)labelWithText:(NSString *)text;

@end
