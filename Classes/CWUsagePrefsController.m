/* 
 * Copyright (c) 2007-2008 Patrick Quinn-Graham
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

#import "CWUsagePrefsController.h"


@implementation CWUsagePrefsController

+(void)setDefaultUserDefaults:(NSMutableDictionary*)dd
{
	[dd setValue:@"daily" forKey:@"CWUsageFrequency"];
	[dd setValue:@"NO" forKey:@"CWActivateUsageWarning"];
	[dd setValue:@"NO" forKey:@"CWSuppressUsageWarning"];
	[dd setValue:@"-never-set-" forKey:@"CWSuppressUsageWarningForAmount"];
	
	[dd setValue:[NSNumber numberWithInt:0] forKey:@"CWActivateUsageWarningWhen"];
	[dd setValue:[NSNumber numberWithInt:0] forKey:@"CWActivateUsageWarningValue"];
	[dd setValue:[NSNumber numberWithInt:0] forKey:@"CWActivateUsageWarningValueMultiplier"];
	
	[dd setValue:@"NO" forKey:@"CWAutoReset"];
	[dd setValue:[NSDate dateWithTimeIntervalSinceReferenceDate:0] forKey:@"CWAutoResetLastReset"];
	
	[dd setValue:[NSNumber numberWithInt:1] forKey:@"CWAutoResetPostAction"];
	[dd setValue:[NSNumber numberWithInt:1] forKey:@"CWAutoResetDailyDays"];
	
	[dd setValue:[NSNumber numberWithInt:1] forKey:@"CWAutoResetWeeklyWeeks"];
	
	
	[dd setValue:@"NO" forKey:@"CWAutoResetWeeklySunday"];
	[dd setValue:@"NO" forKey:@"CWAutoResetWeeklyMonday"];
	[dd setValue:@"NO" forKey:@"CWAutoResetWeeklyTuesday"];
	[dd setValue:@"NO" forKey:@"CWAutoResetWeeklyWednesday"];
	[dd setValue:@"NO" forKey:@"CWAutoResetWeeklyThursday"];
	[dd setValue:@"NO" forKey:@"CWAutoResetWeeklyFriday"];
	[dd setValue:@"NO" forKey:@"CWAutoResetWeeklySaturday"];
	
	
	[dd setValue:[NSNumber numberWithInt:1] forKey:@"CWAutoResetMonthlyMonths"];
	
	
	[dd setValue:[NSNumber numberWithInt:0] forKey:@"CWAutoResetMonthlyOnTheMode"];
	[dd setValue:[NSNumber numberWithInt:0] forKey:@"CWAutoResetMonthlyOnTheWhich"];
	[dd setValue:[NSNumber numberWithInt:0] forKey:@"CWAutoResetMonthlyOnTheDayOfWeek"];
	
}

-(int)mixedStateFromBOOL:(BOOL)src
{
	return src ? NSOnState : NSOffState;
}

-(void)awakeFromNib
{
	[self changeFrequency:[[NSUserDefaults standardUserDefaults] stringForKey:@"CWUsageFrequency"]];
	
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	
	[autoResetWeeklySunday    setState:[self mixedStateFromBOOL:[ud boolForKey:@"CWAutoResetWeeklySunday"]]];
	[autoResetWeeklyMonday    setState:[self mixedStateFromBOOL:[ud boolForKey:@"CWAutoResetWeeklyMonday"]]];
	[autoResetWeeklyTuesday   setState:[self mixedStateFromBOOL:[ud boolForKey:@"CWAutoResetWeeklyTuesday"]]];
	[autoResetWeeklyWednesday setState:[self mixedStateFromBOOL:[ud boolForKey:@"CWAutoResetWeeklyWednesday"]]];
	[autoResetWeeklyThursday  setState:[self mixedStateFromBOOL:[ud boolForKey:@"CWAutoResetWeeklyThursday"]]];
	[autoResetWeeklyFriday    setState:[self mixedStateFromBOOL:[ud boolForKey:@"CWAutoResetWeeklyFriday"]]];
	[autoResetWeeklySaturday  setState:[self mixedStateFromBOOL:[ud boolForKey:@"CWAutoResetWeeklySaturday"]]];
	
	[autoResetMonthlyEach  setState:[self mixedStateFromBOOL:([ud integerForKey:@"CWAutoResetMonthlyOnTheMode"] == 0)]];
	[autoResetMonthlyOnThe  setState:[self mixedStateFromBOOL:([ud integerForKey:@"CWAutoResetMonthlyOnTheMode"] == 1)]];
}

-(void)toggleAutoResetWeekdays:(NSButton*)sender
{
	NSString *whichDay = @"";
	
	if(sender == autoResetWeeklySunday)	   whichDay = @"CWAutoResetWeeklySunday";
	if(sender == autoResetWeeklyMonday)    whichDay = @"CWAutoResetWeeklyMonday";
	if(sender == autoResetWeeklyTuesday)   whichDay = @"CWAutoResetWeeklyTuesday";
	if(sender == autoResetWeeklyWednesday) whichDay = @"CWAutoResetWeeklyWednesday";
	if(sender == autoResetWeeklyThursday)  whichDay = @"CWAutoResetWeeklyThursday";
	if(sender == autoResetWeeklyFriday)    whichDay = @"CWAutoResetWeeklyFriday";
	if(sender == autoResetWeeklySaturday)  whichDay = @"CWAutoResetWeeklySaturday";
	
	if(![whichDay isEqualToString:@""]) {
		[[NSUserDefaults standardUserDefaults] setBool:([sender state] == NSOnState) forKey:whichDay];	
	}
}

-(void)changeAutoResetMonthlyMode:(NSButton*)sender
{
	if(sender == autoResetMonthlyEach) {
		[autoResetMonthlyOnThe setState:NSOffState];
	} else if(sender == autoResetMonthlyOnThe) {
		[autoResetMonthlyEach setState:NSOffState];	
	}
	[[NSUserDefaults standardUserDefaults] setInteger:[sender tag] forKey:@"CWAutoResetMonthlyOnTheMode"];
}

-(void)determineNextResetDate
{
	NSUserDefaults *dd = [NSUserDefaults standardUserDefaults];
	
	NSDate *next = nil;
	if([presentFrequency isEqualToString:@"daily"]) {
		NSInteger days = [dd integerForKey:@"CWAutoResetDailyDays"];
		next = [NSDate dateWithTimeIntervalSinceNow:(days * 24 /*hours*/ * 60 /*minutes*/ * 60 /*seconds*/)];
	} else if([presentFrequency isEqualToString:@"weekly"]) {
		// each $n weeks, so we need to figure out:
		// 1: When we last ran
		// 2: Find out which day that was, and what the next one is
		// 3: If never ran, assume last run was today, and base off that.
	} else if([presentFrequency isEqualToString:@"monthly"]) {
	}
	
	[dd setValue:next forKey:@"CWAutoResetNextRun"];
}

