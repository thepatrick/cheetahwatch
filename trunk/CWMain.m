/* CheetahWatch, v1.2
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

#import "CWMain.h"

@implementation CWMain

+(void)initialize
{
	NSMutableDictionary *dd = [NSMutableDictionary dictionaryWithObject:@"YES" forKey:@"CWStoreHistory"];
	[dd setValue:@"YES" forKey:@"CWFirstRun"];
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

	[signal setEnabled:NO]; //disables user interaction, enabled by default

	[status setImage:[NSImage imageNamed:@"no-modem.png"]];
	
	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
	[statusItem setHighlightMode:YES];
	[statusItem setEnabled:YES];
	[statusItem setToolTip:@"CheetahWatch"];
	[statusItem setAttributedTitle:@""];
	[statusItem setToolTip:@"CheetahWatch - No modem detected"];
	[statusItem setMenu:statusItemMenu];		
	[statusItemConnect retain];
	[statusItemDisconnect retain];

	[self performSelectorOnMainThread:@selector(changeStatusImageTo:) withObject: @"no-modem-menu.tif" waitUntilDone:NO];	
	if([self storeUsageHistory]) {
		cwh = [[CWHistorySupport alloc] init];	
		[cwh setMainController:self];
		[cwh setupCoreData];	
	}
	[NSThread detachNewThreadSelector:@selector(USBFinder:) toTarget:[CWMain class] withObject:self];
	[self clearAllUI];
	[self updateHistory];
	[self makeMenuMatchStorageHistory];
	[self setupDialing];	
	[self showFirstRun];
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
	[signal setIntValue:0];
	[mode setStringValue:@""];	
	[statusItem setTitle:@""];
	[carrierInMenu setTitle:@"Carrier:"];
	
	[self setHardwareVersion:@""];
	[self setIMEI:@""];
	if([statusItemMenu indexOfItem:statusItemDisconnect] != -1) {
		[statusItemMenu removeItem:statusItemDisconnect];
	}
	if([statusItemMenu indexOfItem:statusItemConnect] != -1) {
		[statusItemMenu removeItem:statusItemConnect];
	}	
	[self clearConnectionUI];
	[statusItemConectedFor setTitle:@"No modem connected"];
}

-(void)clearConnectionUI
{
	[speedReceive setStringValue:@""];
	[speedTransmit setStringValue:@""];
	[transferReceive setStringValue:@""];
	[transferTransmit setStringValue:@""];
	[uptime setStringValue:@""];
	[statusItem setToolTip:@"CheetahWatch - Not connected"];
	[statusItemConectedFor setTitle:@"Not connected"];
	if([statusItemMenu indexOfItem:statusItemDisconnect] != -1) {
		[statusItemMenu removeItem:statusItemDisconnect];	
		if([statusItemMenu indexOfItem:statusItemConnect] == -1) {
			[statusItemMenu insertItem:statusItemConnect atIndex:([statusItemMenu indexOfItem:statusItemConectedFor] + 1)];
		}
	}
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
	[self clearAllUI];
	NSImage *imageFromBundle = [NSImage imageNamed:@"no-modem.png"];
	[status setImage: imageFromBundle];
	[statusItem setAttributedTitle:@""];
	[statusItem setToolTip:@"CheetahWatch - No modem detected"];
	[statusItemConectedFor setTitle:@"No modem connected"];
	[self performSelectorOnMainThread:@selector(changeStatusImageTo:) withObject: @"no-modem-menu.tif" waitUntilDone:NO];
}

-(void)haveModemMain:(id)ignore
{
	if([statusItemMenu indexOfItem:statusItemConnect] < 0) {
		[statusItemMenu insertItem:statusItemConnect atIndex:([statusItemMenu indexOfItem:statusItemConectedFor] + 1)];
	}
}

// called by the monitor thread to say "hoorah! w00t!"
-(void)haveModem
{
	NSImage *imageFromBundle = [NSImage imageNamed:@"have-modem.png"];
	[statusItem setTitle:@"?"]; 
	[status setImage: imageFromBundle];
	[self clearAllUI];
	[self performSelectorOnMainThread:@selector(changeStatusImageTo:) withObject: @"signal-0.tif" waitUntilDone:NO];
	[self performSelectorOnMainThread:@selector(haveModemMain:) withObject:nil waitUntilDone:YES];
	[statusItemConectedFor setTitle:@"Not connected"];
	carrierNameTimer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(sendCarrierRequest:) userInfo:nil repeats:YES];
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

-(void)connectNetworkTimeoutCheck:(id)sender
{
	SCNetworkConnectionStatus lStat = SCNetworkConnectionGetStatus (scncRef);
	
	if(lStat == kSCNetworkConnectionConnected) { // we've connected, stop now
		return;
	}
	if(lStat == kSCNetworkConnectionConnecting) { // we're connecting still
		[statusItemConectedFor setTitle:@"Connecting..."];
		[self performSelector:@selector(connectNetworkTimeoutCheck:) withObject:sender afterDelay:1];
		return;
	}
	if(lStat == kSCNetworkConnectionDisconnecting) {
		[statusItemConectedFor setTitle:@"Disconnecting..."];
		[self performSelector:@selector(connectNetworkTimeoutCheck:) withObject:sender afterDelay:1];
		// cancelling out...
		return;
	}
	if(lStat == kSCNetworkConnectionDisconnected) {
		// cancelled out...
		[statusItemConectedFor setTitle:@"Not connected"];
		if([statusItemMenu indexOfItem:statusItemDisconnect] != -1) {
			[statusItemMenu removeItem:statusItemDisconnect];	
			if([statusItemMenu indexOfItem:statusItemConnect] == -1) {
				[statusItemMenu insertItem:statusItemConnect atIndex:([statusItemMenu indexOfItem:statusItemConectedFor] + 1)];
			}
		}
		return;
	}	
}

-(void)connectNetwork:(id)sender
{	
	SCNetworkConnectionStart(scncRef, userOptions, true);
	[statusItemConectedFor setTitle:@"Connecting..."];
	[self performSelector:@selector(connectNetworkTimeoutCheck:) withObject:sender afterDelay:1];
	
	int index = [statusItemMenu indexOfItem:statusItemConnect];
	if(index != -1) {
		[statusItemMenu removeItem:statusItemConnect];	
		if([statusItemMenu indexOfItem:statusItemDisconnect] == -1) {
			[statusItemMenu insertItem:statusItemDisconnect atIndex:([statusItemMenu indexOfItem:statusItemConectedFor] + 1)];
		}
	}
}

-(void)disconnectNetworkTimeoutCheck:(id)sender
{
	SCNetworkConnectionStatus lStat = SCNetworkConnectionGetStatus (scncRef);	
	if(lStat == kSCNetworkConnectionDisconnecting) {
		[statusItemConectedFor setTitle:@"Disconnecting..."];
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
	[uptime setStringValue:[self prettyTime:[currentUptime intValue]]];
	
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
	
	int index = [statusItemMenu indexOfItem:statusItemConnect];
	if(index != -1) {
		[statusItemMenu removeItem:statusItemConnect];	
		if([statusItemMenu indexOfItem:statusItemDisconnect] == -1) {
			[statusItemMenu insertItem:statusItemDisconnect atIndex:([statusItemMenu indexOfItem:statusItemConectedFor] + 1)];
		}
	}
	
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
	NSLog(@"Passing AT command to atWorker.");
	[[atWorker performThreadedWithTarget:self afterDelay:1] sendATCommand:thing toDevice:fd];
}

-(void)sendCarrierRequest:(NSTimer*)timer
{
//	[self sendATCommandsTimerAction:@"AT+COPS?\r"];
	[[atWorker performThreadedWithTarget:self] sendATCommand:@"AT+COPS?\r" toDevice:fd];
}

#pragma mark Modem interface thread

// this is the quasi-runloop (yeah, whatever) that follows the stream from the modem
// the functions below are all run on the second thread.
+ (void)MyRunner:(id)mainController
{
	int bytes;
	char *buf_stream, *buf_lineStart;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	buf_stream=(char *)malloc(BUFSIZE*sizeof(char));
	fd = open(MODEMUIDEV, O_RDWR | O_NOCTTY ); 
	if (fd < 0) {
		[mainController performSelectorOnMainThread:@selector(noModem:) withObject:nil waitUntilDone:YES];
		[pool release];
		free(buf_stream);
		return;
	}	
	[mainController haveModem];
	
	[mainController performSelectorOnMainThread:@selector(setIMEI:) 
									 withObject:[mainController GetATResult:@"AT+CGSN\r" forDev:fd]
								  waitUntilDone:YES];
						
	BOOL waitingOnAPN = YES;
	[mainController performSelectorOnMainThread:@selector(startAPNATCommandsTimer:) withObject:nil waitUntilDone:NO];

	BOOL waitingOnCarrierName = YES;
	[mainController performSelectorOnMainThread:@selector(sendATCommandsTimer:) withObject:@"AT+COPS?\r" waitUntilDone:NO];	
	[mainController performSelectorOnMainThread:@selector(sendATCommandsTimer:) withObject:@"AT+CSQ\r" waitUntilDone:NO];	
	[mainController performSelectorOnMainThread:@selector(sendATCommandsTimer:) withObject:@"AT^HWVER\r" waitUntilDone:NO];
	
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
						printf("APN, but not with details. Try again.");
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
						[mainController performSelectorOnMainThread:@selector(sendATCommandsTimer:) withObject:@"AT+COPS?\r" waitUntilDone:NO];
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
	NSString *version = [NSString stringWithCString:(buff + 1)];
	if([version length] > 0) {
		//NSLog(@"\" location in version: %i", [version rangeOfString:@"\""].location);
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
	NSString *apn = [[NSString stringWithCString:buff] substringFromIndex:10];
//	NSLog(@"Location of ,: %i", [apn rangeOfString:@","].location);
	if([apn rangeOfString:@","].location < [apn length]) {
		apn = [apn substringToIndex:([apn rangeOfString:@","].location - 1)];	
		[self performSelectorOnMainThread:@selector(setAPN:) withObject:apn waitUntilDone:YES];
	} 
}

-(void)gotCarrier:(char*)buff
{
	NSString *carrier = [NSString stringWithCString:buff];	
	if([carrier rangeOfString:@"\""].location < [carrier length]) {
		carrier = [carrier substringFromIndex:([carrier rangeOfString:@"\""].location + 1)];
		if([carrier rangeOfString:@"\""].location < [carrier length]) {
			carrier = [carrier substringToIndex:([carrier rangeOfString:@"\""].location)];
			[carrierInMenu performSelectorOnMainThread:@selector(setTitle:) withObject:[@"Carrier: " stringByAppendingString:carrier] waitUntilDone:NO];
		}
	}
}

-(void)doSetSignalStrength:(int)z_signal
{
	//NSLog(@"doSetSignalStrength:%i",z_signal);
	if(z_signal > 31) NSLog(@"Claimed that signal was %i\n", z_signal);
	if(z_signal > 31) z_signal = 0;
	[signal setIntValue:z_signal];
	
	NSString *which;
	if(z_signal == 0) which = @"signal-0.tif";
	else if(z_signal < 10) which = @"signal-1.tif";
	else if(z_signal < 15) which = @"signal-2.tif";
	else if(z_signal < 20) which = @"signal-3.tif";
	else if(z_signal >= 20) which = @"signal-4.tif";
	
	[self performSelectorOnMainThread:@selector(changeStatusImageTo:) withObject:which waitUntilDone:YES];		
}

-(void)signalStrengthFromCSQ:(char*)buff
{
	NSString *strength = [NSString stringWithCString:buff];	
	if([strength rangeOfString:@","].location < [strength length]) {
		strength = [strength substringToIndex:([strength rangeOfString:@","].location)];
		//NSLog(@"Signal Strength From CSQ is: %@", strength);
		[self doSetSignalStrength:atoi([strength cString])];
	}
	
}

// Update the signal strength display
-(void)signalStrength:(char*)buff
{
	[self doSetSignalStrength:atoi(buff)];
}

// Update the signal strength meter (on main thread)
-(void)changeStatusImageTo:(NSString*)which
{
	[statusItem setImage:[NSImage imageNamed:which]];
}

// Process a mode update
-(void)modeChange:(char*)buff
{
	NSString *newMode = [NSString stringWithCString:buff length:1];
	[self performSelectorOnMainThread:@selector(modeChangeAction:) withObject:newMode waitUntilDone:YES];
}

// Update the "mode" displays (on main thread)
-(void)modeChangeAction:(NSString*)newMode
{

	NSString *menuMode;

	switch ([newMode cString][0]) {
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
	
	write(dev, [command cString], [command cStringLength]);
	read(dev,buf_stream,255);
	bytes = read(dev,buf_stream,255);
	buf_lineStart=strchr(buf_stream,'\n');
	buf_stream[bytes]=0x00;  
	if (buf_lineStart) {
		strcpy(buf_stream, buf_lineStart); 
		if (buf_stream[0]=='\n') {
			sscanf(buf_stream, "\n%[^\r\n]", buf_scanned);
			returnValue =  [NSString stringWithCString:buf_scanned];
		}
	}	
	
	free(buf_stream);
	free(buf_scanned);
	return returnValue;
}

-(void)sendATCommandThread:(NSString*)command
{
	NSLog(@"sendATCommandThread starting...");
	[self sendATCommand:command toDevice:fd];
	NSLog(@"sendATCommandThread ending.");
}

-(void)sendATCommand:(NSString*)command toDevice:(int)dev
{		
	char *buf_stream;
	buf_stream=(char *)malloc(BUFSIZE*sizeof(char));
	write(dev, [command cString], [command cStringLength]);
	read(dev,buf_stream,255);
	free(buf_stream);
}

#pragma mark USB Finder thread
// This function sets up some stuff to detect a USB device being plugged. be prepared for C...
+(void)USBFinder:(id)mainController
{
    mach_port_t				masterPort;
    CFMutableDictionaryRef 	matchingDict;
    CFRunLoopSourceRef		runLoopSource;
    CFNumberRef				numberRef;
    kern_return_t			kr;
    long					usbVendor = kMyVendorID;
    long					usbProduct = kMyProductID;
	
	gCWMain = mainController;
	
    // first create a master_port for my task
    kr = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if (kr || !masterPort) {
        printf("ERR: Couldn't create a master IOKit Port(%08x)\n", kr);
        return;
    }

    matchingDict = IOServiceMatching(kIOUSBDeviceClassName);	// Interested in instances of class
                                                                // IOUSBDevice and its subclasses
    if (!matchingDict) {
        printf("Can't create a USB matching dictionary\n");
        mach_port_deallocate(mach_task_self(), masterPort);
        return;
    }

	numberRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &usbVendor);
    CFDictionarySetValue(matchingDict, CFSTR(kUSBVendorID), numberRef);
    CFRelease(numberRef);
 	
    numberRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &usbProduct);
    CFDictionarySetValue(matchingDict, CFSTR(kUSBProductID), numberRef);
    CFRelease(numberRef);
    numberRef = 0;

    // Create a notification port and add its run loop event source to our run loop
    // This is how async notifications get set up.
    gNotifyPort = IONotificationPortCreate(masterPort);
    runLoopSource = IONotificationPortGetRunLoopSource(gNotifyPort);
    
    gRunLoop = CFRunLoopGetCurrent();
    CFRunLoopAddSource(gRunLoop, runLoopSource, kCFRunLoopDefaultMode);

    // Now set up a notification to be called when a device is first matched by I/O Kit.
    // Note that this will not catch any devices that were already plugged in so we take
    // care of those later.
	// notifyPort, notificationType, matching, callback, refCon, notification
    IOServiceAddMatchingNotification(gNotifyPort, kIOFirstMatchNotification,
									 matchingDict, DeviceAdded, NULL, &gAddedIter);		
    
    // Iterate once to get already-present devices and arm the notification
    DeviceAdded(NULL, gAddedIter);

    // Now done with the master_port
    mach_port_deallocate(mach_task_self(), masterPort);
    masterPort = 0;

    // Start the run loop. Now we'll receive notifications.
    CFRunLoopRun();
}

// this is a (mmm C) callback function when a USB device we care about is connected. 
void DeviceAdded(void *refCon, io_iterator_t iterator)
{
    io_service_t		usbDevice;
    while ( (usbDevice = IOIteratorNext(iterator)) )
    {		
		[gCWMain performSelectorOnMainThread:@selector(startMonitor:) withObject:nil waitUntilDone:YES];
        IOObjectRelease(usbDevice);
    }
}

@end