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

#import "CWPrettyPrint.h"

// bytes unit translation - localized
static NSString *ISByteUnits[] = { @"L200", @"L201", @"L202", @"L203", @"L204", @"L205", @"L206", nil };


// return a nicely formatted time duration
NSString *CWPrettyTime(NSUInteger time)
{
    if (time >= 86400) {
        // an hour or more
        return [NSString stringWithFormat:NSLocalizedString(@"L300", @""), time / 86400, (time % 86400) / 3600, (time % 3600) / 60, time % 60];
    }
    // less than an hour
    return [NSString stringWithFormat:NSLocalizedString(@"L301", @""), time / 3600, (time % 3600) / 60, time % 60];
}

// return a nicely formatted bytes amount
NSString *CWPrettyBytes(unsigned long long bytes)
{
    NSString **unit = &ISByteUnits[1];
    
    if (bytes < 1024) {
        // no fractions in simple byte values
        return [NSString stringWithFormat:@"%llu %@", bytes, NSLocalizedString(ISByteUnits[0], @"")];
    } else {
        // search appropriate unit size
        while (unit[1] && bytes >= 1024 * 1024) {
            unit++;
            bytes /= 1024;
        }
    }
    return [NSString stringWithFormat:@"%.1f %@", (double)bytes/1024.0, NSLocalizedString(*unit, @"")];
}

// return a nicely formatted bytes/s amount
NSString *CWPrettyBytesPerSecond(unsigned long long bytes)
{
    return [CWPrettyBytes(bytes) stringByAppendingString:NSLocalizedString(@"L210", @"")];
}