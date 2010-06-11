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

#import "CWUsagePrefsController.h"

@implementation CWUsagePrefsController

-(void)awakeFromNib
{
	[(NSObject*)[[NSApplication sharedApplication] delegate] addObserver:self forKeyPath:@"model.preferences.resetMode" 
			   options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) 
			   context:nil];
}
	 
-(void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void *)context {
	if([keyPath isEqualToString:@"model.preferences.resetMode"])
		[self changeFrequency:[autoResetFrequency2 labelForSegment:[[change objectForKey:@"new"] integerValue]]];
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
	
	NSRect innerFrame = NSMakeRect(22, 22, 296, 0);
	
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
		viewHeight = 143;
		[autoResetFrequency2 setSelectedSegment:2];
	} else {
		NSLog(@"Oh feck.");
		return;
	}
	
	CGFloat scaleFactor = [[NSScreen mainScreen] userSpaceScaleFactor];

	CGFloat newViewHeight = (260 + viewHeight);		
	windowFrame.origin.y += windowFrame.size.height - (newViewHeight * scaleFactor);
	windowFrame.size.height = (newViewHeight * scaleFactor);		
	[prefsWindow setFrame:windowFrame display:YES animate:YES];
		
	NSRect containerFrame = [autoResetFrequencyViewContainer frame];
	containerFrame.size.height = viewHeight + 44;
	containerFrame.origin.y = 22;
	[autoResetFrequencyViewContainer setFrame:containerFrame];
	
	[autoResetFrequencyViewContainer addSubview:view];
	innerFrame.size.height = viewHeight + 44;		
	innerFrame.origin.y = -26;
	[view setFrame:innerFrame];
	
}

@end
