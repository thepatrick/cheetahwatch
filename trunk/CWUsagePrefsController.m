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
}

-(void)awakeFromNib
{
	NSLog(@"Good morning everybody!");
	[self changeFrequency:[[NSUserDefaults standardUserDefaults] stringForKey:@"CWUsageFrequency"]];
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
