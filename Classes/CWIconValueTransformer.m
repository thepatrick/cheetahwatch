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

#import "CWIconValueTransformer.h"
#import "CWPrettyPrint.h"
#import "CWModel.h"


@implementation CWIconValueTransformer

+ (Class)transformedValueClass
{
    return [NSImage class];
}

+ (BOOL)allowsReverseTransformation
{
    return NO;
}

// convenience constructor
+ (id)valueTransformer
{
    return [[[self class] new] autorelease];
}

- (NSString *)modeIndicatorString:(NSInteger)mode
{
    // mode values taken from https://forge.betavine.net/pipermail/vodafonemobilec-devel/2007-November/000043.html
    switch (mode) {
        case 0:     // None
            return NSLocalizedString(@"L250", @"");
        case 1:     // GSM
            return NSLocalizedString(@"L251", @"");
        case 2:     // GPRS
            return NSLocalizedString(@"L252", @"");
        case 3:     // EDGE
            return NSLocalizedString(@"L253", @"");
        case 4:     // WCDMA/UMTS
            return NSLocalizedString(@"L254", @"");
        case 5:     // HSDPA
            return NSLocalizedString(@"L255", @"");
        case 6:     // HSUPA
            return NSLocalizedString(@"L256", @"");
        case 7:     // HSDPA + HSUPA
            return NSLocalizedString(@"L257", @"");
        default:    // Unknown
            return NSLocalizedString(@"L251", @"");
    }    
}

- (NSString *)modeIndicatorIconname:(NSInteger)mode
{
    // mode values taken from https://forge.betavine.net/pipermail/vodafonemobilec-devel/2007-November/000043.html
    switch (mode) {
        case 0:     // None
            return @"gsm";
        case 1:     // GSM
            return @"gsm";
        case 2:     // GPRS
            return @"gprs";
        case 3:     // EDGE
            return @"edge";
        case 4:     // WCDMA/UMTS
            return @"umts";
        case 5:     // HSDPA
            return @"umts";
        case 6:     // HSUPA
            return @"umts";
        case 7:     // HSDPA + HSUPA
            return @"umts";
        case 8:     // TD_SCDMA
            return @"umts";
        case 9:     //
            return @"umts";
        default:    // Unknown
            return @"gsm";
    }    
}

- (id)transformedValue:(id)value
{
    // translate signal level and connection state into an icon
    CWModel *model = (CWModel *)value;

    if ([model modemAvailable]) {

		NSShadow *textShadow = [[NSShadow alloc] init];
		[textShadow setShadowColor:[NSColor colorWithDeviceWhite:1 alpha:.8]];
		[textShadow setShadowBlurRadius:0];
		[textShadow setShadowOffset:NSMakeSize(0, -1)];
		
		NSAttributedString *modeString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@", CWPrettyTimeShort([model duration])]
																		 attributes: [NSDictionary dictionaryWithObjectsAndKeys:
																					  [NSFont boldSystemFontOfSize:12.0], NSFontAttributeName,
																					  textShadow, NSShadowAttributeName,
																					  [NSColor blackColor], NSForegroundColorAttributeName,
																					  nil]];
				
        // show mode and connection state or only mode, dependizg on connection state and preference setting & create status icon
		NSImage *statusIcon =[[[NSImage alloc] initWithSize:NSMakeSize([model connected] && [[model preferences] showConnectionTime] ? ( 43 + modeString.size.width ) : 41, 22)] autorelease];
		
		[statusIcon setFlipped: YES];
		
        // load raw icon with bars - append -off suffix if not connected
        NSImage *rawIcon = [NSImage imageNamed:[@"signal-" stringByAppendingFormat:@"%lu%@", (unsigned long)[model signalLevel], [model connected] ? @"" : @"-off" ]];

		[rawIcon setFlipped: NO];
        // draw raw icon into status icon
        [statusIcon lockFocus];
        [rawIcon drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
        // load second raw icon which shows connection state
        if ( [model connected] ) {
			NSImage *rawIcon2 = [NSImage imageNamed: [self modeIndicatorIconname:[model mode]]];
            [rawIcon2 drawAtPoint:NSMakePoint(22, 0) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];                
            if ([[model preferences] showConnectionTime]) {
				// create raw icon with connection time
				NSImage *rawIcon3 = [[[NSImage alloc] initWithSize:NSMakeSize([modeString size].width, 22)] autorelease];				
				[rawIcon3 lockFocus];
				[modeString drawAtPoint:NSZeroPoint];
				[modeString release];
				[rawIcon3 unlockFocus];
				[rawIcon3 drawAtPoint:NSMakePoint(41,3) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
			}
        } else if ((![model serviceAvailable]) || ([model ongoingPIN])) {
                NSImage *rawIcon2 = [NSImage imageNamed: @"lock-off"];            
                [rawIcon2 drawAtPoint:NSMakePoint(22, 0) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];                
        }
        // unlock drawing focus again
        [statusIcon unlockFocus];
		[statusIcon setFlipped: NO];		
        return statusIcon;
    } else {
        // no modem available
        return [NSImage imageNamed:@"airplane"];
    }
}

@end