-(void)changeFrequency:(NSString*)newFrequency
{
	if(presentFrequency != nil) {
		if([presentFrequency isEqualToString:@"daily"]) {
			[freqDailyView retain];
			[freqDailyView removeFromSuperview];
		} else if([presentFrequency isEqualToString:@"weekly"]) {
			[freqWeeklyView retain];
			[freqWeeklyView removeFromSuperview];
		} else if([presentFrequency isEqualToString:@"monthly"]) {
			[freqMonthlyView retain];
			[freqMonthlyView removeFromSuperview];	
		}
	
		[presentFrequency release];
		presentFrequency = nil;
	}

	presentFrequency = [newFrequency copy];
	
	NSRect windowFrame = [prefsWindow frame];
	
	CGFloat viewHeight;
	
	NSRect innerFrame = NSMakeRect(52, 0, 296, 0);
	
	NSView *view;
	
	if([presentFrequency isEqualToString:@"daily"]) {
		view = freqDailyView;
		viewHeight = 22;
		[autoResetFrequency2 setSelectedSegment:0];
	} else if([presentFrequency isEqualToString:@"weekly"]) {
		view = freqWeeklyView;
		viewHeight = 55;	
		[autoResetFrequency2 setSelectedSegment:1];	
	} else if([presentFrequency isEqualToString:@"monthly"]) {
		view = freqMonthlyView;
		viewHeight = 188;
		[autoResetFrequency2 setSelectedSegment:2];
	} else {
		NSLog(@"Oh feck.");
		return;
	}
	
	CGFloat scaleFactor = [[NSScreen mainScreen] userSpaceScaleFactor];

	CGFloat newViewHeight = (222 + viewHeight);		
	windowFrame.origin.y += windowFrame.size.height - (newViewHeight * scaleFactor);
	windowFrame.size.height = (newViewHeight * scaleFactor);		
	[prefsWindow setFrame:windowFrame display:YES animate:YES];
		
	[[prefsWindow contentView] addSubview:view];
	innerFrame.size.height = viewHeight;		
	innerFrame.origin.y = (windowFrame.size.height / scaleFactor) - (innerFrame.size.height + 170);
	[view setFrame:innerFrame];

	[[NSUserDefaults standardUserDefaults] setObject:presentFrequency forKey:@"CWUsageFrequency"];
}

-(void)changeAutoResetFrequency2:(id)sender
{
	[self changeFrequency:[sender labelForSegment:[sender selectedSegment]]];
}

-(void)showPrefsWindow:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	[prefsWindow makeKeyAndOrderFront:sender];
}

@end
