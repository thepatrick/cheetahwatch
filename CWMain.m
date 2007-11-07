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
	NSMutableDictionary *dd = [NSMutableDictionary dictionaryWithObject:@"YES" forKey:@"CWStoreHistory"];
	[dd setValue:@"YES" forKey:@"CWFirstRun"];
	[[NSUserDefaults standardUserDefaults] registerDefaults:dd];
}

SCNetworkConnectionContext gScncCtx;
SCNetworkConnectionStatus gStat = kSCNetworkConnectionInvalid;

const char *statusMsg (SCNetworkConnectionStatus stat)
{
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

void calloutProc ( 
    SCNetworkConnectionRef connection, 
    SCNetworkConnectionStatus status, 
    void *info )
{
	gStat = status;
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

	if([self storeUsageHistory]) {
		cwh = [[CWHistorySupport alloc] init];	
		[cwh setMainController:self];
		[cwh setupCoreData];	
	}
	
	
	[NSThread detachNewThreadSelector:@selector(USBFinder:) toTarget:[CWMain class] withObject:self];
	
	[self clearAllUI];
	[self updateHistory];

	[self makeMenuMatchStorageHistory];

	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
	[statusItem setHighlightMode:YES];
	[statusItem setEnabled:YES];
	[statusItem setToolTip:@"CheetahWatch"];

	[status setImage:[NSImage imageNamed:@"no-modem.png"]];
	[statusItem setAttributedTitle:@""];
	[statusItem setToolTip:@"CheetahWatch - No modem detected"];
	[self performSelectorOnMainThread:@selector(changeStatusImageTo:) withObject: @"no-modem-menu.tif" waitUntilDone:NO];
	
	[statusItem setMenu:statusItemMenu];

	[self showFirstRun];
	
	CFStringRef serviceID;
	CFDictionaryRef userOptions;
	
	if(SCNetworkConnectionCopyUserPreferences(NULL, &serviceID, &userOptions)) {
		NSLog(@"ServiceID: %@\n", serviceID);
		
		SCNetworkConnectionRef scncRef = SCNetworkConnectionCreateWithServiceID (NULL, serviceID, calloutProc, &gScncCtx);
		
		const char *msg = NULL;
		int err = kSCStatusOK, mainRes = 0;
		
		if (scncRef == NULL) {
			msg = "SCNetworkConnectionCreateWithServiceID failed";
			err = SCError ();
			mainRes = 1;
		} else {
			gStat = SCNetworkConnectionGetStatus (scncRef);
			msg = statusMsg (gStat);
			mainRes = 0;
						
			if (msg != NULL)
				printf ("%s\n", msg);
		}
		
	} else {
		NSLog(@"No service to dial...?");
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
	[sparkler checkUpdates:sender];
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
	
	[self setHardwareVersion:@""];
	[self setIMEI:@""];
	[self setIMSI:@""];	
	[self clearConnectionUI];
}

-(void)clearConnectionUI
{
	[speedReceive setStringValue:@""];
	[speedTransmit setStringValue:@""];
	[transferReceive setStringValue:@""];
	[transferTransmit setStringValue:@""];
	[uptime setStringValue:@""];
	[statusItem setToolTip:@"CheetahWatch - Not connected"];
}

-(void)updateHistory
{
	if([self storeUsageHistory]) {
		[cwh calculateTotalUsage];
		int runningTotalSent = [cwh cachedTotalSent];
		int runningTotalRecv = [cwh cachedTotalRecv];
		[totalReceived setStringValue:[self prettyDataAmount:runningTotalRecv]];
		[totalTransmitted setStringValue:[self prettyDataAmount:runningTotalSent]];
	}
}

// called by the monitor thread to say "no modem!"
- (void)noModem:(id)sender
{
	if([self storeUsageHistory]) {
		[cwh markConnectionAsClosed];
	}	
	[self clearAllUI];
	NSImage *imageFromBundle = [NSImage imageNamed:@"no-modem.png"];
	[status setImage: imageFromBundle];
	[statusItem setAttributedTitle:@""];
	[statusItem setToolTip:@"CheetahWatch - No modem detected"];
	[self performSelectorOnMainThread:@selector(changeStatusImageTo:) withObject: @"no-modem-menu.tif" waitUntilDone:NO];
}

// called by the monitor thread to say "hoorah! w00t!"
-(void)haveModem
{
	NSImage *imageFromBundle = [NSImage imageNamed:@"have-modem.png"];
	[statusItem setTitle:@"?"]; 
	[status setImage: imageFromBundle];
	[self clearAllUI];
	[self performSelectorOnMainThread:@selector(changeStatusImageTo:) withObject: @"signal-0.tif" waitUntilDone:NO];
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
	
	NSString *tooltip = [NSString stringWithFormat:@"CheetahWatch - %@ down / %@ up", 
									[self prettyDataAmount:[currentReceived intValue]],
									[self prettyDataAmount:[currentTransmitted intValue]]];
	
	[statusItem setToolTip:tooltip];


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
-(void)setIMSI:(NSString*)theIMSI
{
	[modemInfoIMSI setStringValue:theIMSI];
}
-(void)getIMSI:(id)sender
{
	NSLog(@"Calling -getIMSI:");
	[self performSelector:@selector(getIMSI2:) withObject:nil afterDelay:5];
}

-(void)getIMSI2:(id)sender
{
	[self sendATCommand:@"AT+CGDCONT?\r" toDevice:fd];
	[self sendATCommand:@"AT+CGDCONT?\r" toDevice:fd];
	
//	NSLog(@"Calling -getIMSI2:");
//	NSString *apn = [[self GetATResult:@"AT+CGDCONT?\r" forDev:fd] substringFromIndex:18];
//	NSLog(@"Location of ,: %i", [apn rangeOfString:@","].location);
//	if([apn rangeOfString:@","].location < [apn length]) {
//		apn = [apn substringToIndex:([apn rangeOfString:@","].location - 1)];	
//		[self performSelectorOnMainThread:@selector(setAPN:) withObject:apn waitUntilDone:YES];
//	} else {
//		NSLog(@"Index out of bounds, try again...");
//		usleep(10000);
//		apn = [self GetATResult:@"AT+CGDCONT?\r" forDev:fd];
//		NSLog(@"Location of ,: %@", apn);
//		usleep(20000);
//		apn = [self GetATResult:@"AT+CGDCONT?\r" forDev:fd];
//		NSLog(@"Location of ,: %@", apn);
//	}

}

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
	[mainController performSelectorOnMainThread:@selector(getIMSI:) withObject:nil waitUntilDone:NO];
		
	[mainController performSelectorOnMainThread:@selector(setIMEI:) 
									 withObject:[mainController GetATResult:@"AT+CGSN\r" forDev:fd]
								  waitUntilDone:YES];
								
//	[mainController performSelectorOnMainThread:@selector(setIMSI:) 
//									 withObject:[mainController GetATResult:@"AT+CIMI\r" forDev:fd]
//								  waitUntilDone:YES];
								  
								  
//	NSString *apn = [[mainController GetATResult:@"AT+CGDCONT?\r" forDev:fd] substringFromIndex:18];
//	NSLog(@"Location of ,: %i", [apn rangeOfString:@","].location);
//	if([apn rangeOfString:@","].location < [apn length]) {
//		apn = [apn substringToIndex:([apn rangeOfString:@","].location - 1)];	
//		[mainController performSelectorOnMainThread:@selector(setAPN:) withObject:apn waitUntilDone:YES];
//	} else {
//		NSLog(@"Index out of bounds, try again...");
//		usleep(10000);
//		apn = [mainController GetATResult:@"AT+CGDCONT?\r" forDev:fd];
//		NSLog(@"Location of ,: %@", apn);
//		usleep(20000);
//		apn = [mainController GetATResult:@"AT+CGDCONT?\r" forDev:fd];
//		NSLog(@"Location of ,: %@", apn);
//	}

	[mainController sendATCommand:@"AT^HWVER\r" toDevice:fd];
	
	while(bytes = read(fd,buf_stream,255)){
		buf_lineStart=strchr(buf_stream,'^');
		if(buf_lineStart == 0) {
			buf_lineStart=strchr(buf_stream,'+');
			printf("\nDidn't find ^, looked for +, found it at: %i\n", buf_lineStart);
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
					if(buf_stream[8] == '?') {
						printf("APN, but not with details. Try again.");
					} else if(buf_stream[8] == ':') {
						[mainController gotAPN:(buf_stream+8)];
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
		NSLog(@"\" location in version: %i", [version rangeOfString:@"\""].location);
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
	NSLog(@"Location of ,: %i", [apn rangeOfString:@","].location);
	if([apn rangeOfString:@","].location < [apn length]) {
		apn = [apn substringToIndex:([apn rangeOfString:@","].location - 1)];	
		[self performSelectorOnMainThread:@selector(setAPN:) withObject:apn waitUntilDone:YES];
	} 
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
	unsigned int SecondsConnected, SpeedTransmit, SpeedReceive, Transmitted, Received;
	sscanf(buff,"%X,%X,%X,%X,%X", &SecondsConnected,&SpeedTransmit,&SpeedReceive,&Transmitted,&Received);
		
	//@TODO this should probably lock to prevent badness, but meh.
	currentUptime = [NSNumber numberWithInt:SecondsConnected];
	currentSpeedReceive = [NSNumber numberWithInt:SpeedReceive];
	currentSpeedTransmit = [NSNumber numberWithInt:SpeedTransmit];
	currentTransmitted = [NSNumber numberWithInt:Transmitted];
	currentReceived = [NSNumber numberWithInt:Received];
	
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


-(void)sendATCommand:(NSString*)command toDevice:(int)dev
{		
	char *buf_stream;
	buf_stream=(char *)malloc(BUFSIZE*sizeof(char));
	write(dev, [command cString], [command cStringLength]);
	read(dev,buf_stream,255);
	free(buf_stream);
}

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