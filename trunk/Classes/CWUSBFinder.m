//
//  CWUSBFinder.m
//  CheetahWatch
//
//  Created by Patrick Quinn-Graham on 05/05/08.
//  Copyright 2008 Patrick Quinn-Graham. All rights reserved.
//

#import "CWUSBFinder.h"

static CWMain			*gCWMain;

@implementation CWUSBFinder

// This function sets up some stuff to detect a USB device being plugged. be prepared for C...
+(void)USBFinder:(CWMain*)mainController
{
    mach_port_t				masterPort;
    kern_return_t			kr;
	
	gCWMain = mainController;
	
    // first create a master_port for my task
    kr = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if (kr || !masterPort) {
        printf("ERR: Couldn't create a master IOKit Port(%08x)\n", kr);
        return;
    }
	
	if(![CWUSBFinder addSearchForVendorID:kMyVendorID andProductID:kE220ProductID withMasterPort:masterPort]) {
		mach_port_deallocate(mach_task_self(), masterPort);
		return;
	}
	if(![CWUSBFinder addSearchForVendorID:kMyVendorID andProductID:kE169ProductID withMasterPort:masterPort]) {
		mach_port_deallocate(mach_task_self(), masterPort);
		return;
	}

    // Now done with the master_port
    mach_port_deallocate(mach_task_self(), masterPort);
    masterPort = 0;

    // Start the run loop. Now we'll receive notifications.
    CFRunLoopRun();
}

+(BOOL)addSearchForVendorID:(long)usbVendor andProductID:(long)usbProduct withMasterPort:(mach_port_t)masterPort
{
    CFMutableDictionaryRef 	matchingDict;
    CFRunLoopSourceRef		runLoopSource;
    CFNumberRef				numberRef;
	
	matchingDict = IOServiceMatching(kIOUSBDeviceClassName);	// Interested in instances of class
                                                                // IOUSBDevice and its subclasses
    if (!matchingDict) {
        printf("Can't create a USB matching dictionary\n");
		return NO;
    }
	
	numberRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &usbVendor);
    CFDictionarySetValue(matchingDict, CFSTR(kUSBVendorID), numberRef);
    CFRelease(numberRef);
 	
    numberRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &usbProduct);
    CFDictionarySetValue(matchingDict, CFSTR(kUSBProductID), numberRef);
    CFRelease(numberRef);
	
    numberRef = 0;

    // Create a notification port and add its run loop event source to our run loop
    // This is how async notifications get set up.
    IONotificationPortRef notifyPort = IONotificationPortCreate(masterPort);
    runLoopSource = IONotificationPortGetRunLoopSource(notifyPort);
    
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFRunLoopAddSource(runLoop, runLoopSource, kCFRunLoopDefaultMode);

	io_iterator_t addedIter;

    // Now set up a notification to be called when a device is first matched by I/O Kit.
    // Note that this will not catch any devices that were already plugged in so we take
    // care of those later.
	// notifyPort, notificationType, matching, callback, refCon, notification
    IOServiceAddMatchingNotification(notifyPort, kIOFirstMatchNotification,
									 matchingDict, CWUSBFinderDeviceAdded, NULL, &addedIter);		
    
    // Iterate once to get already-present devices and arm the notification
    CWUSBFinderDeviceAdded(NULL, addedIter);
	return YES;
}

// this is a (mmm C) callback function when a USB device we care about is connected. 
void CWUSBFinderDeviceAdded(void *refCon, io_iterator_t iterator)
{
    io_service_t		usbDevice;
    while ( (usbDevice = IOIteratorNext(iterator)) )
    {		
		[gCWMain performSelectorOnMainThread:@selector(startMonitor:) withObject:nil waitUntilDone:YES];
        IOObjectRelease(usbDevice);
    }
}

@end
