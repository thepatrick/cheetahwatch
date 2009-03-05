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

#import "NBInvocationQueue.h"
#import "CWUsagePrefsController.h"
#import "CWHistorySupport.h"
#import "CWMain.h"
#import "CWNetworks.h"
#import "CWUSBFinder.h"

@implementation CWMain

+(void)initialize
{
	NSMutableDictionary *dd = [NSMutableDictionary dictionaryWithObject:@"YES" forKey:@"CWStoreHistory"];
	[dd setValue:@"YES" forKey:@"CWFirstRun"];
	[dd setValue:@"YES" forKey:@"CWShowStatsBox"];
	[dd setValue:@"YES" forKey:@"CWShowStatusWhileConnecting"];
	
	[CWUsagePrefsController setDefaultUserDefaults:dd];
	
	[[NSUserDefaults standardUserDefaults] registerDefaults:dd];
}

const char *statusMsgA (SCNetworkConnectionStatus stat)
{
	NSLog(@"statusMsgA called. Should be happy now. Mmm happy.");
	static const char *statusString[] = {
		"kSCNetworkConnectionInvalid",
		"kSCNetworkConnectionDisconnected",
		"kSCNetworkConnectionConnecting",
		"kSCNetworkConnectionConnected",
		"kSCNetworkConnectionDisconnecting"
	};
	const char *msg = NULL;
	if (kSCNetworkConnectionInvalid <= stat && stat <= kSCNetworkConnectionDisconnecting)
		msg = statusString [stat + 1];
	else
		msg = "Unknown status";
	return msg;
}

void calloutProc (SCNetworkConnectionRef connection, SCNetworkConnectionStatus status, void *info )
{
	NSLog(@"calloutProc!");
	SCNetworkConnectionStatus gStat = status;
	const char *msg = statusMsgA(gStat);				
	if (msg != NULL)
		printf ("%s\n", msg);
}

-(void)awakeFromNib
{
	atWorker = [[NBInvocationQueue alloc] init];
	[NSThread detachNewThreadSelector:@selector(runQueueThread) toTarget:atWorker withObject:nil];
	
	networks = [[CWNetworks networks] retain];
	
	[signal setEnabled:NO]; //disables user interaction, enabled by default
	
	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
	[statusItem setHighlightMode:YES];
	[statusItem setEnabled:YES];
	[statusItem setToolTip:@"CheetahWatch"];
	//[statusItem setAttributedTitle:@""];
	[statusItem setToolTip:@"CheetahWatch - No modem detected"];
	[statusItem setMenu:statusItemMenu];		
	
	// these two items need to be retained by us because we add/remove them many times while the app is running
	// if we didnt, the first time they were removed they'd turn to mush, which isn't anywhere near as fun as it sounds.
	[statusItemConnect retain];
	[statusItemDisconnect retain];

	[self changeStatusImageTo:@"no-modem-menu.tif"];
	
	if([self storeUsageHistory]) {
		cwh = [[CWHistorySupport alloc] init];	
		[cwh setMainController:self];
		[cwh setupCoreData];	
	}
	
	[NSThread detachNewThreadSelector:@selector(USBFinder:) toTarget:[CWUSBFinder class] withObject:self];
	
	[self clearAllUI];
	[self updateHistory];
	[self makeMenuMatchStorageHistory];
	[self setupDialing];	
	[self showFirstRun];
	
	if(![[NSUserDefaults standardUserDefaults] boolForKey:@"CWShowStatsBox"]) {
		[self makeTheWindowCompactAnimating:NO];
		[toggleStatsDisplay setState:NSOffState];
	}
	
	shouldHideStatusWhenConnected = NO;
}

-(void)setupDialing
{
	gStat = kSCNetworkConnectionInvalid;
	CFStringRef serviceID;
	if(SCNetworkConnectionCopyUserPreferences(NULL, &serviceID, &userOptions)) {
		scncRef = SCNetworkConnectionCreateWithServiceID (NULL, serviceID, calloutProc, &gScncCtx);
		if (scncRef == NULL) {
			NSLog(@"SCNetworkConnectionCreateWithServiceID failed");
		} else {
			gStat = SCNetworkConnectionGetStatus (scncRef);
		}
	} else {
		NSLog(@"No PPP services configured.");
		
		[[NSAlert alertWithMessageText:@"CheetahWatch can't dial your modem as no suitable connections have been configured." 
						 defaultButton:@"Oky Doky" alternateButton:nil otherButton:nil 
			 informativeTextWithFormat:@"You need to configure a dial-up connection in the Network pane in System Preferences. Consult your provider (or google) for assistance."] runModal];
	}
}

