// TokenSetupViewController.m
#import "TokenSetupViewController.h"
#import "KeychainHelper.h"
#import "Constants.h"
#import "FacebookAdsViewController.h"

@interface TokenSetupViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UIScrollView      *scrollView;
@property (nonatomic, strong) UILabel           *titleLabel;
@property (nonatomic, strong) UILabel           *tokenLabel;
@property (nonatomic, strong) UITextView        *tokenField;   // multi-line — tokens are long
@property (nonatomic, strong) UILabel           *accountLabel;
@property (nonatomic, strong) UITextField       *accountField;
@property (nonatomic, strong) UILabel           *hintLabel;
@property (nonatomic, strong) UIButton          *saveButton;

// Add this line:
- (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font frame:(CGRect)frame;

@end

@implementation TokenSetupViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    //diag added
    self.view.backgroundColor = [UIColor redColor];

    self.title = @"Facebook Setup";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [self buildUI];

    // Pre-fill if values already exist (e.g. user is updating)
    NSString *existingToken   = [KeychainHelper loadValueForKey:kFBAccessTokenKey];
    NSString *existingAccount = [KeychainHelper loadValueForKey:kFBAdAccountIDKey];
    if (existingToken)   self.tokenField.text   = existingToken;
    if (existingAccount) self.accountField.text = existingAccount;

    // Keyboard avoidance
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardChanged:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UI

- (void)buildUI {
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:self.scrollView];

    CGFloat pad = 20.0;
    CGFloat w   = self.view.bounds.size.width - pad * 2;
    CGFloat y   = 40.0;

    // Title
    self.titleLabel = [self labelWithText:@"Enter Facebook Credentials"
                                     font:[UIFont boldSystemFontOfSize:20]
                                    frame:CGRectMake(pad, y, w, 28)];
    [self.scrollView addSubview:self.titleLabel];
    y += 44;

    // Hint
    self.hintLabel = [self labelWithText:
        @"Token: generate at developers.facebook.com/tools/explorer\n"
         "Permissions needed: ads_read, read_insights\n\n"
         "Account ID: found in Meta Business Manager (format: act_XXXXXXXXX)"
                                    font:[UIFont systemFontOfSize:13]
                                   frame:CGRectMake(pad, y, w, 72)];
    self.hintLabel.numberOfLines = 0;
    self.hintLabel.textColor = [UIColor secondaryLabelColor];
    [self.scrollView addSubview:self.hintLabel];
    y += 84;

    // Token label + field
    self.tokenLabel = [self labelWithText:@"Access Token"
                                     font:[UIFont systemFontOfSize:15]
                                    frame:CGRectMake(pad, y, w, 22)];
    [self.scrollView addSubview:self.tokenLabel];
    y += 28;

    self.tokenField = [[UITextView alloc] initWithFrame:CGRectMake(pad, y, w, 100)];
    self.tokenField.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.tokenField.layer.borderColor  = [UIColor separatorColor].CGColor;
    self.tokenField.layer.borderWidth  = 1.0;
    self.tokenField.layer.cornerRadius = 8.0;
    self.tokenField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.tokenField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.tokenField.textContainerInset = UIEdgeInsetsMake(8, 8, 8, 8);
    [self.scrollView addSubview:self.tokenField];
    y += 112;

    // Account ID label + field
    self.accountLabel = [self labelWithText:@"Ad Account ID  (e.g. act_123456789)"
                                       font:[UIFont systemFontOfSize:15]
                                      frame:CGRectMake(pad, y, w, 22)];
    [self.scrollView addSubview:self.accountLabel];
    y += 28;

    self.accountField = [[UITextField alloc] initWithFrame:CGRectMake(pad, y, w, 44)];
    self.accountField.placeholder          = @"act_XXXXXXXXX";
    self.accountField.borderStyle          = UITextBorderStyleRoundedRect;
    self.accountField.font                 = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
    self.accountField.autocorrectionType   = UITextAutocorrectionTypeNo;
    self.accountField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.accountField.returnKeyType        = UIReturnKeyDone;
    self.accountField.delegate             = self;
    [self.scrollView addSubview:self.accountField];
    y += 60;

    // Save button
    self.saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.saveButton.frame = CGRectMake(pad, y, w, 50);
    [self.saveButton setTitle:@"Save & Continue" forState:UIControlStateNormal];
    self.saveButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    self.saveButton.backgroundColor = [UIColor systemBlueColor];
    [self.saveButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.saveButton.layer.cornerRadius = 12.0;
    [self.saveButton addTarget:self action:@selector(didTapSave) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:self.saveButton];
    y += 70;

    self.scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, y);
}

- (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font frame:(CGRect)frame {
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.text = text;
    label.font = font;
    label.numberOfLines = 1;
    return label;
}

#pragma mark - Actions

- (void)didTapSave {
    NSString *token   = [self.tokenField.text stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *account = [self.accountField.text stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (token.length == 0 || account.length == 0) {
        [self showAlert:@"Missing Fields" message:@"Please enter both the access token and ad account ID."];
        return;
    }

    if (![account hasPrefix:@"act_"]) {
        [self showAlert:@"Invalid Account ID" message:@"Ad Account ID must start with 'act_' (e.g. act_123456789)."];
        return;
    }

    BOOL tokenSaved   = [KeychainHelper saveValue:token   forKey:kFBAccessTokenKey];
    BOOL accountSaved = [KeychainHelper saveValue:account forKey:kFBAdAccountIDKey];

    if (!tokenSaved || !accountSaved) {
        [self showAlert:@"Keychain Error" message:@"Could not save credentials. Please try again."];
        return;
    }

    // Navigate to the ads dashboard
    FacebookAdsViewController *adsVC = [[FacebookAdsViewController alloc] init];
    [self.navigationController pushViewController:adsVC animated:YES];
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Keyboard

- (void)keyboardChanged:(NSNotification *)note {
    CGRect keyboardFrame = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat keyboardHeight = CGRectGetHeight(keyboardFrame);
    self.scrollView.contentInset = UIEdgeInsetsMake(0, 0, keyboardHeight, 0);
}

@end
