//
//  CWUsagePrefsController.m
//  CheetahWatch
//
//  Created by Patrick Quinn-Graham on 01/04/08.
//  Copyright 2008 Patrick Quinn-Graham. All rights reserved.
//

#import "CWUsagePrefsController.h"


@implementation CWUsagePrefsController

+(void)setDefaultUserDefaults:(NSMutableDictionary*)dd
{
	[dd setValue:@"daily" forKey:@"CWUsageFrequency"];
	[dd setValue:@"NO" forKey:@"CWActivateUsageWarning"];
	[dd setValue:[NSNumber numberWithInt:0] forKey:@"CWActivateUsageWarningWhen"];
	[dd setValue:[NSNumber numberWithInt:0] forKey:@"CWActivateUsageWarningValue"];
	[dd setValue:[NSNumber numberWithInt:0] forKey:@"CWActivateUsageWarningValueMultiplier"];
	[dd setValue:@"NO" forKey:@"CWAutoReset"];
	
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
	NSLog(@"Good morning everybody!");
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
	
	//float windowHeight;
	float viewHeight;
	
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

	float newViewHeight = (222 + viewHeight);		
	windowFrame.origin.y += windowFrame.size.height - newViewHeight;
	windowFrame.size.height = newViewHeight;		
	[prefsWindow setFrame:windowFrame display:YES animate:YES];
		
	[[prefsWindow contentView] addSubview:view];
	innerFrame.size.height = viewHeight;		
	innerFrame.origin.y = windowFrame.size.height - (innerFrame.size.height + 170);
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
