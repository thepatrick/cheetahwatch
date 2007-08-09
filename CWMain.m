#import "CWMain.h"

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

@implementation CWMain

-(void)awakeFromNib
{
	[signal setEnabled:NO]; //disables user interaction, enabled by default
	[theWindow setTopBorder:24.0];
	[theWindow setBottomBorder:205];
	[theWindow setBorderStartColor:[NSColor colorWithDeviceWhite:0.9 alpha:0.5]];
	[theWindow setBorderEndColor:[NSColor colorWithDeviceWhite:0.5 alpha:0.5]];
	[theWindow setBorderEdgeColor:[NSColor colorWithDeviceWhite:0.8 alpha:0.5]];
	[theWindow setBgColor:[NSColor colorWithDeviceWhite:0.95 alpha:1.0]];
	[theWindow setBackgroundColor:[theWindow styledBackground]];
	[self clearAllUI];
	[self startMonitor:nil];
}

// start a new thread running myrunner below
-(void)startMonitor:(id)sender
{
	[NSThread detachNewThreadSelector:@selector(MyRunner:) toTarget:[CWMain class] withObject:self];
}

// clear UI, generally keep things from looking too silly.
-(void)clearAllUI
{
	[signal setIntValue:0];
	[mode setStringValue:@""];	
	[speedReceive setStringValue:@""];
	[speedTransmit setStringValue:@""];
	[transferReceive setStringValue:@""];
	[transferTransmit setStringValue:@""];
	[uptime setStringValue:@""];
}

// called by the monitor thread to say "no modem!"
- (void)noModem:(id)sender
{
	[self clearAllUI];
	NSImage *imageFromBundle = [NSImage imageNamed:@"no-modem.png"];
	[status setImage: imageFromBundle];
	[self performSelector:@selector(startMonitor:) withObject:self afterDelay:5];
}

// called by the monitor thread to say "hoorah! w00t!"
-(void)haveModem
{
	NSImage *imageFromBundle = [NSImage imageNamed:@"have-modem.png"];
	[status setImage: imageFromBundle];
	[self clearAllUI];
}

// Update the signal strength display
-(void)signalStrength:(char*)buff
{
	int z_signal;
	z_signal=atoi(buff);
	if(z_signal > 20) printf("Claimed that signal was %i\n", z_signal);
	if(z_signal > 50) z_signal = 0;
	[signal setIntValue:z_signal];
}

// Update the "mode" display
- (void)modeChange:(char*)buff
{
	[mode setStringValue:@""];
	switch (buff[0]) {
		case '0':
			[mode setStringValue:@"None"];
			break;
		case '1':
			[mode setStringValue:@"GPRS"];
			break;
		case '2':
			[mode setStringValue:@"GPRS"];
			break;
		case '3':
			[mode setStringValue:@"EDGE"];
			break;
		case '4':
			[mode setStringValue:@"WCDMA"];
			break;
		case '5':
			[mode setStringValue:@"HSDPA"];
			break;
		default:
			[mode setStringValue:@"Unknown"];
	}
}

// Update the connection time, speed, and data moved display
- (void)flowReport:(char*)buff
{
	unsigned int SecondsConnected, SpeedTransmit, SpeedReceive, Transmitted, Received;
	sscanf(buff,"%X,%X,%X,%X,%X", &SecondsConnected,&SpeedTransmit,&SpeedReceive,&Transmitted,&Received);
	float MinutesConnected = SecondsConnected / 60;	
	[uptime setStringValue:[NSString stringWithFormat:@"%.0f:%.2d", MinutesConnected, (SecondsConnected - ((int)MinutesConnected * 60 ))]];
	[speedReceive setStringValue:[NSString stringWithFormat:@"%ikBps", (SpeedReceive/1024)]];
	[speedTransmit setStringValue:[NSString stringWithFormat:@"%ikBps", (SpeedTransmit/1024)]];
	[transferReceive setStringValue:[NSString stringWithFormat:@"%.1fMB", (double )Received/(1024*1024)]];
	[transferTransmit setStringValue:[NSString stringWithFormat:@"%.1fMB", (double )Transmitted/(1024*1024)]];
}

// this is the quasi-runloop (yeah, whatever) that follows the stream from the modem
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
@end