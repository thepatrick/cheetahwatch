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

#import "CWPreferences.h"


@implementation CWPreferences

// class initializer
+ (void)initialize
{
    static BOOL beenHere;
    if (!beenHere) {
        // make derived attributes binding capable
        [self setKeys:[NSArray arrayWithObject:@"resetMode"] triggerChangeNotificationsForDependentKey:@"enableDayFields"];
        [self setKeys:[NSArray arrayWithObject:@"resetMode"] triggerChangeNotificationsForDependentKey:@"enableWeekFields"];
        [self setKeys:[NSArray arrayWithObject:@"resetMode"] triggerChangeNotificationsForDependentKey:@"enableMonthFields"];
        beenHere = YES;
    }
}

// initializer
- (id)init
{
    if (self = [super init]) {
        // set some default values
        storeUsageHistory = YES;
        resetStatistics = YES;
        dayPeriod = weekPeriod = monthPeriod = 1;
        dayOfWeek = dayOfMonth = 1;
        resetMode = CWResetStatisticsModeMonth;
        trafficWarningMode = CWTrafficWarningModeAll;
        trafficWarningAmount = 5;
        trafficWarningUnit = CWTrafficWarningUnitGB;
        trafficWarningInterval = 300;
        showConnectionTime = YES;
		autoconnect = NO;
        presetApn = @"";
    }
    return self;
}

// coder protocol
- (id)initWithCoder:(NSCoder *)decoder
{
	if (self = [super init]) {
		storeUsageHistory = [decoder decodeBoolForKey:@"storeUsageHistory"];
		resetStatistics = [decoder decodeBoolForKey:@"resetStatistics"];
		resetMode = [decoder decodeIntegerForKey:@"resetMode"];
		dayPeriod = [decoder decodeIntegerForKey:@"dayPeriod"];
		weekPeriod = [decoder decodeIntegerForKey:@"weekPeriod"];
		monthPeriod = [decoder decodeIntegerForKey:@"monthPeriod"];
		dayOfWeek = [decoder decodeIntegerForKey:@"dayOfWeek"];
		dayOfMonth = [decoder decodeIntegerForKey:@"dayOfMonth"];
		trafficWarning = [decoder decodeBoolForKey:@"trafficWarning"];
		trafficWarningMode = [decoder decodeIntegerForKey:@"trafficWarningMode"];
		trafficWarningAmount = [decoder decodeIntegerForKey:@"trafficWarningAmount"];
		trafficWarningUnit = [decoder decodeIntegerForKey:@"trafficWarningUnit"];
		trafficWarningInterval = [decoder decodeIntegerForKey:@"trafficWarningInterval"];
		showConnectionTime = [decoder decodeBoolForKey:@"showConnectionTime"];
		autoconnect = [decoder decodeBoolForKey:@"autoconnect"];
		presetApn = [[decoder decodeObjectForKey:@"presetApn"] retain];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeBool:storeUsageHistory forKey:@"storeUsageHistory"];
	[encoder encodeBool:resetStatistics forKey:@"resetStatistics"];
	[encoder encodeInteger:resetMode forKey:@"resetMode"];
	[encoder encodeInteger:dayPeriod forKey:@"dayPeriod"];
	[encoder encodeInteger:weekPeriod forKey:@"weekPeriod"];
	[encoder encodeInteger:monthPeriod forKey:@"monthPeriod"];
	[encoder encodeInteger:dayOfWeek forKey:@"dayOfWeek"];
	[encoder encodeInteger:dayOfMonth forKey:@"dayOfMonth"];
	[encoder encodeBool:trafficWarning forKey:@"trafficWarning"];
	[encoder encodeInteger:trafficWarningMode forKey:@"trafficWarningMode"];
	[encoder encodeInteger:trafficWarningAmount forKey:@"trafficWarningAmount"];
	[encoder encodeInteger:trafficWarningUnit forKey:@"trafficWarningUnit"];
	[encoder encodeInteger:trafficWarningInterval forKey:@"trafficWarningInterval"];
	[encoder encodeBool:showConnectionTime forKey:@"showConnectionTime"];
	[encoder encodeBool:autoconnect forKey:@"autoconnect"];
	[encoder encodeObject:presetApn forKey:@"presetApn"];
}

