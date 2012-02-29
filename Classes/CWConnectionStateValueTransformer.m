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

#import <SystemConfiguration/SystemConfiguration.h>
#import "CWConnectionStateValueTransformer.h"
#import "CWDurationValueTransformer.h"
#import "CWModel.h"


@implementation CWConnectionStateValueTransformer
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
    CWModel *model = (CWModel *)value;
    CWDurationValueTransformer *valueTransformer;

    switch ([model connectionState]) {
        // for possible values see table 4-3 in 
        // http://developer.apple.com/mac/library/documentation/Networking/Conceptual/SystemConfigFrameworks/SC_ReachConnect/SC_ReachConnect.html
        
        case kSCNetworkConnectionPPPDisconnected:
            return NSLocalizedString(@"L280", @"");
        case kSCNetworkConnectionPPPInitializing:
            return NSLocalizedString(@"L281", @"");
        case kSCNetworkConnectionPPPConnectingLink:
            return NSLocalizedString(@"L282", @"");
        case kSCNetworkConnectionPPPNegotiatingLink:
        case kSCNetworkConnectionPPPAuthenticating:
        case kSCNetworkConnectionPPPNegotiatingNetwork:
            return NSLocalizedString(@"L283", @"");
        case kSCNetworkConnectionPPPConnected:
            // include connect time in state
            valueTransformer = [CWDurationValueTransformer valueTransformer];
            return [NSString stringWithFormat:NSLocalizedString(@"L284", @""),
                             [valueTransformer transformedValue:[NSNumber numberWithDouble:[model duration]]]];
        case kSCNetworkConnectionPPPTerminating:
        case kSCNetworkConnectionPPPDisconnectingLink:
            return NSLocalizedString(@"L285", @"");
        case kSCNetworkConnectionPPPHoldingLinkOff:
        case kSCNetworkConnectionPPPSuspended:
        case kSCNetworkConnectionPPPWaitingForRedial:
        case kSCNetworkConnectionPPPDialOnTraffic:
        default:
            return NSLocalizedString(@"L299", @"");
    }
}

@end
