// FacebookAdsViewController.m
//
// Displays active Facebook ad campaign stats:
//   Name, Impressions, Reach, Frequency, Spend, CTR, CPM
//   Clicks, Video Plays, Landing Page Views,
//   Landing Page Views % of Impressions, Video Plays % of Impressions
//
// Token & Account ID are read from Keychain (stored by TokenSetupViewController).
// Pull-to-refresh supported. Settings button lets user update credentials.
// ─────────────────────────────────────────────────────────────────────────────

#import "FacebookAdsViewController.h"
#import "TokenSetupViewController.h"
#import "KeychainHelper.h"
#import "Constants.h"
#import "AdStat.h"

// ─── Row definitions ────────────────────────────────────────────────────────

typedef NS_ENUM(NSInteger, AdStatRow) {
    AdStatRowImpressions = 0,
    AdStatRowReach,
    AdStatRowFrequency,
    AdStatRowSpend,
    AdStatRowCPM,
    AdStatRowCTR,
    AdStatRowClicks,
    AdStatRowVideoPlays,
    AdStatRowVideoPlaysPct,
    AdStatRowLandingPageViews,
    AdStatRowLandingPageViewsPct,
    AdStatRowCount   // always last
};

static NSString * const kCellID         = @"AdStatCell";
static NSInteger  const kSummarySection = 0;

// ─── Interface ──────────────────────────────────────────────────────────────

@interface FacebookAdsViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView              *tableView;
@property (nonatomic, strong) UIRefreshControl         *refreshControl;
@property (nonatomic, strong) UIActivityIndicatorView  *spinner;
@property (nonatomic, strong) UILabel                  *emptyLabel;
@property (nonatomic, strong) NSMutableArray<AdStat *> *stats;

@property (nonatomic, copy)   NSString *accessToken;
@property (nonatomic, copy)   NSString *adAccountID;

// Computed summary values
@property (nonatomic, assign) long long  totalImpressions;
@property (nonatomic, assign) long long  totalReach;
@property (nonatomic, assign) long long  totalClicks;
@property (nonatomic, assign) long long  totalVideoPlays;
@property (nonatomic, assign) long long  totalLandingPageViews;
@property (nonatomic, assign) double     totalSpend;
@property (nonatomic, assign) double     avgCTR;
@property (nonatomic, assign) double     avgFrequency;
@property (nonatomic, assign) double     overallCPM;

@end

// ─── Implementation ─────────────────────────────────────────────────────────

@implementation FacebookAdsViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Active Ads";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.stats = [NSMutableArray array];

    [self buildNavBar];
    [self buildTableView];
    [self buildSpinner];
    [self buildEmptyLabel];

    if ([self loadCredentials]) {
        [self refresh];
    }
}

#pragma mark - Credential Loading

- (BOOL)loadCredentials {
    self.accessToken  = [KeychainHelper loadValueForKey:kFBAccessTokenKey];
    self.adAccountID  = [KeychainHelper loadValueForKey:kFBAdAccountIDKey];

    if (!self.accessToken || !self.adAccountID) {
        [self showError:@"No credentials found. Tap ⚙ to set your token and account ID."];
        return NO;
    }
    return YES;
}

#pragma mark - UI Construction

- (void)buildNavBar {
    UIBarButtonItem *settingsBtn = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"gear"]
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(didTapSettings)];
    self.navigationItem.rightBarButtonItem = settingsBtn;
}

- (void)buildTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds
                                                  style:UITableViewStyleInsetGrouped];
    self.tableView.dataSource = self;
    self.tableView.delegate   = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.rowHeight = 44.0;

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = self.refreshControl;

    [self.view addSubview:self.tableView];
}

- (void)buildSpinner {
    self.spinner = [[UIActivityIndicatorView alloc]
                    initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.spinner.center = self.view.center;
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
}

- (void)buildEmptyLabel {
    self.emptyLabel = [[UILabel alloc] initWithFrame:self.view.bounds];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.font = [UIFont systemFontOfSize:15];
    self.emptyLabel.textColor = [UIColor secondaryLabelColor];
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];
}

#pragma mark - Actions

