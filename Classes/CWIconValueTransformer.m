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
            return NSLocalizedString(@"L240", @"");
        case 1:     // GSM
            return NSLocalizedString(@"L241", @"");
        case 2:     // GPRS
            return NSLocalizedString(@"L242", @"");
        case 3:     // EDGE
            return NSLocalizedString(@"L243", @"");
        case 4:     // WCDMA/UMTS
            return NSLocalizedString(@"L244", @"");
        case 5:     // HSDPA
        case 6:     // HSUPA
        case 7:     // HSDPA + HSUPA
            return NSLocalizedString(@"L245", @"");
        default:    // Unknown
            return NSLocalizedString(@"L249", @"");
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
        NSUInteger signalStrength = [model signalStrength];
        NSFont *menuFont = [NSFont fontWithName:@"Monaco" size:10.0];
        NSImage *statusIcon;
        BOOL connected = [model connected];
        NSDictionary *stringAttributes;
        NSAttributedString *modeString;
        NSString *modeRawString;
        NSString *iconName;
        NSImage *rawIcon, *rawIcon2;
        
        // determine icon for given signal strength
        if (signalStrength == 0) {
            iconName = @"signal-0";
        } else if (signalStrength < 10) {
            iconName = @"signal-1";
        } else if (signalStrength < 15) {
            iconName = @"signal-2";
        } else if (signalStrength < 20) {
            iconName = @"signal-3";
        } else {
            iconName = @"signal-4";
        }
        // construct mode and duration string
        stringAttributes = [NSDictionary dictionaryWithObjectsAndKeys:menuFont, NSFontAttributeName, [NSColor colorWithCalibratedRed:0.32 green:0.32 blue:0.32 alpha:1], NSForegroundColorAttributeName, nil];
        // show mode and connection state or only mode, depending on connection state and preference setting & create status icon
        if (connected && [[model preferences] showConnectionTime]) {
            modeRawString = [NSString stringWithFormat:@"%@", CWPrettyTime([model duration])];
            modeString = [[NSAttributedString alloc] initWithString:modeRawString attributes:stringAttributes];
            statusIcon = [[[NSImage alloc] initWithSize:NSMakeSize(41 + [modeString size].width, 22)] autorelease]; 
        } else {
            statusIcon = [[[NSImage alloc] initWithSize:NSMakeSize(41, 22)] autorelease]; 
        }
        // load raw icon with bars - append -off suffix if not connected
        rawIcon = [NSImage imageNamed:[iconName stringByAppendingString:connected ? @"" : @"-off"]];
        // draw raw icon into status icon
        [statusIcon lockFocus];
        [rawIcon drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
        // load second raw icon which shows connection state
        if ( connected ) {
            rawIcon2 = [NSImage imageNamed: [self modeIndicatorIconname:[model mode]]];
            [rawIcon2 drawAtPoint:NSMakePoint(22, 0) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];                
            // show connection time
            [modeString drawAtPoint:NSMakePoint(41, 3)];
            [modeString release];
        } else {
            if ([model carrier] == NULL) {
                rawIcon2 = [NSImage imageNamed: @"lock-off"];            
                [rawIcon2 drawAtPoint:NSMakePoint(22, 0) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];                
            }
        }
        // unlock drawing focus again
        [statusIcon unlockFocus];
        return statusIcon;
    } else {
        // no modem available
        return [NSImage imageNamed:@"airplane"];
    }
}

@end
