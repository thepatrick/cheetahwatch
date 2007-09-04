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

#import "CWMain.h"

@implementation CWMain

+(void)initialize
{
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObject:@"YES" forKey:@"CWStoreHistory"]];
}

-(void)awakeFromNib
{
	[signal setEnabled:NO]; //disables user interaction, enabled by default
	[theWindow setTopBorder:24.0];
	[theWindow setBottomBorder:255];
	[theWindow setBorderStartColor:[NSColor colorWithDeviceWhite:0.9 alpha:0.5]];
	[theWindow setBorderEndColor:[NSColor colorWithDeviceWhite:0.5 alpha:0.5]];
	[theWindow setBorderEdgeColor:[NSColor colorWithDeviceWhite:0.8 alpha:0.5]];
	[theWindow setBgColor:[NSColor colorWithDeviceWhite:0.95 alpha:1.0]];
	[theWindow setBackgroundColor:[theWindow styledBackground]];
	[theWindow setDelegate:self];
	
	cwh = [[CWHistorySupport alloc] init];	
	[cwh setMainController:self];
	[cwh setupCoreData];
	
	[self clearAllUI];
	[self startMonitor:nil];
	[self updateHistory];
	
	[self makeMenuMatchStorageHistory];
	
//	[menuStoreUsageHistory setVisible:NO];
	
   statusItem = [[[NSStatusBar systemStatusBar] 
      statusItemWithLength:NSVariableStatusItemLength]
      retain];
   [statusItem setHighlightMode:YES];
   [statusItem setEnabled:YES];
   [statusItem setToolTip:@"CheetahWatch"];
   
   [statusItem setImage:[NSImage imageNamed:@"no-modem-menu.tif"]];

   [statusItem setAction:@selector(clickMenu:)];
   [statusItem setTarget:self];
}

-(void)clickMenu:(id)sender
{
//	NSLog(@"clickMenu!");
	[NSApp activateIgnoringOtherApps:YES];
	[theWindow makeKeyAndOrderFront:self];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)app hasVisibleWindows:(BOOL)visible
{
	if (visible)
		return TRUE;
	[theWindow makeKeyAndOrderFront:self];
	return FALSE;
}

-(void)dealloc
{
	[cwh release];
    [statusItem release];
	[super dealloc];
}

// start a new thread running myrunner below
-(void)startMonitor:(id)sender
{
	[NSThread detachNewThreadSelector:@selector(MyRunner:) toTarget:[CWMain class] withObject:self];
}

// clear UI, generally keep things from looking too silly.
-(void)clearAllUI
{
	[statusItem setImage:[NSImage imageNamed:@"no-modem-menu.tif"]];
	[signal setIntValue:0];
	[mode setStringValue:@""];	
	[statusItem setTitle:@""];
	[self clearConnectionUI];
}

-(void)clearConnectionUI
{
	[speedReceive setStringValue:@""];
	[speedTransmit setStringValue:@""];
	[transferReceive setStringValue:@""];
	[transferTransmit setStringValue:@""];
	[uptime setStringValue:@""];
}

-(void)updateHistory
{
	[cwh calculateTotalUsage];
	int runningTotalSent = [cwh cachedTotalSent];
	int runningTotalRecv = [cwh cachedTotalRecv];
	[totalReceived setStringValue:[self prettyDataAmount:runningTotalRecv]];
	[totalTransmitted setStringValue:[self prettyDataAmount:runningTotalSent]];
}

// called by the monitor thread to say "no modem!"
- (void)noModem:(id)sender
{
	[cwh willChangeValueForKey:@"theUptime"];
	[cwh setValue:@"Hello 2" forKey:@"theUptime"];
	[cwh didChangeValueForKey:@"theUptime" ];
	
	[cwh markConnectionAsClosed];
	[self clearAllUI];
	NSImage *imageFromBundle = [NSImage imageNamed:@"no-modem.png"];
	[status setImage: imageFromBundle];
	[statusItem setImage:[NSImage imageNamed:@"no-modem-menu.tif"]];
	[self performSelector:@selector(startMonitor:) withObject:self afterDelay:5];
}