- (void)refresh {
    if (![self loadCredentials]) {
        [self.refreshControl endRefreshing];
        return;
    }
    [self.stats removeAllObjects];
    [self.tableView reloadData];
    self.emptyLabel.hidden = YES;
    [self.spinner startAnimating];
    [self fetchActiveAds];
}

- (void)didTapSettings {
    TokenSetupViewController *vc = [[TokenSetupViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - Summary Computation

- (void)computeSummary {
    self.totalImpressions      = 0;
    self.totalReach            = 0;
    self.totalClicks           = 0;
    self.totalVideoPlays       = 0;
    self.totalLandingPageViews = 0;
    self.totalSpend            = 0.0;

    for (AdStat *stat in self.stats) {
        self.totalImpressions      += [stat.impressions longLongValue];
        self.totalReach            += [stat.reach longLongValue];
        self.totalClicks           += [stat.clicks longLongValue];
        self.totalVideoPlays       += [stat.videoPlays longLongValue];
        self.totalLandingPageViews += [stat.landingPageViews longLongValue];
        self.totalSpend            += [stat.spend doubleValue];
    }

    NSUInteger count = self.stats.count;

    // CTR = total clicks / total impressions
    self.avgCTR = self.totalImpressions > 0
        ? ((double)self.totalClicks / self.totalImpressions) * 100.0
        : 0.0;

    // CPM = (total spend / total impressions) * 1000
    self.overallCPM = self.totalImpressions > 0
        ? (self.totalSpend / self.totalImpressions) * 1000.0
        : 0.0;

    // CORRECT — matches Facebook's calculation: impressions / reach
    self.avgFrequency = self.totalReach > 0
        ? (double)self.totalImpressions / (double)self.totalReach
        : 0.0;}

#pragma mark - Step 1: Fetch active ads list

- (void)fetchActiveAds {
    NSString *urlStr = [NSString stringWithFormat:
        @"%@/%@/ads"
        @"?fields=id,name"
        @"&effective_status=[\"ACTIVE\"]"
        @"&limit=50"
        @"&access_token=%@",
        kFBGraphBaseURL,
        self.adAccountID,
        self.accessToken];

    NSURL *url = [NSURL URLWithString:
        [urlStr stringByAddingPercentEncodingWithAllowedCharacters:
         [NSCharacterSet URLQueryAllowedCharacterSet]]];

    [[[NSURLSession sharedSession] dataTaskWithURL:url
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

        if (error) {
            [self finishWithError:error.localizedDescription];
            return;
        }

        NSError *jsonError = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data ?: [NSData data]
                                                             options:0
                                                               error:&jsonError];
        if (json[@"error"]) {
            NSString *msg = json[@"error"][@"message"] ?: @"Unknown Facebook API error.";
            [self finishWithError:msg];
            return;
        }

        NSArray *ads = json[@"data"];
        if (!ads || ads.count == 0) {
            [self finishWithError:@"No active ads found for this account."];
            return;
        }

        [self fetchInsightsForAds:ads];

    }] resume];
}

#pragma mark - Step 2: Fetch insights for each ad

- (void)fetchInsightsForAds:(NSArray<NSDictionary *> *)ads {
    dispatch_group_t  group   = dispatch_group_create();
    dispatch_queue_t  queue   = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    NSMutableArray   *results = [NSMutableArray array];

    for (NSDictionary *ad in ads) {
        dispatch_group_enter(group);

        NSString *adID   = ad[@"id"]   ?: @"";
        NSString *adName = ad[@"name"] ?: @"Unknown Ad";

        // video_p100_watched_actions is the correct field for 100% completions
        NSString *insightFields =
            @"impressions,reach,frequency,spend,cpm,ctr,clicks,"
             "video_p100_watched_actions,actions";

        NSString *urlStr = [NSString stringWithFormat:
            @"%@/%@/insights"
            @"?fields=%@"
            //@"&date_preset=last_30d"
            @"&date_preset=maximum"

            @"&access_token=%@",
            kFBGraphBaseURL,
            adID,
            insightFields,
            self.accessToken];

        NSURL *url = [NSURL URLWithString:urlStr];

        [[[NSURLSession sharedSession] dataTaskWithURL:url
            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

            void (^leaveGroup)(void) = ^{ dispatch_group_leave(group); };

            if (error || !data) {
                NSLog(@"[Insights ERROR] ad %@: %@", adID, error.localizedDescription);
                leaveGroup();
                return;
            }

            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data
                                                                 options:0
                                                                   error:nil];

            NSDictionary *insight = [json[@"data"] firstObject];

            AdStat *stat = [[AdStat alloc] init];
            stat.adID        = adID;
            stat.name        = adName;
            stat.impressions = insight[@"impressions"] ?: @"0";
            stat.reach       = insight[@"reach"]       ?: @"0";
            stat.frequency   = insight[@"frequency"]   ?: @"0";
            stat.spend       = insight[@"spend"]       ?: @"0";
            stat.cpm         = insight[@"cpm"]         ?: @"0";
            stat.ctr         = insight[@"ctr"]         ?: @"0";
            stat.clicks      = insight[@"clicks"]      ?: @"0";

            // Landing page views — from standard actions array
            NSArray *actions = insight[@"actions"] ?: @[];
            NSInteger totalLandingPageViews = 0;
            for (NSDictionary *action in actions) {
                if ([action[@"action_type"] isEqualToString:@"landing_page_view"]) {
                    totalLandingPageViews += [action[@"value"] integerValue];
                }
            }

            // 100% video completions — separate top-level field from FB API
            NSArray *videoP100Actions = insight[@"video_p100_watched_actions"] ?: @[];
            NSInteger totalVideoPlays = 0;
            for (NSDictionary *action in videoP100Actions) {
                totalVideoPlays += [action[@"value"] integerValue];
            }

            NSLog(@"[Video P100 for '%@'] %@", adName, videoP100Actions);
            NSLog(@"[Actions for '%@'] %@", adName, actions);

            stat.videoPlays       = @(totalVideoPlays).stringValue;
            stat.landingPageViews = @(totalLandingPageViews).stringValue;

            [stat computePercentages];

            @synchronized(results) {
                [results addObject:stat];
            }
            leaveGroup();

        }] resume];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [results sortUsingDescriptors:
            @[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];

        self.stats = results;
        [self computeSummary];
        [self.spinner stopAnimating];
        [self.refreshControl endRefreshing];

        if (self.stats.count == 0) {
            self.emptyLabel.text   = @"No data returned for active ads.";
            self.emptyLabel.hidden = NO;
        }
        [self.tableView reloadData];
    });
}