// derived accessors
- (BOOL)enableDayFields
{
    return resetMode == CWResetStatisticsModeDay;
}

- (BOOL)enableWeekFields
{
    return resetMode == CWResetStatisticsModeWeek;
}

- (BOOL)enableMonthFields
{
    return resetMode == CWResetStatisticsModeMonth;
}

// accessors
- (BOOL)storeUsageHistory
{
	return storeUsageHistory;
}

- (void)setStoreUsageHistory:(BOOL)newStoreUsageHistory
{
	storeUsageHistory = newStoreUsageHistory;
}

- (BOOL)resetStatistics
{
	return resetStatistics;
}

- (void)setResetStatistics:(BOOL)newResetStatistics
{
	resetStatistics = newResetStatistics;
}

- (NSInteger)resetMode
{
	return resetMode;
}

- (void)setResetMode:(NSInteger)newResetMode
{
	resetMode = newResetMode;
}

- (NSInteger)dayPeriod
{
	return dayPeriod;
}

- (void)setDayPeriod:(NSInteger)newDayPeriod
{
	dayPeriod = newDayPeriod;
}

- (NSInteger)weekPeriod
{
	return weekPeriod;
}

- (void)setWeekPeriod:(NSInteger)newWeekPeriod
{
	weekPeriod = newWeekPeriod;
}

- (NSInteger)monthPeriod
{
	return monthPeriod;
}

- (void)setMonthPeriod:(NSInteger)newMonthPeriod
{
	monthPeriod = newMonthPeriod;
}

- (NSInteger)dayOfWeek
{
	return dayOfWeek;
}

- (void)setDayOfWeek:(NSInteger)newDayOfWeek
{
	dayOfWeek = newDayOfWeek;
}

- (NSInteger)dayOfMonth
{
	return dayOfMonth;
}

- (void)setDayOfMonth:(NSInteger)newDayOfMonth
{
	dayOfMonth = newDayOfMonth;
}

- (BOOL)trafficWarning
{
	return trafficWarning;
}

- (void)setTrafficWarning:(BOOL)newTrafficWarning
{
	trafficWarning = newTrafficWarning;
}

- (NSInteger)trafficWarningMode
{
	return trafficWarningMode;
}

- (void)setTrafficWarningMode:(NSInteger)newTrafficWarningMode
{
	trafficWarningMode = newTrafficWarningMode;
}

- (NSInteger)trafficWarningAmount
{
	return trafficWarningAmount;
}

- (void)setTrafficWarningAmount:(NSInteger)newTrafficWarningAmount
{
	trafficWarningAmount = newTrafficWarningAmount;
}

- (NSInteger)trafficWarningUnit
{
	return trafficWarningUnit;
}

- (void)setTrafficWarningUnit:(NSInteger)newTrafficWarningUnit
{
	trafficWarningUnit = newTrafficWarningUnit;
}

- (NSInteger)trafficWarningInterval
{
	return trafficWarningInterval;
}

- (void)setTrafficWarningInterval:(NSInteger)newTrafficWarningInterval
{
	trafficWarningInterval = newTrafficWarningInterval;
}

- (BOOL)autoconnect
{
	return autoconnect;
}

- (void)setAutoconnect:(BOOL)newAutoconnect
{
	autoconnect = newAutoconnect;
}

- (BOOL)showConnectionTime
{
	return showConnectionTime;
}

- (void)setShowConnectionTime:(BOOL)newShowConnectionTime
{
	showConnectionTime = newShowConnectionTime;
}

- (NSString *)presetApn
{
	return presetApn;
}

- (void)setPresetApn:(NSString *)newPresetApn
{
	[newPresetApn retain];
	[presetApn release];
	presetApn = newPresetApn;
}

@end
