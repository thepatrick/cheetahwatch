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

#import "CWUSBFinder.h"
#include <IOKit/IOKitLib.h>
#include <IOKit/serial/IOSerialKeys.h>
#include <IOKit/IOBSD.h>
#include <IOKit/IOMessage.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>


// it's all here: http://developer.apple.com/mac/library/documentation/DeviceDrivers/Conceptual/AccessingHardware/AH_IOKitLib_API/AH_IOKitLib_API.html

// dictionary keys in devices.plist
#define CWDevicePath                @"devicePath"
#define CWMatchingDictionary        @"matchingDictionary"

// private forward declarations
@interface CWUSBFinder (CWUSBFinderPrivateMethods)
- (void)addSupportedDevices;
- (void)deviceAddedNotification:(io_service_t)device;
- (void)deviceRemovedNotification:(io_service_t)device;
@end


// callback functions for notifications - they call the delegate
static void CWUSBFinderDeviceAdded(void *refCon, io_iterator_t iterator)
{
    CWUSBFinder *usbFinder = (CWUSBFinder *)refCon;
    io_service_t device;
    while ((device = IOIteratorNext(iterator))) {
        [usbFinder deviceAddedNotification:device];
        IOObjectRelease(device);
    }
}

static void CWUSBFinderDeviceRemoved(void *refCon, io_iterator_t iterator)
{
    CWUSBFinder *usbFinder = (CWUSBFinder *)refCon;
    io_service_t device;
    while ((device = IOIteratorNext(iterator))) {
        [usbFinder deviceRemovedNotification:device];
        IOObjectRelease(device);
    }
}
    

@implementation CWUSBFinder

- (id)initWithDelegate:(id)aDelegate
{
    if (self = [super init]) {
        CFRunLoopSourceRef runLoopSource;
        // load list of supported devices
        NSString *path = [[NSBundle mainBundle] pathForResource:@"devices" ofType:@"plist"];
        devices = [[NSArray alloc] initWithContentsOfFile:path];
        // don't retain the delegate
        delegate = aDelegate;
        // allocate a notification port (can be used for all devices later), using default master port
        notificationPort = IONotificationPortCreate(kIOMasterPortDefault);
        // get runloop source for this port
        runLoopSource = IONotificationPortGetRunLoopSource(notificationPort);
        // add source to current runloop
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
        // add devices to monitor
        [self addSupportedDevices];
    }
    return self;
}

- (void)dealloc
{
    // destroy notification port, deregistering all device notifications
    IONotificationPortDestroy(notificationPort);
    // release device matching dictionaries
    [devices release];
    [super dealloc];
}

// add device to monitor
- (void)addDevice:(NSDictionary *)matchingDictionary
{
	io_iterator_t addedIter;
#ifdef DEBUG
    NSLog(@"CWUSBFinder: adding Device with dictionary %@", matchingDictionary);
#endif
    // register for device attachment - retain the matchingDictionary, since it is consumed by the call!
    IOServiceAddMatchingNotification(notificationPort, kIOFirstMatchNotification, (CFDictionaryRef)[matchingDictionary retain],
                                     CWUSBFinderDeviceAdded, self, &addedIter);
    // arm notification
    CWUSBFinderDeviceAdded(self, addedIter);
    // register for device detachment - ignore return value since we cannot do much about a failure anyway
    IOServiceAddMatchingNotification(notificationPort, kIOTerminatedNotification, (CFDictionaryRef)[matchingDictionary retain],
                                     CWUSBFinderDeviceRemoved, self, &addedIter);
    // arm notification
    CWUSBFinderDeviceRemoved(self, addedIter);
}

// convenience method - add a list of devices
- (void)addSupportedDevices
{
    NSEnumerator *enumerator = [devices objectEnumerator];
    NSDictionary *device;
    while (device = [enumerator nextObject]) {
        [self addDevice:[device objectForKey:CWMatchingDictionary]];
    }
}

// look through the devices list, return the device path if it found
- (NSString *)pathForDevice:(NSDictionary *)deviceProperties
{
    NSEnumerator *enumerator = [devices objectEnumerator];
    NSDictionary *device;
    NSString *path = nil;
    while (device = [enumerator nextObject]) {
        // compare USB properties - this can be extended to support non-USB devices like PCCards etc.
        NSDictionary *matchingDictionary = [device objectForKey:CWMatchingDictionary];
        if ([[matchingDictionary objectForKey:(NSString *)CFSTR(kIOProviderClassKey)] isEqual:(NSString *)CFSTR(kIOUSBDeviceClassName)]) {
            // compare USB manufacturer and product id
            if ([[matchingDictionary objectForKey:(NSString *)CFSTR(kUSBVendorID)]isEqual:[deviceProperties objectForKey:(NSString *)CFSTR(kUSBVendorID)]] &&
                [[matchingDictionary objectForKey:(NSString *)CFSTR(kUSBProductID)]isEqual:[deviceProperties objectForKey:(NSString *)CFSTR(kUSBProductID)]]) {
                // found a matching device
                path = [device objectForKey:CWDevicePath];
                break;
            }
        }
    }
#ifdef DEBUG
    NSLog(@"CWUSBFinder: returning path %@ for device dictionary %@", path ? path : @"none", deviceProperties);
#endif
    return path;
}

// device add/remove notifications, called by the callback functions
- (void)deviceAddedNotification:(io_service_t)device
{
#ifdef DEBUG
    NSLog(@"CWUSBFinder: device added notification received");
#endif
    if ([delegate respondsToSelector:@selector(deviceAdded:)]) {
        // get device properties
        CFMutableDictionaryRef cfDeviceProperties = NULL;
        if (IORegistryEntryCreateCFProperties(device, &cfDeviceProperties, kCFAllocatorDefault, kNilOptions) == KERN_SUCCESS) {
            NSString *devicePath = [self pathForDevice:(NSDictionary *)cfDeviceProperties];
            if (devicePath) {
                // found a matching device
                [delegate deviceAdded:devicePath];
            }
            CFRelease(cfDeviceProperties);
        }
    }
}

- (void)deviceRemovedNotification:(io_service_t)device
{
#ifdef DEBUG
    NSLog(@"CWUSBFinder: device removed notification received");
#endif
    if ([delegate respondsToSelector:@selector(deviceRemoved:)]) {
        // get device properties
        CFMutableDictionaryRef cfDeviceProperties = NULL;
        if (IORegistryEntryCreateCFProperties(device, &cfDeviceProperties, kCFAllocatorDefault, kNilOptions) == KERN_SUCCESS) {
            NSString *devicePath = [self pathForDevice:(NSDictionary *)cfDeviceProperties];
            if (devicePath) {
                // found a matching device
                [delegate deviceRemoved:devicePath];
            }
            CFRelease(cfDeviceProperties);
        }
    }
}

@end
