// AdStat.m
#import "AdStat.h"

@implementation AdStat

- (void)computePercentages {
    double imp = [self.impressions doubleValue];
    if (imp <= 0) {
        self.landingPageViewsPct = @"N/A";
        self.videoPlaysPct       = @"N/A";
        return;
    }

    double lpv = [self.landingPageViews doubleValue];
    double vp  = [self.videoPlays doubleValue];

    self.landingPageViewsPct = (lpv > 0)
        ? [NSString stringWithFormat:@"%.1f%%", (lpv / imp) * 100.0]
        : @"0.0%";

    self.videoPlaysPct = (vp > 0)
        ? [NSString stringWithFormat:@"%.1f%%", (vp / imp) * 100.0]
        : @"0.0%";
}

@end
