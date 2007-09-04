/* CheetahWatch, v1.0.2
 * Copyright (c) 2007 Patrick Quinn-Graham
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
#import "StyledWindow.h"
#import "CWHistorySupport.h"

#define BAUDRATE B9600
#define MODEMUIDEV "/dev/tty.HUAWEIMobile-Pcui"
#define BUFSIZE 256

@interface CWMain : NSObject
{
    IBOutlet id mode;
    IBOutlet id signal;
    IBOutlet id speedReceive;
    IBOutlet id speedTransmit;
    IBOutlet id status;
	IBOutlet StyledWindow *theWindow;
    IBOutlet id transferReceive;
    IBOutlet id transferTransmit;
    IBOutlet id uptime;
	IBOutlet id appMenu;	
	IBOutlet id totalReceived;
	IBOutlet id totalTransmitted;	
	IBOutlet id menuStoreUsageHistory;
	IBOutlet id menuClearUsageHistory;
	
	bool weHaveAModem;
	NSStatusItem *statusItem;

 	CWHistorySupport *cwh;
	
	NSNumber *currentUptime;
	NSNumber *currentSpeedReceive;
	NSNumber *currentSpeedTransmit;
	NSNumber *currentTransmitted;
	NSNumber *currentReceived;
	
}

-(void)startMonitor:(id)sender;
-(void)clearAllUI;
-(void)clearConnectionUI;
-(void)updateHistory;
-(void)makeMenuMatchStorageHistory;

-(BOOL)storeUsageHistory;
-(void)toggleStoreUsageHistory;
-(void)makeMenuMatchStorageHistory;

-(NSString*)prettyDataAmount:(int)bytes;

-(void)noModem:(id)sender;
-(void)haveModem;

-(void)storeUsageHistory:(id)sender;
-(void)clearUsageHistory:(id)sender;

-(void)signalStrength:(char*)buff;
-(void)modeChange:(char*)buff;
-(void)flowReport:(char*)buff;

+(void)MyRunner:(id)mainController;


@end