#pragma mark - Error Helper

- (void)finishWithError:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.spinner stopAnimating];
        [self.refreshControl endRefreshing];
        self.emptyLabel.text   = message;
        self.emptyLabel.hidden = NO;
    });
}

- (void)showError:(NSString *)message {
    self.emptyLabel.text   = message;
    self.emptyLabel.hidden = NO;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.stats.count == 0) return 0;
    return (NSInteger)self.stats.count + 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return AdStatRowCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == kSummarySection) {
        return [NSString stringWithFormat:@"Summary — %lu Active Ads",
                (unsigned long)self.stats.count];
    }
    return self.stats[(NSUInteger)(section - 1)].name;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:kCellID];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    NSString *label = nil;
    NSString *value = nil;
    BOOL isSummary = (indexPath.section == kSummarySection);

    if (isSummary) {
        cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
        switch ((AdStatRow)indexPath.row) {
            case AdStatRowImpressions:
                label = @"Total Impressions";
                value = [self formattedInteger:@(self.totalImpressions).stringValue];
                break;
            case AdStatRowReach:
                label = @"Total Reach*";
                value = [self formattedInteger:@(self.totalReach).stringValue];
                break;
            case AdStatRowFrequency:
                label = @"Avg Frequency";
                value = [NSString stringWithFormat:@"%.2f", self.avgFrequency];
                break;
            case AdStatRowSpend:
                label = @"Total Spend";
                value = [NSString stringWithFormat:@"$%.2f", self.totalSpend];
                break;
            case AdStatRowCPM:
                label = @"Overall CPM";
                value = [NSString stringWithFormat:@"$%.2f", self.overallCPM];
                break;
            case AdStatRowCTR:
                label = @"Overall CTR";
                value = [NSString stringWithFormat:@"%.2f%%", self.avgCTR];
                break;
            case AdStatRowClicks:
                label = @"Total Clicks";
                value = [self formattedInteger:@(self.totalClicks).stringValue];
                break;
            case AdStatRowVideoPlays:
                label = @"Total Video Plays (100%)";
                value = [self formattedInteger:@(self.totalVideoPlays).stringValue];
                break;
            case AdStatRowVideoPlaysPct:
                label = @"Video Plays % of Impr.";
                value = self.totalImpressions > 0
                    ? [NSString stringWithFormat:@"%.1f%%",
                       (double)self.totalVideoPlays / self.totalImpressions * 100.0]
                    : @"N/A";
                break;
            case AdStatRowLandingPageViews:
                label = @"Total Landing Page Views";
                value = [self formattedInteger:@(self.totalLandingPageViews).stringValue];
                break;
            case AdStatRowLandingPageViewsPct:
                label = @"Landing Page % of Impr.";
                value = self.totalImpressions > 0
                    ? [NSString stringWithFormat:@"%.1f%%",
                       (double)self.totalLandingPageViews / self.totalImpressions * 100.0]
                    : @"N/A";
                break;
            case AdStatRowCount:
                break;
        }

    } else {
        cell.textLabel.font = [UIFont systemFontOfSize:15];
        AdStat *stat = self.stats[(NSUInteger)(indexPath.section - 1)];
        switch ((AdStatRow)indexPath.row) {
            case AdStatRowImpressions:
                label = @"Impressions";
                value = [self formattedInteger:stat.impressions];
                break;
            case AdStatRowReach:
                label = @"Reach";
                value = [self formattedInteger:stat.reach];
                break;
            case AdStatRowFrequency:
                label = @"Frequency";
                value = [NSString stringWithFormat:@"%.2f", [stat.frequency doubleValue]];
                break;
            case AdStatRowSpend:
                label = @"Spend";
                value = [NSString stringWithFormat:@"$%.2f", [stat.spend doubleValue]];
                break;
            case AdStatRowCPM:
                label = @"CPM";
                value = [NSString stringWithFormat:@"$%.2f", [stat.cpm doubleValue]];
                break;
            case AdStatRowCTR:
                label = @"CTR";
                value = [NSString stringWithFormat:@"%.2f%%", [stat.ctr doubleValue]];
                break;
            case AdStatRowClicks:
                label = @"Clicks";
                value = [self formattedInteger:stat.clicks];
                break;
            case AdStatRowVideoPlays:
                label = @"Video Plays (100%)";
                value = [self formattedInteger:stat.videoPlays];
                break;
            case AdStatRowVideoPlaysPct:
                label = @"Video Plays % of Impr.";
                value = stat.videoPlaysPct;
                break;
            case AdStatRowLandingPageViews:
                label = @"Landing Page Views";
                value = [self formattedInteger:stat.landingPageViews];
                break;
            case AdStatRowLandingPageViewsPct:
                label = @"Landing Page % of Impr.";
                value = stat.landingPageViewsPct;
                break;
            case AdStatRowCount:
                break;
        }
    }

    cell.textLabel.text       = label;
    cell.detailTextLabel.text = value;

    // Default color
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];

    // Highlight percentage rows
    if (indexPath.row == AdStatRowVideoPlaysPct) {
        BOOL isZeroOrNA = [value isEqualToString:@"N/A"] || [value isEqualToString:@"0.0%"];
        cell.detailTextLabel.textColor = isZeroOrNA
            ? [UIColor secondaryLabelColor]
            : [UIColor systemGreenColor];
    } else if (indexPath.row == AdStatRowLandingPageViewsPct) {
        BOOL isZeroOrNA = [value isEqualToString:@"N/A"] || [value isEqualToString:@"0.0%"];
        cell.detailTextLabel.textColor = isZeroOrNA
            ? [UIColor secondaryLabelColor]
            : [UIColor systemBlueColor];
    }

    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == kSummarySection) {
        return @"Totals and averages across all active ads · Last 30 days · *Reach summed across ads (may overcount overlap)";
    }
    return [NSString stringWithFormat:@"Ad ID: %@  ·  Last 30 days",
            self.stats[(NSUInteger)(section - 1)].adID];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Formatting Helper

- (NSString *)formattedInteger:(NSString *)raw {
    long long val = [raw longLongValue];
    if (val == 0) return @"0";
    NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
    f.numberStyle = NSNumberFormatterDecimalStyle;
    return [f stringFromNumber:@(val)] ?: raw;
}

@end
