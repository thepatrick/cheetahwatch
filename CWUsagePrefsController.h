//
//  CWUsagePrefsController.h
//  CheetahWatch
//
//  Created by Patrick Quinn-Graham on 01/04/08.
//  Copyright 2008 Patrick Quinn-Graham. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface CWUsagePrefsController : NSObject {
	
	IBOutlet NSWindow		*prefsWindow;
	IBOutlet NSButton		*warnMe;
	IBOutlet NSPopUpButton	*warnMeWhichType;
	IBOutlet NSTextField	*warnMeFileSize;
	IBOutlet NSPopUpButton	*warnMeFileSizeMultiplier;
	
	IBOutlet NSButton		*autoReset;
	IBOutlet NSSegmentedControl *autoResetFrequency2;
	IBOutlet NSView			*autoResetFrequencyView;
	IBOutlet NSBox			*autoResetFrequencyViewContainer;
	IBOutlet NSPopUpButton	*afterReset;
	
	IBOutlet NSView			*freqDailyView;
	IBOutlet NSView			*freqWeeklyView;
	IBOutlet NSView			*freqMonthlyView;
	
	IBOutlet NSButton		*autoResetWeeklySunday;
	IBOutlet NSButton		*autoResetWeeklyMonday;
	IBOutlet NSButton		*autoResetWeeklyTuesday;
	IBOutlet NSButton		*autoResetWeeklyWednesday;
	IBOutlet NSButton		*autoResetWeeklyThursday;
	IBOutlet NSButton		*autoResetWeeklyFriday;
	IBOutlet NSButton		*autoResetWeeklySaturday;
	
	IBOutlet NSButton		*autoResetMonthlyEach;
	IBOutlet NSButton		*autoResetMonthlyOnThe;
	
	NSString *presentFrequency;
	
}

+(void)setDefaultUserDefaults:(NSMutableDictionary*)dd;

-(void)changeFrequency:(NSString*)newFrequency;
-(void)changeAutoResetFrequency2:(id)sender;
-(void)showPrefsWindow:(id)sender;

-(void)toggleAutoResetWeekdays:(NSButton*)sender;

-(void)changeAutoResetMonthlyMode:(NSButton*)sender;

@end
