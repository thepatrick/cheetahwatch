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
        NSColor *color;        
        NSString *iconName;
        NSImage *rawIcon;
        
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
        color = connected ? [NSColor colorWithCalibratedRed:0.05 green:0.37 blue:0.80 alpha:1] :
                            [NSColor colorWithCalibratedRed:0.40 green:0.40 blue:0.40 alpha:1];
        stringAttributes = [NSDictionary dictionaryWithObjectsAndKeys:menuFont, NSFontAttributeName, color, NSForegroundColorAttributeName, nil];
        // show mode and connection state or only mode, depending on connection state and preference setting
        if (connected && [[model preferences] showConnectionTime]) {
            modeRawString = [NSString stringWithFormat:@"%@ %@", [self modeIndicatorString:[model mode]], CWPrettyTime([model duration])];
        } else {
            modeRawString = [self modeIndicatorString:[model mode]];
        }
        modeString = [[NSAttributedString alloc] initWithString:modeRawString attributes:stringAttributes];
        // create status icon
        statusIcon = [[[NSImage alloc] initWithSize:NSMakeSize(28 + [modeString size].width, 22)] autorelease]; 
        // load raw icon with bars - append -off suffix if not connected
        rawIcon = [NSImage imageNamed:[iconName stringByAppendingString:connected ? @"" : @"-off"]];
        // draw raw icon into status icon
        [statusIcon lockFocus];
        [rawIcon drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
        // draw mode indicator
        [modeString drawAtPoint:NSMakePoint(28, 3)];
        [modeString release];
        // unlock drawing focus again
        [statusIcon unlockFocus];
        return statusIcon;
    } else {
        // no modem available
        return [NSImage imageNamed:@"no-modem-menu"];
    }
}

@end
