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

#import "CWModeValueTransformer.h"


@implementation CWModeValueTransformer

+ (Class)transformedValueClass
{
    return [NSString class];
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

- (id)transformedValue:(id)value
{
    // mode values taken from https://forge.betavine.net/pipermail/vodafonemobilec-devel/2007-November/000043.html
    switch ([value integerValue]) {
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
        case 6:     // HSUPA
        case 7:     // HSDPA + HSUPA
            return NSLocalizedString(@"L255", @"");
        default:    // Unknown
            return NSLocalizedString(@"L259", @"");
    }
}

@end
