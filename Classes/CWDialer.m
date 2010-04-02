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

#import "CWDialer.h"
#import "CWModel.h"

// see http://developer.apple.com/mac/library/documentation/Networking/Reference/SCDynamicStoreKey/Reference/reference.html
// for the all the magic here...

// list of supported modem names (as returned by SystemConfiguration)
static NSArray *modems;

// forward declarations
@interface CWDialer (CWDialerPrivateMethods)
- (void)systemConfigurationChangeNotificationForKeys:(CFArrayRef)changedKeys;
- (void)connectionStatusChangeNotificationForConnection:(SCNetworkConnectionRef)notifiedConnection;
@end

// system configuration change callback function
static void CWSystemConfigurationNotificationCallback(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info)
{
    CWDialer *dialer = (CWDialer *)info;
#ifdef DEBUG
    NSLog(@"CWDialer: configuration changed %@", (id)changedKeys);
#endif
    // bridge back into dialer object
    [dialer systemConfigurationChangeNotificationForKeys:changedKeys];
}

// connection status change callback function
static void CWConnectionStatusChangeCallback(SCNetworkConnectionRef connection, SCNetworkConnectionStatus status, void *info)
{
    CWDialer *dialer = (CWDialer *)info;
#ifdef DEBUG
    NSLog(@"CWDialer: connection status changed to %ld", (long)status);
#endif
    // bridge back into dialer object
    [dialer connectionStatusChangeNotificationForConnection:connection];
}


@implementation CWDialer

// class initializer
+ (void)initialize
{
    if (modems == nil) {
        // load list of identifiers of supported modems
        NSString *path = [[NSBundle mainBundle] pathForResource:@"modems" ofType:@"plist"];
        modems = [[NSArray alloc] initWithContentsOfFile:path];
    }
}

// initializer
- (id)initWithModel:(CWModel *)aModel
{
    if (self = [super init]) {
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        SCDynamicStoreContext context;
        // remember modem
        model = [aModel retain];
        // set current status to disconnected - this will create a new connection record if we are already connected
        currentStatus = kSCNetworkConnectionPPPDisconnected;
        // create a dynamic store - no need to retain self
        context.version = 0;
        context.info = self;
        context.retain = NULL;
        context.release = NULL;
        context.copyDescription = NULL;
        if (store = SCDynamicStoreCreate(NULL, (CFStringRef)bundleIdentifier, CWSystemConfigurationNotificationCallback, &context)) {
            // create runloop source and add it to the current run loop to receive notifications
            if (runLoopSource = SCDynamicStoreCreateRunLoopSource(NULL, store, 0)) {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
                CFMutableArrayRef patterns = CFArrayCreateMutable(NULL, 1, &kCFTypeArrayCallBacks);
                if (patterns) {
                    CFStringRef key = SCDynamicStoreKeyCreateNetworkGlobalEntity(NULL, kSCDynamicStoreDomainSetup, kSCEntNetIPv4);
                    if (key) {
                        CFArrayAppendValue(patterns, key);
                        if (SCDynamicStoreSetNotificationKeys (store, patterns, NULL)) {
                            // call callback initially
                            CWSystemConfigurationNotificationCallback(store, patterns, self);
                            // all ok
                            CFRelease(key);
                            CFRelease(patterns);
                            return self;
                        }
                        CFRelease(key);
                    }
                    CFRelease(patterns);
                }
            }
        }
        // something went wrong with registering for notifications
        [self autorelease];
        self = nil;
    }
    return nil;    
}

