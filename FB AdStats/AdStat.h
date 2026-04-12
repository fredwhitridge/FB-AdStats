// AdStat.h
#import <Foundation/Foundation.h>

@interface AdStat : NSObject

@property (nonatomic, strong) NSString *adID;
@property (nonatomic, strong) NSString *name;

// Raw metrics (strings from API)
@property (nonatomic, strong) NSString *impressions;
@property (nonatomic, strong) NSString *reach;
@property (nonatomic, strong) NSString *frequency;
@property (nonatomic, strong) NSString *spend;
@property (nonatomic, strong) NSString *ctr;
@property (nonatomic, strong) NSString *clicks;
@property (nonatomic, strong) NSString *landingPageViews;
@property (nonatomic, strong) NSString *videoPlays;
@property (nonatomic, strong) NSString *cpm;


// Computed percentage strings (set after parsing)
@property (nonatomic, strong) NSString *landingPageViewsPct;   // landing_page_views / impressions
@property (nonatomic, strong) NSString *videoPlaysPct;         // video_plays / impressions

/// Populate pct fields from raw numeric strings. Call after all raw fields are set.
- (void)computePercentages;

@end