-(void)showFirstRun
{
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"CWFirstRun"]) {	   
	   [[firstRunWebkit mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[[NSBundle mainBundle] pathForResource:@"Welcome" ofType:@"html"]]]];
	   [firstRunWindow setTitle:@""];
	   [firstRunWindow makeKeyAndOrderFront:self];
	   [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"CWFirstRun"];
	}
}

-(void)clickMenu:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	[theWindow makeKeyAndOrderFront:self];
	shouldHideStatusWhenConnected = NO;
}

-(void)showModemInfo:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];	
	[modemInfoWindow makeKeyAndOrderFront:self];
}

-(void)showAbout:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	[NSApp orderFrontStandardAboutPanel:sender];
}

-(void)checkUpdates:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	[sparkler checkForUpdates:sender];
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
	if([self storeUsageHistory]) {
		[cwh release];
	}
	[statusItemConnect release];
	[statusItemDisconnect release];
    [statusItem release];
	[networks release];
	[super dealloc];
}

// start a new thread running myrunner below, used to get this started from the usb monitor thread
-(void)startMonitor:(id)sender
{
	[NSThread detachNewThreadSelector:@selector(MyRunner:) toTarget:[CWMain class] withObject:self];
}

// clear UI, generally keep things from looking too silly.
-(void)clearAllUI
{
	lastSignalStrength = -1;
	[signal setIntValue:0];
	[mode setStringValue:@""];	
	[statusItem setTitle:@""];
	[carrierInMenu setTitle:@"Carrier:"];
	[carrierInStatus setStringValue:@""];
	
	[self setHardwareVersion:@""];
	[self setIMEI:@""];
	
	[self clearConnectionUI];
	
	if([statusItemMenu indexOfItem:statusItemDisconnect] != -1) {
		[statusItemMenu removeItem:statusItemDisconnect];	
	}
	if([statusItemMenu indexOfItem:statusItemConnect] != -1) {
		[statusItemMenu removeItem:statusItemConnect];
	}	

	[statusWindowConnect setHidden:YES];
	[statusWindowDisonnect setHidden:YES];

	[statusItemConectedFor setTitle:@"No modem connected"];
}

-(void)clearConnectionUI
{
	connected = NO;
	[self setSignalStrength:lastSignalStrength];
		
	[speedReceive setStringValue:@""];
	[speedTransmit setStringValue:@""];
	[transferReceive setStringValue:@""];
	[transferTransmit setStringValue:@""];
	//[uptime setStringValue:@""];
	[statusItem setToolTip:@"CheetahWatch - Not connected"];
	[statusItemConectedFor setTitle:@"Not connected"];
	[connectedInStatus setStringValue:@"Not connected"];
	if([statusItemMenu indexOfItem:statusItemDisconnect] != -1) {
		[statusItemMenu removeItem:statusItemDisconnect];	
		if([statusItemMenu indexOfItem:statusItemConnect] == -1) {
			[statusItemMenu insertItem:statusItemConnect atIndex:([statusItemMenu indexOfItem:statusItemConectedFor] + 1)];
		}
	}
	[statusWindowConnect setHidden:NO];
	[statusWindowDisonnect setHidden:YES];

}

-(void)updateHistory
{
	if([self storeUsageHistory]) {
		[cwh calculateTotalUsage];
		SInt64 runningTotalSent = [cwh cachedTotalSent];
		SInt64 runningTotalRecv = [cwh cachedTotalRecv];
		[totalReceived setStringValue:[self prettyDataAmount64:runningTotalRecv]];
		[totalTransmitted setStringValue:[self prettyDataAmount64:runningTotalSent]];
	}
}

