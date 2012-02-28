/* 
 * Copyright (c) 2007-2009 Patrick Quinn-Graham, Christoph Nadig
 * 
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import <Cocoa/Cocoa.h>

// used in resetMode
#define CWResetStatisticsModeDay        0
#define CWResetStatisticsModeWeek       1
#define CWResetStatisticsModeMonth      2

// used in trafficWarningMode
#define CWTrafficWarningModeAll         0
#define CWTrafficWarningModeReceived    1
#define CWTrafficWarningModeSent        2

// used in trafficWarningUnit
#define CWTrafficWarningUnitMB          0
#define CWTrafficWarningUnitGB          1


@interface CWPreferences : NSObject {

    // collect usage statistics
    BOOL storeUsageHistory;

    // statistics settings
    BOOL resetStatistics;
    NSInteger resetMode;
    NSInteger dayPeriod;
    NSInteger weekPeriod;
    NSInteger monthPeriod;
    NSInteger dayOfWeek;
    NSInteger dayOfMonth;
    
    // traffic warning settings
    BOOL trafficWarning;
    NSInteger trafficWarningMode;
    NSInteger trafficWarningAmount;
    NSInteger trafficWarningUnit;
    NSInteger trafficWarningInterval;

    // show connection time in status bar if true
    BOOL showConnectionTime;
	
	// Connect automaticly
	BOOL autoconnect;

    // APN settings
    NSString *presetApn;

}

// accessors
- (BOOL)storeUsageHistory;
- (void)setStoreUsageHistory:(BOOL)newStoreUsageHistory;
- (BOOL)resetStatistics;
- (void)setResetStatistics:(BOOL)newResetStatistics;
- (NSInteger)resetMode;
- (void)setResetMode:(NSInteger)newResetMode;
- (NSInteger)dayPeriod;
- (void)setDayPeriod:(NSInteger)newDayPeriod;
- (NSInteger)weekPeriod;
- (void)setWeekPeriod:(NSInteger)newWeekPeriod;
- (NSInteger)monthPeriod;
- (void)setMonthPeriod:(NSInteger)newMonthPeriod;
- (NSInteger)dayOfWeek;
- (void)setDayOfWeek:(NSInteger)newDayOfWeek;
- (NSInteger)dayOfMonth;
- (void)setDayOfMonth:(NSInteger)newDayOfMonth;
- (BOOL)trafficWarning;
- (void)setTrafficWarning:(BOOL)newTrafficWarning;
- (NSInteger)trafficWarningMode;
- (void)setTrafficWarningMode:(NSInteger)newTrafficWarningMode;
- (NSInteger)trafficWarningAmount;
- (void)setTrafficWarningAmount:(NSInteger)newTrafficWarningAmount;
- (NSInteger)trafficWarningUnit;
- (void)setTrafficWarningUnit:(NSInteger)newTrafficWarningUnit;
- (NSInteger)trafficWarningInterval;
- (void)setTrafficWarningInterval:(NSInteger)newTrafficWarningInterval;
- (BOOL)showConnectionTime;
- (void)setShowConnectionTime:(BOOL)newShowConnectionTime;
- (BOOL)autoconnect;
- (void)setAutoconnect:(BOOL)newAutoconnect;
- (NSString *)presetApn;
- (void)setPresetApn:(NSString *)newPresetApn;


@end
