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

#import "CWModem.h"
#import "CWNetworks.h"
#import "CWUSBFinder.h"

// interval in which some commands are sent regularily
#define CWPeriodicCommandInterval       5.0

// maximum time we wait for a reply for a command
#define CWCommandTimeout                2.0

// forward declaration of private methods
@interface CWModem (CWModemPrivateMethods)
- (void)closeModem;
@end

@implementation CWModem

// initializer
- (id)initWithModel:(CWModel *)aModel;
{
    if (self = [super init]) {
        // remember model
        model = [aModel retain];
        // subscribe for background read notifications
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataAvailableNotification:)
                                              name:NSFileHandleDataAvailableNotification object:nil];
        // create modem input buffer
        modemData = [NSMutableData new];
        // create command queue
        modemCommands = [NSMutableArray new];
        // create a USB finder to get notified, when a supported device is attached
        usbFinder = [[CWUSBFinder alloc] initWithDelegate:self];
    }
    return self;
}

- (void)dealloc
{
    [periodicTimer invalidate];
    [commandTimeoutTimer invalidate];
    [usbFinder release];
    [modemHandle release];
    [modemData release];
    [modemCommands release];
    [model release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

// parse a +CSQ reply
- (void)processCSQ:(NSScanner *)scanner
{
    // example: +CSQ: 11,99
    NSInteger signalStrength;
    if ([scanner scanInteger:&signalStrength]) {
        // have a valid signal strength
        [model setSignalStrength:signalStrength];
    }
}

// parse a +CGDCONT reply
- (void)processCGDCONT:(NSScanner *)scanner
{
    // example: +CGDCONT: 1,"IP","gprs.swisscom.ch","",0,0
    // ignore APN number
    if ([scanner scanUpToString:@"," intoString:nil]) {
        // consume comma
        [scanner scanString:@"," intoString:nil];
        // ignore protocol indication
        if ([scanner scanUpToString:@"," intoString:nil]) {
            NSString *apn;
            [scanner scanString:@"," intoString:nil];
            // scan APN
            if ([scanner scanUpToString:@"," intoString:&apn]) {
                // remove optional quotes
                apn = [apn stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
                [model setApn:apn];
            }
            // ignore rest of line
        }
    }
}

// parse a +COPS reply
- (void)processCOPS:(NSScanner *)scanner
{
    // example: +COPS: 0,2,"22801",2
    NSInteger cmode;
    // ignore first argument
    [scanner scanUpToString:@"," intoString:nil];
    [scanner scanString:@"," intoString:nil];
    // read mode, and the following comma
    if ([scanner scanInteger:&cmode]) {
        if ([scanner scanString:@"," intoString:nil]) {
            NSString *mccmnc;
            if ([scanner scanUpToString:@"," intoString:&mccmnc]) {
                // remove optional quotes
                mccmnc = [mccmnc stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];            
                if (cmode == 2) {
                    // translate numeric MCC/MNC into operator name
                    NSString *carrier = [CWNetworks operatorForMCCMNC:mccmnc];
					
					if (
						(![model carrierAvailable]) && 
						([[model preferences] autoconnect]) && 
						(delegate) && 
						([delegate respondsToSelector:@selector(needsAutoconnect)])
						 ) {
							[delegate needsAutoconnect];
						}
					
                    [model setCarrier:carrier ? carrier : mccmnc];
                } else {
                    [model setCarrier:mccmnc];
                }
                // ignore rest of line
            }
        }
    }
}

// parse a ^HWVER reply
- (void)processHWVER:(NSScanner *)scanner
{
    // example: ^HWVER:"CD96TCPU"
    NSString *version;
    // consume optional quotes
    [scanner scanString:@"\"" intoString:nil];
    // scan version string
    if ([scanner scanUpToString:@"\"" intoString:&version]) {
        [model setHwVersion:version];
    }
}

// parse a ^DSFLOWPRT reply
- (void)processDSFLOWRPT:(NSScanner *)scanner
{
    // example: ^DSFLOWRPT:00000008,00000045,00000084,0000000000003839,000000000000475F,0003E800,102C0243
    // arguments are: seconds, upload speed, download speed, upload traffic, download traffic, unknown, unknown
    unsigned int seconds, rxSpeed, txSpeed;
    unsigned long long rxBytes, txBytes;
    if ([scanner scanHexInt:&seconds]        && [scanner scanString:@"," intoString:nil] &&
        [scanner scanHexInt:&txSpeed]        && [scanner scanString:@"," intoString:nil] &&
        [scanner scanHexInt:&rxSpeed]        && [scanner scanString:@"," intoString:nil] &&
        [scanner scanHexLongLong:&txBytes]   && [scanner scanString:@"," intoString:nil] &&
        [scanner scanHexLongLong:&rxBytes]   && [scanner scanString:@"," intoString:nil]) {
        // have a valid traffic log line
        [model setDuration:seconds];
        [model setRxBytes:rxBytes];
        [model setTxBytes:txBytes];
        [model setRxSpeed:rxSpeed];
        [model setTxSpeed:txSpeed];
        // check for traffic limit violation
        [model checkTrafficLimit];
    }
    // ignore rest of input
}

// parse a ^RSSI reply
- (void)processRSSI:(NSScanner *)scanner
{
    // example: ^RSSI:14
    NSInteger signalStrength;
    if ([scanner scanInteger:&signalStrength]) {
        // have a valid signal strength
        [model setSignalStrength:signalStrength];
    }
}

// parse a ^MODE reply
- (void)processMODE:(NSScanner *)scanner
{
    // example: ^MODE:5,7
    NSInteger mode;
    // the first integer is the general mode - we ignore it, as these modems are GSM/3G+ only (should be 3 or 5)
    if ([scanner scanInteger:&mode]) {
        // look for (optional) submode
        if ([scanner scanString:@"," intoString:nil]) {
            if ([scanner scanInteger:&mode]) {
                // have a valid submode
                [model setMode:mode];
                return;
            }
        }
    }
    // could not parse or didn't find anything feasible, set mode to unknown
    [model setMode:-1];
}

// parse ZPAS (ZTE mode)
- (void)processZPAS:(NSScanner *)scanner
{
    // example: +ZPAS: "GPRS","CS_PS"
    NSString *mode_str;
    if (![scanner scanString:@"\"" intoString:nil]) {
        [model setMode:-1];
        return;
    }
    if (![scanner scanUpToString:@"\"" intoString:&mode_str]) {
        [model setMode:-1];
        return;
    }
    
    if ([mode_str isEqual:@"No Service"]) {
        [model setMode:0];
    } else if ([mode_str isEqual:@"Limited Service"]) {
        [model setMode:-1];
    } else if ([mode_str isEqual:@"GSM"]) {
        [model setMode:1];
    } else if ([mode_str isEqual:@"GPRS"]) {
        [model setMode:2];
    } else if ([mode_str isEqual:@"EDGE"]) {
        [model setMode:3];
    } else if ([mode_str isEqual:@"UMTS"]) {
        [model setMode:4];
    } else if ([mode_str isEqual:@"HSDPA"]) {
        [model setMode:5];
    } else if ([mode_str isEqual:@"HSUPA"]) {
        [model setMode:6];
    } else {
        [model setMode:-1];
    }
    
#ifdef DEBUG
    NSLog(@"CWModem: ZPAS str: %@ ZPAS int: %d", mode_str, [model mode]);
#endif
}


// parse a CIMI reply (rest of line is IMSI)
- (void)processCIMI:(NSScanner *)scanner
{
    NSString *imsi;
    if ([scanner scanUpToString:@"\n" intoString:&imsi]) {
        [model setImsi:imsi];
    }
}

// parse a CGSN reply (rest of line is IMEI)
- (void)processCGSN:(NSScanner *)scanner
{
    NSString *imei;
    if ([scanner scanUpToString:@"\n" intoString:&imei]) {
        [model setImei:imei];
    }
}

// parse a CGMI reply (rest of line is manufacturer)
- (void)processCGMI:(NSScanner *)scanner
{
    NSString *manufacturer;
    if ([scanner scanUpToString:@"\n" intoString:&manufacturer]) {
        // at least make it look a bit pretty
        [model setManufacturer:[manufacturer capitalizedString]];
    }
}

// parse a CGMM reply (rest of line is model)
- (void)processCGMM:(NSScanner *)scanner
{
    NSString *modemModel;
    if ([scanner scanUpToString:@"\n" intoString:&modemModel]) {
        [model setModel:modemModel];
    }
}

// parse a CGMR reply (rest of line is hardware version)
- (void)processCGMR:(NSScanner *)scanner
{
	// example: ^HWVER:"CD96TCPU"
    NSString *version;
    // scan version string
    if ([scanner scanUpToString:@"\n" intoString:&version]) {
        [model setHwVersion:version];
    }
}

// parse a CPIN reply (rest of line is pin state)
- (void)processCPIN:(NSScanner *)scanner
{
    NSString *pinState;
    if (![scanner scanUpToString:@"\n" intoString:&pinState])
		return;
	
	if ([pinState isEqual:@"READY"]) {
		[model setOngoingPIN:NO];
		return;
    } else if (([pinState isEqual:@"SIM PIN"]) && (![model ongoingPIN])) {
		if (delegate && [delegate respondsToSelector:@selector(needsPin:)]) {
            [model setOngoingPIN:YES];
			[delegate needsPin:NSLocalizedString(@"L133", @"")];
		}
    } else if (([pinState isEqual:@"SIM PUK"]) && (![model ongoingPIN])) {
		if (delegate && [delegate respondsToSelector:@selector(needsPuk)]) {
            [model setOngoingPIN:YES];
            [delegate needsPuk:NSLocalizedString(@"L135", @"")];
		}
	} else {
		if ((delegate && [delegate respondsToSelector:@selector(needsPin:)]) && (![model ongoingPIN])) {
            [model setOngoingPIN:YES];
			[delegate needsPin:NSLocalizedString(@"L133", @"")];
		}
	}
}


// parse zte mode preference
- (void)processZSNT:(NSScanner *)scanner
{
    /*
     ZTE:
     'GPRSONLY' : 'AT+ZSNT=1,0,0',
     '3GONLY'   : 'AT+ZSNT=2,0,0',
     'GPRSPREF' : 'AT+ZSNT=0,0,1',
     '3GPREF'   : 'AT+ZSNT=0,0,2',
     */
    
    NSString *order;
    if (![scanner scanUpToString:@"\n" intoString:&order])
        return;
    
    if ([order isEqualTo:@"1,0,0"]) {
        [model setModesPreference:CWModeGPRSOnly];
    } else if ([order isEqualTo:@"2,0,0"]) {
        [model setModesPreference:CWMode3GOnly];
    } else if ([order isEqualTo:@"0,0,1"]) {
        [model setModesPreference:CWModeGPRSPreferred];
    } else if ([order isEqualTo:@"0,0,2"]) {
        [model setModesPreference:CWMode3GPreferred];
    }

}

// parse Huawei mode preference
- (void)processSYSCFG:(NSScanner *)scanner
{
    /*
     Huawei:
     'GPRSONLY' : 'AT^SYSCFG=13,1,3FFFFFFF,2,4',
     '3GONLY'   : 'AT^SYSCFG=14,2,3FFFFFFF,2,4',
     'GPRSPREF' : 'AT^SYSCFG=2,1,3FFFFFFF,2,4',
     '3GPREF'   : 'AT^SYSCFG=2,2,3FFFFFFF,2,4',
     */
    
    NSInteger firstNumber;
    NSInteger secondNumber;

    if (![scanner scanInteger:&firstNumber])
        return;
    if (![scanner scanString:@"," intoString:nil])
        return;
    if (![scanner scanInteger:&secondNumber])
        return;
    
    if (firstNumber==13 && secondNumber==1) {
        [model setModesPreference:CWModeGPRSOnly];
    } else if (firstNumber==14 && secondNumber==2) {
        [model setModesPreference:CWMode3GOnly];
    } else if (firstNumber==2 && secondNumber==1) {
        [model setModesPreference:CWModeGPRSPreferred];
    } else if (firstNumber==2 && secondNumber==2) {
        [model setModesPreference:CWMode3GPreferred];
    }
}

// facility lock
- (void)processCLCK:(NSScanner *)scanner
{
    NSString *issuedCommand = [modemCommands objectAtIndex:0];
    NSInteger mode; // 0 unlock, 1 lock
    if ([issuedCommand isEqual:@"AT+CLCK=\"SC\",2"]) {
        // process pin lock status AT+CLCK="SC",2
        // reply example: +CLCK: 0
        if ([scanner scanInteger:&mode]) {
            if (mode) {
                [model setPinLock:YES];
            } else {
                [model setPinLock:NO];
            }

        }
    }
}

// dequeue next command from list and send it to the modem, then start timeout timer
- (void)dequeueNextModemCommand
{
    // invalidate timeout timer
    [commandTimeoutTimer invalidate];
    commandTimeoutTimer = nil;
    // look for further commands
    if ([modemCommands count]) {
        NSString *command = [[modemCommands objectAtIndex:0] stringByAppendingString:@"\r"];
#ifdef DEBUG
    NSLog(@"CWModem: sending %@", command);
#endif
        // send command to modem
        [modemHandle writeData:[command dataUsingEncoding:NSASCIIStringEncoding]];
        // start timout timer
        commandTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:CWCommandTimeout target:self selector:@selector(commandTimeout:)
                                       userInfo:nil repeats:NO];
    }
}

// +CME ERROR
- (void)processCMEERROR:(NSScanner *)scanner
{
    NSString *error;
    if ([scanner scanUpToString:@"\n" intoString:&error]) {
        if ([error isEqual:@"SIM busy"]) {
#ifdef DEBUG
            NSLog(@"CWModem: SIM busy ERROR");
#endif
            // invalidate timeout timer, we need some time...
            [commandTimeoutTimer invalidate];
            commandTimeoutTimer = nil;
            
            // SIM busy, sleep 1 second, then reissue command
            sleep(1);
            [self dequeueNextModemCommand];
        } else if (([error isEqual:@"SIM PIN required"]) && (![model ongoingPIN])) {
            if (delegate && [delegate respondsToSelector:@selector(needsPin:)]) {
                [model setOngoingPIN:YES];
                [delegate needsPin:error];
            }
        } else if (([error isEqual:@"SIM PUK required"]) && (![model ongoingPIN])) {
            if (delegate && [delegate respondsToSelector:@selector(needsPuk)]) {
                [model setOngoingPIN:YES];
                [delegate needsPuk:NSLocalizedString(@"L135", @"")];
            }
        } else if ([error isEqual:@"incorrect password"]) { // Incorrect PIN code
            if (delegate && [delegate respondsToSelector:@selector(needsPin:)]) {
                [model setOngoingPIN:YES];
                [delegate needsPin:error];
            }
        }
    }
}

// command timed out
- (void)commandTimeout:(NSTimer *)aTimer
{
#ifdef DEBUG
    NSLog(@"CWModem: commandTimeout: %@", [modemCommands objectAtIndex:0]);
#endif
    commandTimeoutTimer = nil;
    // skip command that timed out and dequeue next one
    [modemCommands removeObjectAtIndex:0];
    [self dequeueNextModemCommand];
}

// process a reply from a command
- (void)processReply:(NSString *)command scanner:(NSScanner *)scanner
{
    // dispatch commands - a NSDictionary with method names could be more effective here
    if ([command isEqual:@"+CSQ"]) {
        [self processCSQ:scanner];
    } else if ([command isEqual:@"+CGDCONT"]) {
        [self processCGDCONT:scanner];
    } else if ([command isEqual:@"+COPS"]) {
        [self processCOPS:scanner];
    } else if ([command isEqual:@"^HWVER"]) {
        [self processHWVER:scanner];
    } else if ([command isEqual:@"^DSFLOWRPT"]) {
        [self processDSFLOWRPT:scanner];
    } else if ([command isEqual:@"^RSSI"]) {
        [self processRSSI:scanner];
    } else if ([command isEqual:@"^MODE"]) {
        [self processMODE:scanner];
    } else if ([command isEqual:@"+ZPAS"]) {
        [self processZPAS:scanner];
    } else if ([command isEqual:@"+CIMI"]) {
        [self processCIMI:scanner];
    } else if ([command isEqual:@"+CGSN"]) {
        [self processCGSN:scanner];
    } else if ([command isEqual:@"+CGMI"]) {
        [self processCGMI:scanner];
    } else if ([command isEqual:@"+CGMM"]) {
        [self processCGMM:scanner];
    } else if ([command isEqual:@"+CGMR"]) {
        [self processCGMR:scanner];
    } else if ([command isEqual:@"+CPIN"]) {
        [self processCPIN:scanner];
    } else if ([command isEqual:@"+ZSNT"]) {
        [self processZSNT:scanner];
    } else if ([command isEqual:@"^SYSCFG"]) {
        [self processSYSCFG:scanner];
    } else if ([command isEqual:@"+CLCK"]) {
        [self processCLCK:scanner];
    } else if ([command isEqual:@"+CME ERROR"]) {
        [self processCMEERROR:scanner];
    } else {
        // unhandled command
#ifdef DEBUG
        NSLog(@"CWModem: IGNORING %@", command);
#endif
    }
}

// process a line received from the modem and call the processing method for the command, if appropriate
- (void)processLine:(NSString *)line
{
    NSScanner *scanner = [NSScanner scannerWithString:line];
    NSString *command;
#ifdef DEBUG
    NSLog(@"CWModem: processing %@", line);
#endif
    // look for reply or OK or ERROR
    if ([line isEqual:@"OK"] || [line isEqual:@"ERROR"]) {
        // command terminated, send next in queue
        [modemCommands removeObjectAtIndex:0];
        [self dequeueNextModemCommand];
    } else if ([modemCommands count] && [line isEqual:[modemCommands objectAtIndex:0]]) {
        // this is just an echo from the last command sent to the modem, ignore it
    } else {
        [scanner scanUpToString:@":" intoString:&command];
        // check for colon - in this case the command is whatever comes before the colon
        if ([scanner scanString:@":" intoString:nil]) {
            // dispatch command
            [self processReply:command scanner:scanner];
        } else {
            // there is no colon, use the first command in the queue with AT removed (if available, otherwise ignore this line)
            if ([modemCommands count]) {
                command = [modemCommands objectAtIndex:0];
                if ([command hasPrefix:@"AT"]) {
                    command = [command substringFromIndex:2];
                }
                // dispatch command
                [self processReply:command scanner:[NSScanner scannerWithString:line]];
            }
        }
    }
}

// send command to modem
- (void)sendModemCommand:(NSString *)command
{
    // queue command and start dequeuing if queue was empty
#ifdef DEBUG
    NSLog(@"CWModem: queuing %@", command);
#endif
    [modemCommands addObject:command];
    if ([modemCommands count] == 1) {
        [self dequeueNextModemCommand];
    }
}

// background read notification
- (void)dataAvailableNotification:(NSNotification *)notification
{
    // earlier versions of MacOS X needed an autorelease pool here otherwise this would leak
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    NSData *newData = [modemHandle availableData];
    if ([newData length]) {
        NSUInteger position = 0;
        // append received data to residue
        [modemData appendData:newData];
        // find complete lines
        while (position < [modemData length]) {
            char ch = ((char *)[modemData bytes])[position++];
            if (ch == '\r') {
            NSRange range = NSMakeRange(0, position);
            NSString *line = [[[NSString alloc] initWithData:[modemData subdataWithRange:range] encoding:NSASCIIStringEncoding] autorelease];
                // trim newline characters at both ends
                line = [line stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
                if ([line length]) {
                    [self  performSelectorOnMainThread:@selector(processLine:) withObject:line waitUntilDone:NO];
                }                        
                // remove processed bytes and reset index to beginning of data
                [modemData replaceBytesInRange:range withBytes:NULL length:0];
                position = 0;
            }
        }
        // re-arm background reading
        [modemHandle waitForDataInBackgroundAndNotify];
    } else {
        // no more data to read, close modemHandle - this does not work in 10.6.0/1 due to a bug - the file handle will be released
        // through the notification from CWUSBFinder when the modem is removed
        [modemHandle release];
        modemHandle = nil;
    }
    // release autorelease pool and all objects registered with it
    [pool release];
}

- (void)setModesPref:(CWModesPreference)newPref
{
    if ([[model manufacturer] isEqualTo:@"Huawei"]) {
        if (newPref==CWModeGPRSOnly) {
            [self sendModemCommand:@"AT^SYSCFG=13,1,3FFFFFFF,2,4"];
        } else if (newPref==CWMode3GOnly) {
            [self sendModemCommand:@"AT^SYSCFG=14,2,3FFFFFFF,2,4"];
        } else if (newPref==CWModeGPRSPreferred) {
            [self sendModemCommand:@"AT^SYSCFG=2,1,3FFFFFFF,2,4"];
        } else if (newPref==CWMode3GPreferred) {
            [self sendModemCommand:@"AT^SYSCFG=2,2,3FFFFFFF,2,4"];
        }
    } else if ([[model manufacturer] isEqualTo:@"Zte Incorporated"]) {
        if (newPref==CWModeGPRSOnly) {
            [self sendModemCommand:@"AT+ZSNT=1,0,0"];
        } else if (newPref==CWMode3GOnly) {
            [self sendModemCommand:@"AT+ZSNT=2,0,0"];
        } else if (newPref==CWModeGPRSPreferred) {
            [self sendModemCommand:@"AT+ZSNT=0,0,1"];
        } else if (newPref==CWMode3GPreferred) {
            [self sendModemCommand:@"AT+ZSNT=0,0,2"];
        }
    }
}

// periodic timer to query some information
- (void)periodicCommandTimer:(NSTimer *)aTimer
{
    [self sendModemCommand:@"AT+CSQ"];             // query signal strength
    [self sendModemCommand:@"AT+CGDCONT?"];        // query APN
    [self sendModemCommand:@"AT+COPS?"];           // query carrier
    [self sendModemCommand:@"AT+CPAS"];            // query module status
	[self sendModemCommand:@"AT+CIMI"];            // query IMSI
	if ([[model manufacturer] isEqual:@"Zte Incorporated"]) {
		[self sendModemCommand:@"AT+ZPAS?"];       // query mode (ZTE)
        [self sendModemCommand:@"AT+ZSNT?"];       // query mode preferences (ZTE)
	} else if ([[model manufacturer] isEqual:@"Huawei"]) {
        [self sendModemCommand:@"AT^SYSCFG?"];  // query mode preferences (Huawei)
    }
    [self sendModemCommand:@"AT+CLCK=\"SC\",2"];   // query pin lock status
}

// open modem, allocata a file handle and send initial data
- (void)openModem:(NSString *)devicePath
{
    // check if there is already a handle open, close it in this case
    if (modemHandle) {
        [self closeModem];
    }
        // create a new NSFileHandle for the modem port and start reading in the background
		modemHandle = [NSFileHandle fileHandleForUpdatingAtPath: devicePath];
		if ( modemHandle == nil )
			NSLog(@"CWModem: Failed to open device %@", devicePath);
#ifdef DEBUG
			NSLog(@"CWModem: Succesfully accessed device %@", devicePath);
#endif
        [modemHandle waitForDataInBackgroundAndNotify];

        // Initialization - no ongoing pin at the beginning..
        [model setOngoingPIN:NO];
        
        // send commands to query some basic information
        [self sendModemCommand:@"AT+CGMI"];       // query manufacterer
        [self sendModemCommand:@"AT+CGMM"];       // query model
        [self sendModemCommand:@"AT+CGSN"];       // query IMEI
		if ([[model manufacturer] isEqual:@"Huawei"]) {
			[self sendModemCommand:@"AT^HWVER"];  // query hardware version (Huawei)
			[self sendModemCommand:@"AT+CFUN=1;+CFUN=5"];  // Enable device
		} else {
			[self sendModemCommand:@"AT+CGMR"];   // query hardware version (generic)
		}
		[self sendModemCommand:@"AT+CPIN?"];      // query pin status
        [self sendApn];                           // send APN to modem if set

        // setup a timer to periodically query some information
        periodicTimer = [NSTimer scheduledTimerWithTimeInterval:CWPeriodicCommandInterval target:self selector:@selector(periodicCommandTimer:)
                                 userInfo:nil repeats:YES];
        // call timer action immediately
        [self periodicCommandTimer:periodicTimer];
        // modem is available now
        [model setModemAvailable:YES];
}

// close modem handle and remove any residue data
- (void)closeModem
{
    [periodicTimer invalidate];
    periodicTimer = nil;
    [commandTimeoutTimer invalidate];
    commandTimeoutTimer = nil;
    [modemHandle release];
    modemHandle = nil;
    [modemData setLength:0];
    [modemCommands removeAllObjects];
    [model setModemAvailable:NO];
    // reset most information
    [model reset];
}

// set APN of modem to preferences setting
- (void)sendApn
{
    NSString *presetApn = [[model preferences] presetApn];
    // don't do anything if no APN is defined in preferences and don't send anything if no modem is present
    if ([presetApn length] && [model modemAvailable]) {
        // example command: AT+CGDCONT=1,"IP","gprs.swisscom.ch","",0,0
        [self sendModemCommand:[NSString stringWithFormat:@"AT+CGDCONT=1,\"IP\",\"%@\",\"\",0,0", presetApn]];
        // query new APN
        [self sendModemCommand:@"AT+CGDCONT?"];
    }
}

- (void)sendPin: (NSString*) pin
{
    // invalidate periodic timer
    [periodicTimer invalidate];
    periodicTimer = nil;

	[modemHandle writeData: [[NSString stringWithFormat:@"AT+CPIN=%@\r", pin] dataUsingEncoding:NSASCIIStringEncoding]];
	[modemHandle writeData: [[NSString stringWithString:@"AT+CPIN?\r"] dataUsingEncoding:NSASCIIStringEncoding]];
	
	// setup a timer to periodically query some information
	periodicTimer = [NSTimer scheduledTimerWithTimeInterval:CWPeriodicCommandInterval target:self selector:@selector(periodicCommandTimer:)
												   userInfo:nil repeats:YES];
	// call timer action immediately
	[self periodicCommandTimer:periodicTimer];	 
}

- (void)sendPuk:(NSString*)puk withNewPin:(NSString*)newPin
{
    // invalidate periodic timer
    [periodicTimer invalidate];
    periodicTimer = nil;
	
	[modemHandle writeData: [[NSString stringWithFormat:@"AT+CPIN=%@,%@\r", puk, newPin] dataUsingEncoding:NSASCIIStringEncoding]];
	[modemHandle writeData: [[NSString stringWithString:@"AT+CPIN?\r"] dataUsingEncoding:NSASCIIStringEncoding]];
	
	// setup a timer to periodically query some information
	periodicTimer = [NSTimer scheduledTimerWithTimeInterval:CWPeriodicCommandInterval target:self selector:@selector(periodicCommandTimer:)
												   userInfo:nil repeats:YES];
	// call timer action immediately
	[self periodicCommandTimer:periodicTimer];	
}

- (void)setPinLock:(BOOL)enabled pin:(NSString*)pin
{
#ifdef DEBUG
    NSLog(@"CWModem: setPinLock: %@ pin: %@", enabled?@"YES":@"NO", pin);
#endif
    if (enabled) {
        [self sendModemCommand:[NSString stringWithFormat:@"AT+CLCK=\"SC\",1,\"%@\"", pin]];
    } else {
        [self sendModemCommand:[NSString stringWithFormat:@"AT+CLCK=\"SC\",0,\"%@\"", pin]];
    }
}

// CWUSBFinder delegates
- (void)deviceAdded:(NSString *)devicePath
{
#ifdef DEBUG
    NSLog(@"CWModem: open device %@", devicePath);
#endif
    [self openModem:devicePath];
}

- (void)deviceRemoved:(NSString *)devicePath
{
#ifdef DEBUG
    NSLog(@"CWModem: close device %@", devicePath);
#endif
    // not using devicePath yet
    [self closeModem];
}

- (void)deviceSleep
{
    if ([[model manufacturer] isEqualTo:@"Huawei"]) {
		[self sendModemCommand:@"AT+CFUN=5"];
	}
}

- (void)deviceWakeUp
{
    if ([[model manufacturer] isEqualTo:@"Huawei"]) {
		[self sendModemCommand:@"AT+CFUN=1"];        

	}
}

// accessors
- (id)delegate
{
	return delegate;
}

- (void)setDelegate:(id)newDelegate
{
	delegate = newDelegate;
}

@end