// called by the monitor thread to say "no modem!"
- (void)noModem:(id)sender
{
	if([self storeUsageHistory]) {
		[cwh markConnectionAsClosed];
	}
	if(carrierNameTimer != nil) {
		[carrierNameTimer invalidate];
		carrierNameTimer = nil;
	}
	lastSignalStrength = -1;
	[self clearAllUI];
	
	NSAttributedString *emptyAttributedString = [[[NSAttributedString alloc] initWithString:@""] autorelease];
	[statusItem setAttributedTitle:emptyAttributedString];
	[statusItem setToolTip:@"CheetahWatch - No modem detected"];
	[statusItemConectedFor setTitle:@"No modem connected"];
	[connectedInStatus setStringValue:@"No modem connected"];
}

-(void)haveModemMain:(id)ignore
{
	if([statusItemMenu indexOfItem:statusItemConnect] < 0) {
		[statusItemMenu insertItem:statusItemConnect atIndex:([statusItemMenu indexOfItem:statusItemConectedFor] + 1)];
	}
	[statusWindowDisonnect setHidden:YES];
	[statusWindowConnect setHidden:NO];
	carrierNameTimer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(sendCarrierRequest:) userInfo:nil repeats:YES];
}

// called by the monitor thread to say "hoorah! w00t!"
-(void)haveModem
{
//	NSImage *imageFromBundle = [NSImage imageNamed:@"have-modem.png"];
	[statusItem setTitle:@"?"]; 
	//[status setImage: imageFromBundle];
	[self clearAllUI];
	[self setSignalStrength:0];
	[self performSelectorOnMainThread:@selector(haveModemMain:) withObject:nil waitUntilDone:YES];
	[statusItemConectedFor setTitle:@"Not connected"];
	[connectedInStatus setStringValue:@"Not connected"];
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
	[self updateHistory];
}

-(void)clearUsageHistory:(id)sender
{
	if([self storeUsageHistory]) {
		[cwh clearHistory];
		[self updateHistory];
	}
}

-(void)makeTheWindowCompactAnimating:(BOOL)animated
{
	NSRect frame = [theWindow frame];
	
	float newHeight = 138;
	[statsBox setHidden:YES];
	[statsBoxSubstitute setHidden:NO];

	frame.origin.y += frame.size.height - newHeight;
	frame.size.height = newHeight;
	
	[theWindow setFrame:frame display:YES animate:animated];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"CWShowStatsBox"];
}

-(void)makeTheWindowBigAnimating:(BOOL)animated
{
	NSRect frame = [theWindow frame];
	
	float newHeight = 248;
		[statsBox setHidden:NO];
		[statsBoxSubstitute setHidden:YES];

	frame.origin.y += frame.size.height - newHeight;
	frame.size.height = newHeight;
	
	[theWindow setFrame:frame display:YES animate:animated];
	
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"CWShowStatsBox"];
}

-(void)handleDisclosureTriangleFun:(id)sender
{
	NSRect frame = [theWindow frame];
	
	if(frame.size.height != 138) {
		[self makeTheWindowCompactAnimating:YES];
	} else {
		[self makeTheWindowBigAnimating:YES];
	}
	
}

-(void)connectNetworkTimeoutCheck:(id)sender
{
	SCNetworkConnectionStatus lStat = SCNetworkConnectionGetStatus (scncRef);
	
	if(lStat == kSCNetworkConnectionConnected) { // we've connected, stop now
		return;
	}
	if(lStat == kSCNetworkConnectionConnecting) { // we're connecting still
		[statusItemConectedFor setTitle:@"Connecting..."];
		[connectedInStatus setStringValue:@"Connecting..."];
		[self performSelector:@selector(connectNetworkTimeoutCheck:) withObject:sender afterDelay:1];
		return;
	}
	if(lStat == kSCNetworkConnectionDisconnecting) {
		[statusItemConectedFor setTitle:@"Disconnecting..."];
		[connectedInStatus setStringValue:@"Disconnecting..."];
		[self performSelector:@selector(connectNetworkTimeoutCheck:) withObject:sender afterDelay:1];
		// cancelling out...
		return;
	}
	if(lStat == kSCNetworkConnectionDisconnected) {
		// cancelled out...
		[statusItemConectedFor setTitle:@"Not connected"];
		[connectedInStatus setStringValue:@"Not connected"];
		if([statusItemMenu indexOfItem:statusItemDisconnect] != -1) {
			[statusItemMenu removeItem:statusItemDisconnect];		
			if([statusItemMenu indexOfItem:statusItemConnect] == -1) {	
				[statusItemMenu insertItem:statusItemConnect atIndex:([statusItemMenu indexOfItem:statusItemConectedFor] + 1)];
			}
		}
		[statusWindowConnect setHidden:NO];
		[statusWindowDisonnect setHidden:YES];

		return;
	}	
}