- (void)dealloc
{
    if (runLoopSource) {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
        CFRelease(runLoopSource);
    }
    if (store) {
        CFRelease(store);
    }
    if (serviceId) {
        SCNetworkConnectionUnscheduleFromRunLoop(connection, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        CFRelease(connection);
        CFRelease(serviceId);
    }
    [model release];
    [super dealloc];
}

// subscribe to service for connection status change notifications
- (void)subscribeToService:(CFStringRef)newServiceId
{
#ifdef DEBUG
    NSLog(@"CWDialer: subscribing to service %@", newServiceId ? (id)newServiceId : @"none");
#endif
    // compare to currrent service Id    
    if (serviceId && (newServiceId == NULL || CFStringCompare(serviceId, newServiceId, 0) != kCFCompareEqualTo)) {
        // there is currently an old service registered and it is different from the new one, deregister
        SCNetworkConnectionUnscheduleFromRunLoop(connection, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        CFRelease(connection);
        CFRelease(serviceId);
        serviceId = NULL;
    }
    if (newServiceId) {
        // create a connection reference
        SCNetworkConnectionContext context;
        context.version = 0;
        context.info = self;
        context.retain = NULL;
        context.release = NULL;
        context.copyDescription = NULL;
        if (connection = SCNetworkConnectionCreateWithServiceID(NULL, newServiceId, CWConnectionStatusChangeCallback, &context)) {
            // add connection to current runloop
            if (SCNetworkConnectionScheduleWithRunLoop(connection, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode)) {
                // call callback initially to determine current connection status - pass 0 for status since we don't rely on it in the callback anyway
                CWConnectionStatusChangeCallback(connection, 0, self);
                // remember service Id
                serviceId = CFRetain(newServiceId);
            } else {
                // adding connection to runloop failed
                CFRelease(connection);
            }
        }
    }
}

// system configuration change notification
- (void)systemConfigurationChangeNotificationForKeys:(CFArrayRef)changedKeys
{
    // look through the current configuration and see if there is a service that supports dial-up
    // for one of the supported modems
    CFStringRef serviceDictKey = SCDynamicStoreKeyCreateNetworkGlobalEntity(NULL, kSCDynamicStoreDomainSetup, kSCEntNetIPv4);
    if (serviceDictKey) {
        CFPropertyListRef serviceDict = SCDynamicStoreCopyValue(store, serviceDictKey);
        if (serviceDict) {
            CFArrayRef services = CFDictionaryGetValue(serviceDict, kSCPropNetServiceOrder);
            if (services) {
                CFIndex n = CFArrayGetCount(services);
                NSInteger i;
                for (i = 0; i < n; i++) {
                    CFStringRef service = CFArrayGetValueAtIndex(services, i);
                    // get value for this service
                    CFStringRef serviceKey = SCDynamicStoreKeyCreateNetworkServiceEntity(NULL, kSCDynamicStoreDomainSetup, service, kSCEntNetInterface);
                    if (serviceKey) {
                        CFPropertyListRef serviceProperties = SCDynamicStoreCopyValue(store, serviceKey);
                        if (serviceProperties) {
                            // look for device name and compare with entries in supported modem list
                            CFStringRef deviceName = CFDictionaryGetValue(serviceProperties, kSCPropNetInterfaceDeviceName);
                            if ([modems containsObject:(NSString *)deviceName]) {
                                // have a possible service - register it and listen to status changes
                                [self subscribeToService:service];
                                [model setServiceAvailable:YES];
                                // no need to search any further
                                CFRelease(serviceProperties);
                                CFRelease(serviceKey);
                                CFRelease(services);
                                CFRelease(serviceDictKey);
                                return;
                            }
                            CFRelease(serviceProperties);
                        }
                        CFRelease(serviceKey);
                    }
                }
            }
            CFRelease(services);
        }
        CFRelease(serviceDictKey);
    }
    // could not find a dial-up service for a supported modem or something else went wrong, unsubscribe from current service
    [self subscribeToService:NULL];
    // set connection state to disconnected
    [model setConnectionState:kSCNetworkConnectionPPPDisconnected];
    [model setServiceAvailable:NO];
}

// connection status change notification
- (void)connectionStatusChangeNotificationForConnection:(SCNetworkConnectionRef)notifiedConnection
{
    // get detailed status
    CFDictionaryRef statusDictionary = SCNetworkConnectionCopyExtendedStatus(notifiedConnection);
    if (statusDictionary) {
        // extract PPP dictionary
        CFDictionaryRef pppDictionary = CFDictionaryGetValue(statusDictionary, kSCEntNetPPP);
        if (pppDictionary && CFGetTypeID(pppDictionary) == CFDictionaryGetTypeID()) {
            CFNumberRef statusNumber = CFDictionaryGetValue(pppDictionary, kSCPropNetPPPStatus);
            if (statusNumber && CFGetTypeID(statusNumber) == CFNumberGetTypeID()) {
                SInt32 minorStatus;
                if (CFNumberGetValue(statusNumber, kCFNumberSInt32Type, &minorStatus)) {
                    // have valid minor status
                    if (currentStatus == kSCNetworkConnectionPPPDisconnected && minorStatus != currentStatus) {
                        // connection status changed from disconnected to something different - create a new connection record
                        [model openNewConnection];
                    } else if (currentStatus != kSCNetworkConnectionPPPDisconnected && minorStatus == kSCNetworkConnectionPPPDisconnected) {
                        // disconnected
                        [model closeConnection];
                    }
                    currentStatus = minorStatus;
                    [model setConnectionState:(NSInteger)minorStatus];
                }
            }
        }
        // release the status dictionary
        CFRelease(statusDictionary);
    }
}

// connect network
- (BOOL)connect
{
#ifdef DEBUG
    NSLog(@"CWDialer: connecting...");
#endif
    return SCNetworkConnectionStart(connection, NULL, TRUE);
}

// disconnect network
- (BOOL)disconnect
{
#ifdef DEBUG
    NSLog(@"CWDialer: disconnecting...");
#endif
    return SCNetworkConnectionStop(connection, TRUE);
}

@end