// called by the monitor thread to say "hoorah! w00t!"
-(void)haveModem
{
	NSImage *imageFromBundle = [NSImage imageNamed:@"have-modem.png"];
	[statusItem setTitle:@"?"]; 
	[status setImage: imageFromBundle];
	[self clearAllUI];
}

-(BOOL)storeUsageHistory
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"CWStoreHistory"];
}
-(void)toggleStoreUsageHistory
{
	[[NSUserDefaults standardUserDefaults] setBool:(![self storeUsageHistory]) forKey:@"CWStoreHistory"];
}
-(void)makeMenuMatchStorageHistory
{
	[menuStoreUsageHistory setState:([self storeUsageHistory] ? NSOnState : NSOffState)];
}
-(void)storeUsageHistory:(id)sender
{
	[self toggleStoreUsageHistory];
	[self makeMenuMatchStorageHistory];
}

-(void)clearUsageHistory:(id)sender
{
	[cwh clearHistory];
	[self updateHistory];
}

-(NSString*)prettyDataAmount:(int)bytes
{
	if(bytes < 1024) // bytes
		return [NSString stringWithFormat:@"%.0fB", (double)bytes];
	if(bytes < (1024 * 1024)) // KB
		return [NSString stringWithFormat:@"%.1fKB", ((double)bytes / 1024)];
	if(bytes < (1024 * 1024 * 1024)) // MB
		return [NSString stringWithFormat:@"%.1fMB", ((double)bytes / (1024 * 1024))];
	return [NSString stringWithFormat:@"%.1fGB", ((double)bytes / (1024 * 1024 * 1024))];
}

// called by the secondary thread flowReport, notifies History of update
-(void)flowReport2:(id)nothing
{
	int SecondsConnected = [currentUptime intValue];
	
	float MinutesConnected = SecondsConnected / 60;	
	[uptime setStringValue:[NSString stringWithFormat:@"%.0f:%.2d", MinutesConnected, (SecondsConnected - ((int)MinutesConnected * 60 ))]];
	[speedReceive setStringValue:[[self prettyDataAmount:[currentSpeedReceive intValue]] stringByAppendingString:@"ps"]];
	[speedTransmit setStringValue:[[self prettyDataAmount:[currentSpeedTransmit intValue]] stringByAppendingString:@"ps"]];
	[transferReceive setStringValue:[self prettyDataAmount:[currentReceived intValue]]];
	[transferTransmit setStringValue:[self prettyDataAmount:[currentTransmitted intValue]]];


	[cwh flowReportSeconds:currentUptime withTransmitRate:currentSpeedTransmit
		receiveRate:currentSpeedReceive 
		totalSent:currentTransmitted 
		andTotalReceived:currentReceived];

	[self updateHistory];
	
//	int runningTotalSent = [cwh cachedTotalSent];
//	int runningTotalRecv = [cwh cachedTotalRecv];
//	
//	NSLog(@"Running total sent/recv: %@/%@", [self prettyDataAmount:runningTotalSent], [self prettyDataAmount:runningTotalRecv]);
	
}

// this is the quasi-runloop (yeah, whatever) that follows the stream from the modem
// the functions below are all run on the second thread.
+ (void)MyRunner:(id)mainController
{
	int fd, bytes;
	char *buf_stream, *buf_lineStart;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	buf_stream=(char *)malloc(BUFSIZE*sizeof(char));
	fd = open(MODEMUIDEV, O_RDONLY | O_NOCTTY ); 
	if (fd < 0) {
		[mainController performSelectorOnMainThread:@selector(noModem:) withObject:nil waitUntilDone:YES];
		[pool release];
		return;
	}	
	[mainController haveModem];
	while(bytes = read(fd,buf_stream,255)){
		buf_lineStart=strchr(buf_stream,'^');
		buf_stream[bytes]=0x00;  
		if (buf_lineStart) {
			strcpy(buf_stream, buf_lineStart); 
			if (buf_stream[0]=='^') {
				switch (buf_stream[1]) {
					case 'D': [mainController flowReport:(buf_stream+11)]; break;
					case 'M': [mainController modeChange:(buf_stream+8)]; break;
					case 'R': [mainController signalStrength:(buf_stream+6)]; break;
				}
			}
		}	
	}
	[mainController performSelectorOnMainThread:@selector(noModem:) withObject:nil waitUntilDone:YES];
    [pool release];
}