-(BOOL)showStatusOnConnecting
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"CWShowStatusWhileConnecting"];
}


-(void)connectNetwork:(id)sender
{	
	if([self showStatusOnConnecting]) {
		[NSApp activateIgnoringOtherApps:YES];
		[theWindow makeKeyAndOrderFront:self];
		shouldHideStatusWhenConnected = YES;
	}
	
	SCNetworkConnectionStart(scncRef, userOptions, true);
	[statusItemConectedFor setTitle:@"Connecting..."];
	[connectedInStatus setStringValue:@"Connecting..."];
	[self performSelector:@selector(connectNetworkTimeoutCheck:) withObject:sender afterDelay:1];
	
	int index = [statusItemMenu indexOfItem:statusItemConnect];
	if(index != -1) {
		[statusItemMenu removeItem:statusItemConnect];		
		if([statusItemMenu indexOfItem:statusItemDisconnect] == -1) {
			[statusItemMenu insertItem:statusItemDisconnect atIndex:([statusItemMenu indexOfItem:statusItemConectedFor] + 1)];
		}
	}
	
	[statusWindowConnect setHidden:YES];
	[statusWindowDisonnect setHidden:NO];

}

-(void)disconnectNetworkTimeoutCheck:(id)sender
{
	SCNetworkConnectionStatus lStat = SCNetworkConnectionGetStatus (scncRef);	
	if(lStat == kSCNetworkConnectionDisconnecting) {
		[statusItemConectedFor setTitle:@"Disconnecting..."];
		[connectedInStatus setStringValue:@"Disconnecting..."];
		[self performSelector:@selector(disconnectNetworkTimeoutCheck:) withObject:sender afterDelay:1];
		return;
	}
}

