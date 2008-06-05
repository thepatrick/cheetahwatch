//
//  CWUSBFinder.h
//  CheetahWatch
//
//  Created by Patrick Quinn-Graham on 05/05/08.
//  Copyright 2008 Bunkerworld Publishing Ltd.. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/serial/IOSerialKeys.h>
#include <IOKit/IOBSD.h>
#include <IOKit/IOMessage.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>

#define kMyVendorID		4817
#define kE220ProductID	4099
#define kE169ProductID	4097
 
@class CWMain;

@interface CWUSBFinder : NSObject {
}

+(void)USBFinder:(CWMain*)mainController;
+(BOOL)addSearchForVendorID:(long)usbVendor andProductID:(long)usbProduct withMasterPort:(mach_port_t)masterPort andController:(CWMain*)mainController;
void CWUSBFinderDeviceAdded(void *refCon, io_iterator_t iterator);

@end

