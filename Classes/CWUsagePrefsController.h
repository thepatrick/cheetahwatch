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