-(void)disconnectNetwork:(id)sender
{	
	SCNetworkConnectionStop(scncRef, true);
	[self performSelector:@selector(disconnectNetworkTimeoutCheck:) withObject:sender afterDelay:1];
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

-(NSString*)prettyDataAmount64:(SInt64)bytes
{
	if(bytes < 1024) // bytes
		return [NSString stringWithFormat:@"%.0fB", (double)bytes];
	if(bytes < (1024 * 1024)) // KB
		return [NSString stringWithFormat:@"%.1fKB", ((double)bytes / 1024)];
	if(bytes < (1024 * 1024 * 1024)) // MB
		return [NSString stringWithFormat:@"%.1fMB", ((double)bytes / (1024 * 1024))];
	return [NSString stringWithFormat:@"%.1fGB", ((double)bytes / (1024 * 1024 * 1024))];
}

-(NSString*)prettyTime:(SInt32)seconds
{
	int SecondsConnected = seconds;
	float MinutesConnected = SecondsConnected / 60;	
	float HoursConnected = MinutesConnected / 60;	
	float DaysConnected = HoursConnected / 24;
	
	int justSecondsConnected = (SecondsConnected - ((int)MinutesConnected * 60 ));
	int justMinutesConnected = (MinutesConnected - ((int)HoursConnected * 60 ));
	int justHoursConnected = (HoursConnected - ((int)DaysConnected * 24 ));
	
	if(seconds < 60) // X seconds
		return [NSString stringWithFormat:@"%d seconds", seconds];
	if(seconds < (60 * 60)) // X:X minutes
		return [NSString stringWithFormat:@"00:%.2d:%.2d", (int)MinutesConnected, justSecondsConnected];
	if(seconds < (60 * 60 * 24)) // X:X:X
		return [NSString stringWithFormat:@"%.2d:%.2d:%.2d", (int)HoursConnected, justMinutesConnected, justSecondsConnected];
	return [NSString stringWithFormat:@"%.0f days, %.0f:%.2d:%.2d", DaysConnected, justHoursConnected, justMinutesConnected, justSecondsConnected];
}

// called by the secondary thread flowReport, notifies History of update
-(void)flowReport2:(id)nothing
{
//	[uptime setStringValue:[self prettyTime:[currentUptime intValue]]];
	
	if(shouldHideStatusWhenConnected) {
		[theWindow performClose:self];
		shouldHideStatusWhenConnected = NO;
	}
	if(!connected) {
		connected = YES;
		NSLog(@"flowReport2 calling setSignalStrength with %i", lastSignalStrength);
		[self setSignalStrength:lastSignalStrength];
	}
	connected = YES;
	
	[speedReceive setStringValue:[[self prettyDataAmount:[currentSpeedReceive intValue]] stringByAppendingString:@"ps"]];
	[speedTransmit setStringValue:[[self prettyDataAmount:[currentSpeedTransmit intValue]] stringByAppendingString:@"ps"]];
	
	[transferReceive setStringValue:[self prettyDataAmount64:[currentReceived longLongValue]]];
	[transferTransmit setStringValue:[self prettyDataAmount64:[currentTransmitted longLongValue]]];
	
	NSString *tooltip = [NSString stringWithFormat:@"CheetahWatch - %@ down / %@ up", 
									[self prettyDataAmount64:[currentReceived longLongValue]],
									[self prettyDataAmount64:[currentTransmitted longLongValue]]];
									
									
	NSString *connectedFor = [NSString stringWithFormat:@"Connected %@", [self prettyTime:[currentUptime intValue]]];
	
	[statusItem setToolTip:tooltip];
	[statusItemConectedFor setTitle:connectedFor];
	[connectedInStatus setStringValue:connectedFor];
	
	int index = [statusItemMenu indexOfItem:statusItemConnect];
	if(index != -1) {
		[statusItemMenu removeItem:statusItemConnect];	
		if([statusItemMenu indexOfItem:statusItemDisconnect] == -1) {
			[statusItemMenu insertItem:statusItemDisconnect atIndex:([statusItemMenu indexOfItem:statusItemConectedFor] + 1)];	
		}
	}	
	[statusWindowConnect setHidden:YES];
	[statusWindowDisonnect setHidden:NO];

	
//	[statusItemConnect setEnabled:NO];//

	if([self storeUsageHistory]) {
		[cwh flowReportSeconds:currentUptime withTransmitRate:currentSpeedTransmit
			receiveRate:currentSpeedReceive 
			totalSent:currentTransmitted 
			andTotalReceived:currentReceived];
		[self updateHistory];
	}	
}

-(void)setAPN:(NSString*)theApn
{
	[modemInfoAPN setStringValue:theApn];
}
-(void)setHardwareVersion:(NSString*)theVersion
{
	[modemInfoHWVersion setStringValue:theVersion];
}
-(void)setIMEI:(NSString*)theIMEI
{
	[modemInfoIMEI setStringValue:theIMEI];
}


-(void)sendAPNATCommands:(id)sender
{
	NSLog(@"[CWMain sendAPNATCommands:] is deprecated.");
}

-(void)startAPNATCommandsTimer:(id)sender
{	
	[[atWorker performThreadedWithTarget:self afterDelay:5] sendATCommand:@"AT+CGDCONT?\r" toDevice:fd];
	[[atWorker performThreadedWithTarget:self afterDelay:5] sendATCommand:@"AT+CGDCONT?\r" toDevice:fd];
}

-(void)sendATCommandsTimerAction:(id)thing
{
	NSLog(@"[CWMain sendATCommandsTimerAction:] is deprecated.");
}

-(void)sendATCommandsTimer:(id)thing
{
	[[atWorker performThreadedWithTarget:self afterDelay:1] sendATCommand:thing toDevice:fd];
}

-(void)sendCarrierRequest:(NSTimer*)timer
{
	[[atWorker performThreadedWithTarget:self] sendATCommand:@"AT+COPS?\r" toDevice:fd];
}

#pragma mark -
#pragma mark Modem interface thread

// this is the quasi-runloop (yeah, whatever) that follows the stream from the modem
// the functions below are all run on the second thread.
+ (void)MyRunner:(CWMain*)mainController
{
	int bytes;
	char *buf_stream, *buf_lineStart;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	buf_stream=(char *)malloc(BUFSIZE*sizeof(char));
	fd = open(MODEMUIDEV, O_RDWR | O_NOCTTY | O_NDELAY ); 
	if (fd < 0) {
		[mainController performSelectorOnMainThread:@selector(noModem:) withObject:nil waitUntilDone:YES];
		[pool release];
		free(buf_stream);
		return;
	}	
	[mainController haveModem];
	
	NSString *a;
	a = [mainController GetATResult:@"AT+CGSN\r" forDev:fd];
	
	const char *thisResult = [a cStringUsingEncoding:NSStringEncodingConversionExternalRepresentation];
	
	if(thisResult[0] >= '0' && thisResult[0] <= '9') {
		 
		a = [mainController GetATResult:@"AT+CGSN\r" forDev:fd];
		 
	 }
	
	[mainController performSelectorOnMainThread:@selector(setIMEI:) 
									 withObject:a
								  waitUntilDone:YES];
						
	BOOL waitingOnAPN = YES;
	[mainController startAPNATCommandsTimer:nil];
//	[mainController performSelectorOnMainThread:@selector(startAPNATCommandsTimer:) withObject:nil waitUntilDone:NO];

	BOOL waitingOnCarrierName = YES;
	[mainController sendCarrierRequest:nil];
	[mainController sendATCommandsTimer:@"AT+CSQ\r"];	
	[mainController sendATCommandsTimer:@"AT^HWVER\r"];
	
	while(bytes = read(fd,buf_stream,255)){
		buf_lineStart=strchr(buf_stream,'^');
		if(buf_lineStart == 0) {
			buf_lineStart=strchr(buf_stream,'+');
		}
		buf_stream[bytes]=0x00;  
		if (buf_lineStart) {
			strcpy(buf_stream, buf_lineStart); 
			if (buf_stream[0]=='^') {
				switch (buf_stream[1]) {
					case 'D': [mainController flowReport:(buf_stream+11)]; break;
					case 'M': [mainController modeChange:(buf_stream+8)]; break;
					case 'R': [mainController signalStrength:(buf_stream+6)]; break;
					case 'H': [mainController gotHWVersion:(buf_stream+7)]; break;
					case 'B': break;
				}
			}
			if (buf_stream[0]=='+') {
				if(buf_stream[1] == 'C' && buf_stream[2] == 'G') {
					if(buf_stream[8] == '?' && waitingOnAPN) {
						[mainController performSelectorOnMainThread:@selector(startAPNATCommandsTimer:) withObject:nil waitUntilDone:NO];
					} else if(buf_stream[8] == ':') {
						[mainController gotAPN:(buf_stream+8)];
						waitingOnAPN = NO;
					}
				}
				if(buf_stream[1] == 'C' && buf_stream[2] == 'S' && buf_stream[3] == 'Q') {
					[mainController signalStrengthFromCSQ:(buf_stream+6)];
				}
				if(buf_stream[1] == 'C' && buf_stream[2] == 'O' && buf_stream[3] == 'P' && buf_stream[4] == 'S') {
					if(buf_stream[5] == '?' && waitingOnCarrierName) {
						[mainController sendCarrierRequest:nil];
					} else if (buf_stream[5] == ':') {
						waitingOnCarrierName = NO;
						[mainController gotCarrier:(buf_stream+5)];
					}
				}
				if(buf_stream[1] == 'C' && buf_stream[2] == 'M' && buf_stream[3] == 'E') {
					// this is probably an error condition
					//[mainController gotCME:(buf_stream+4)];
				}
			}
		}	
	}
	[mainController performSelectorOnMainThread:@selector(noModem:) withObject:nil waitUntilDone:YES];
    [pool release];
	free(buf_stream); 
}


-(void)gotHWVersion:(char*)buff
{
	
	NSString *version = [NSString stringWithCString:(buff + 1) encoding:NSStringEncodingConversionExternalRepresentation];
	if([version length] > 0) {		
		if([version rangeOfString:@"\""].location > [version length]) {
		} else {
			version = [version substringWithRange:NSMakeRange(0,[version rangeOfString:@"\""].location)];
		}
	}	
	[self performSelectorOnMainThread:@selector(setHardwareVersion:) 
									 withObject:version waitUntilDone:NO];
}

-(void)gotAPN:(char*)buff
{
	NSString *apn = [[NSString stringWithCString:buff encoding:NSStringEncodingConversionExternalRepresentation] substringFromIndex:10];
//	NSLog(@"Location of ,: %i", [apn rangeOfString:@","].location);
	if([apn rangeOfString:@","].location < [apn length]) {
		apn = [apn substringToIndex:([apn rangeOfString:@","].location - 1)];	
		[self performSelectorOnMainThread:@selector(setAPN:) withObject:apn waitUntilDone:YES];
	} 
}

-(void)gotCarrier:(char*)buff
{
	NSString *carrier = [NSString stringWithCString:buff encoding:NSStringEncodingConversionExternalRepresentation];	
	if(!([carrier rangeOfString:@","].location < [carrier length])) {
		return;
	}
	
	NSArray *carrierComponents = [carrier componentsSeparatedByString:@","];	
	NSString *newCarrier = @"";
	
	if([[carrierComponents objectAtIndex:1] integerValue] == 2) {		
		NSString *code = [carrierComponents objectAtIndex:2];		
		NSRange country = NSMakeRange(1, 3);
		NSRange network = NSMakeRange(4, 2);
		NSInteger c = [[code substringWithRange:country] integerValue];
		NSInteger n = [[code substringWithRange:network] integerValue];
		newCarrier = [networks displayNameForCountry:c andNetwork:n];
	} else {
		NSString *name = [carrierComponents objectAtIndex:2];		
		NSInteger stringLength = [name length];
		NSRange interior = NSMakeRange(1, stringLength - 2);
		newCarrier = [name substringWithRange:interior];
	}
	if(![carrier isEqualToString:@""]) {
		[carrierInMenu performSelectorOnMainThread:@selector(setTitle:) withObject:[@"Carrier: " stringByAppendingString:newCarrier] waitUntilDone:NO];
		[carrierInStatus performSelectorOnMainThread:@selector(setStringValue:) withObject:newCarrier waitUntilDone:NO];
	}
}

-(void)setSignalStrength:(NSInteger)z_signal
{
	if(z_signal > 31) NSLog(@"Claimed that signal was %i\n", z_signal);
	if(z_signal > 31) z_signal = 0;
	
	lastSignalStrength = z_signal;
	[signal setIntValue:z_signal];
	
	NSString *suffix = (connected ? @".tif" : @"-off.tif");
		
	NSString *which;
	if(z_signal == -1) which = @"no-modem-menu.tif";
	else if(z_signal == 0) which = [@"signal-0" stringByAppendingString:suffix];
	else if(z_signal < 10) which = [@"signal-1" stringByAppendingString:suffix];
	else if(z_signal < 15) which = [@"signal-2" stringByAppendingString:suffix];
	else if(z_signal < 20) which = [@"signal-3" stringByAppendingString:suffix];
	else if(z_signal >= 20) which = [@"signal-4" stringByAppendingString:suffix];
	
	
	[self performSelectorOnMainThread:@selector(changeStatusImageTo:) withObject:which waitUntilDone:YES];		
}

-(void)signalStrengthFromCSQ:(char*)buff
{
	NSString *strength = [NSString stringWithCString:buff encoding:NSStringEncodingConversionExternalRepresentation];	
	if([strength rangeOfString:@","].location < [strength length]) {
		strength = [strength substringToIndex:([strength rangeOfString:@","].location)];
		//NSLog(@"Signal Strength From CSQ is: %@", strength);
		[self setSignalStrength:atoi([strength cStringUsingEncoding:NSStringEncodingConversionExternalRepresentation])];
	}
	
}

// Update the signal strength display
-(void)signalStrength:(char*)buff
{
	[self setSignalStrength:atoi(buff)];
}

// Update the signal strength meter (on main thread)
-(void)changeStatusImageTo:(NSString*)which
{
	[statusItem setImage:[NSImage imageNamed:which]];
}

// Process a mode update
-(void)modeChange:(char*)buff
{
	buff[1] = 0x00;
	NSString *newMode = [NSString stringWithCString:buff
										   encoding:NSStringEncodingConversionExternalRepresentation];
	[self performSelectorOnMainThread:@selector(modeChangeAction:) withObject:newMode waitUntilDone:YES];
}

// Update the "mode" displays (on main thread)
-(void)modeChangeAction:(NSString*)newMode
{

	NSString *menuMode;

	switch ([newMode cStringUsingEncoding:NSStringEncodingConversionExternalRepresentation][0]) {
		case '0':
			menuMode = @""; 
			[mode setStringValue:@"None"];
			break;
		case '1':
			menuMode = @" G"; 
			[mode setStringValue:@"GPRS"];
			break;
		case '2':
			menuMode = @" G"; 
			[mode setStringValue:@"GPRS"];
			break;
		case '3':
			menuMode = @" E"; 
			[mode setStringValue:@"EDGE"];
			break;
		case '4':
			menuMode = @" W"; 
			[mode setStringValue:@"WCDMA"];
			break;
		case '5':
			menuMode = @" H"; 
			[mode setStringValue:@"HSDPA"];
			break;
		default:
			menuMode = @""; 
			[mode setStringValue:@"Unknown"];
	}

	NSFont *menuFont = [NSFont fontWithName:@"Monaco" size:10.0];
	NSDictionary *stringAttributes = [NSDictionary dictionaryWithObject:menuFont forKey:NSFontAttributeName];
	NSAttributedString *lowerString = [[NSAttributedString alloc] initWithString:menuMode attributes:stringAttributes];
	[statusItem setAttributedTitle:lowerString];
	[lowerString release];

}

// Update the connection time, speed, and data moved display
-(void)flowReport:(char*)buff
{
	unsigned int SecondsConnected, SpeedTransmit, SpeedReceive;
	UInt64 Transmitted, Received;
	
	char *TransmittedC, *TransmittedC2;
	TransmittedC = (char *)malloc(BUFSIZE*sizeof(char));

	sscanf(buff,"%X,%X,%X,%s", &SecondsConnected,&SpeedTransmit,&SpeedReceive,&*TransmittedC);

	Transmitted = strtoull(TransmittedC, &TransmittedC2, 16);
	Received = strtoull((TransmittedC2+1), NULL, 16);

	free(TransmittedC);
	
	currentUptime = [NSNumber numberWithInt:SecondsConnected];
	currentSpeedReceive = [NSNumber numberWithInt:SpeedReceive];
	currentSpeedTransmit = [NSNumber numberWithInt:SpeedTransmit];
	currentTransmitted = [NSNumber numberWithLongLong:Transmitted];
	currentReceived = [NSNumber numberWithLongLong:Received];

	[self performSelectorOnMainThread:@selector(flowReport2:) withObject:nil waitUntilDone:YES];
}

-(NSString*)GetATResult:(NSString*)command forDev:(int)dev
{
	int bytes;
	char *buf_stream, *buf_lineStart, *buf_scanned;
	buf_stream=(char *)malloc(BUFSIZE*sizeof(char));
	buf_scanned=(char *)malloc(BUFSIZE*sizeof(char));
	NSString *returnValue;
	
	returnValue = @"";
	
	write(dev, [command cStringUsingEncoding:NSStringEncodingConversionExternalRepresentation], ([command lengthOfBytesUsingEncoding:NSStringEncodingConversionExternalRepresentation] + 1));
	read(dev,buf_stream,255);
	bytes = read(dev,buf_stream,255);
	buf_lineStart=strchr(buf_stream,'\n');
	buf_stream[bytes]=0x00;  
	if (buf_lineStart) {
		strcpy(buf_stream, buf_lineStart); 
		if (buf_stream[0]=='\n') {
			sscanf(buf_stream, "\n%[^\r\n]", buf_scanned);
			returnValue =  [NSString stringWithCString:buf_scanned encoding:NSStringEncodingConversionExternalRepresentation];
		}
	}	
	
	free(buf_stream);
	free(buf_scanned);
	return returnValue;
}

-(void)sendATCommand:(NSString*)command toDevice:(int)dev
{		
	char *buf_stream;
	buf_stream=(char *)malloc(BUFSIZE*sizeof(char));
	write(dev, [command cStringUsingEncoding:NSStringEncodingConversionExternalRepresentation], [command lengthOfBytesUsingEncoding:NSStringEncodingConversionExternalRepresentation]);
	read(dev,buf_stream,255);
	free(buf_stream);
}

#pragma mark -
#pragma mark USB Finder thread has moved to CWUSBFinder.m/.h

@end