// Update the signal strength display
-(void)signalStrength:(char*)buff
{
	int z_signal;
	z_signal=atoi(buff);
	if(z_signal > 20) printf("Claimed that signal was %i\n", z_signal);
	if(z_signal > 50) z_signal = 0;
	[signal setIntValue:z_signal];
	
	NSString *which;
	if(z_signal == 0) which = @"signal-0.tif";
	else if(z_signal < 6) which = @"signal-1.tif";
	else if(z_signal < 11) which = @"signal-2.tif";
	else if(z_signal < 16) which = @"signal-3.tif";
	else if(z_signal >= 16) which = @"signal-4.tif";
	else if(z_signal > 30) which = @"signal-0.tif";
	
	[self performSelectorOnMainThread:@selector(changeStatusImageTo:) withObject:which waitUntilDone:YES];		
}

-(void)changeStatusImageTo:(NSString*)which
{
	[statusItem setImage:[NSImage imageNamed:which]];
}

// Update the "mode" display
-(void)modeChange:(char*)buff
{
	[mode setStringValue:@""];	
	NSString *newMode = [NSString stringWithCString:buff length:1];
	NSLog(@"BARG: %@", newMode);
	[self performSelectorOnMainThread:@selector(modeChangeAction:) withObject:newMode waitUntilDone:YES];
}

-(void)modeChangeAction:(NSString*)newMode
{//
//	NSFont *stringFont = [NSFont fontWithName:@"Monaco" size:9.0];
//	NSDictionary *stringAttributes = [NSDictionary dictionaryWithObject:stringFont forKey:NSFontAttributeName];
//	NSAttributedString *lowerString = [[NSAttributedString alloc] 
//							initWithString:stringFromElsewhere
//						        attributes:stringAttributes];
//								

	switch ([newMode cString][0]) {
		case '0':
			[statusItem setTitle:@"X"]; 
			[mode setStringValue:@"None"];
			break;
		case '1':
			[statusItem setTitle:@"G"]; 
			[mode setStringValue:@"GPRS"];
			break;
		case '2':
			[statusItem setTitle:@"G"]; 
			[mode setStringValue:@"GPRS"];
			break;
		case '3':
			[statusItem setTitle:@"E"]; 
			[mode setStringValue:@"EDGE"];
			break;
		case '4':
			[statusItem setTitle:@"W"]; 
			[mode setStringValue:@"WCDMA"];
			break;
		case '5':
			[statusItem setTitle:@"H"]; 
			[mode setStringValue:@"HSDPA"];
			break;
		default:
			[statusItem setTitle:@"?"]; 
			[mode setStringValue:@"Unknown"];
	}
}

// Update the connection time, speed, and data moved display
-(void)flowReport:(char*)buff
{
	unsigned int SecondsConnected, SpeedTransmit, SpeedReceive, Transmitted, Received;
	sscanf(buff,"%X,%X,%X,%X,%X", &SecondsConnected,&SpeedTransmit,&SpeedReceive,&Transmitted,&Received);
		
	// this should probably lock to prevent badness, but meh.
	currentUptime = [NSNumber numberWithInt:SecondsConnected];
	currentSpeedReceive = [NSNumber numberWithInt:SpeedReceive];
	currentSpeedTransmit = [NSNumber numberWithInt:SpeedTransmit];
	currentTransmitted = [NSNumber numberWithInt:Transmitted];
	currentReceived = [NSNumber numberWithInt:Received];
	
//	NSLog(@"Should see flowReport2...");
	[self performSelectorOnMainThread:@selector(flowReport2:) withObject:nil waitUntilDone:YES];
}
@end