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

#import <Cocoa/Cocoa.h>
// import all submodel includes, so that other parts only need to import CWModel.h
#import "CWConnectionRecord.h"
#import "CWPreferences.h"

typedef enum {
    CWMode3GPreferred    = 1,
    CWModeGPRSPreferred  = 2,
    CWMode3GOnly         = 3,
    CWModeGPRSOnly       = 4,
	CWModeAuto			 = 5,
} CWModesPreference;

@interface CWModel : NSObject {

    // attributes - volatile
    BOOL modemAvailable;
    BOOL serviceAvailable;
    NSInteger connectionState;    // see http://developer.apple.com/mac/library/documentation/Networking/Conceptual/SystemConfigFrameworks/SC_ReachConnect/SC_ReachConnect.html
    NSTimeInterval duration;
    unsigned long long rxBytes;
    unsigned long long txBytes;
    unsigned long long rxTotalBytes;
    unsigned long long txTotalBytes;
    unsigned long long cumulatedRxTotalBytes;       // same as total bytes, but does not include currently open connection
    unsigned long long cumulatedTxTotalBytes;
    NSUInteger rxSpeed;
    NSUInteger txSpeed;
	NSUInteger signalLevel;
    NSUInteger signalStrength;
    NSUInteger mode;
    NSString *carrier;
    NSString *apn;
    NSString *imei;
    NSString *imsi;
    NSString *hwVersion;
    NSString *manufacturer;
    NSString *model;
    CWModesPreference modesPreference;
    BOOL pinLock;
	BOOL alwaysDisabled;
    BOOL ongoingPIN;

    CWConnectionRecord *currentRecord;

    // attributes - non-volatile
    NSMutableArray *connectionRecords;
    CWPreferences *preferences;
    NSCalendarDate *lastPurgeDate;
    
    // date when last traffic warning was shown
    NSDate *lastTrafficWarningDate;

    // delegate
    id delegate;

}

// return a model initialized from disk data
+ (id)persistentModel;

// write model to disk
- (void)synchronize;

// reset fields to sensible values after removal of modem
- (void)reset;

// calculate cumulated bytes
- (void)calculateCumulatedBytes;

// create new connection record
- (void)openNewConnection;

// close currently open record
- (void)closeConnection;

// cleanup old connection log data and recalculate totals
- (void)cleanupOldConnectionLogs;

// clear complete history
- (void)clearHistory;

// derived accessors - the ones returning self are only useful in combination with a value transformer
- (CWModel *)modelForIcon;
- (CWModel *)modelForConnectionState;
- (BOOL)connected;
- (BOOL)disconnected;
- (BOOL)isZTE;

// accessors
- (BOOL)modemAvailable;
- (void)setModemAvailable:(BOOL)newModemAvailable;
- (BOOL)serviceAvailable;
- (void)setServiceAvailable:(BOOL)newServiceAvailable;
- (NSInteger)connectionState;
- (void)setConnectionState:(NSInteger)newConnectionState;
- (NSTimeInterval)duration;
- (void)setDuration:(NSTimeInterval)newDuration;
- (unsigned long long)rxBytes;
- (void)setRxBytes:(unsigned long long)newRxBytes;
- (unsigned long long)txBytes;
- (void)setTxBytes:(unsigned long long)newTxBytes;
- (unsigned long long)rxTotalBytes;
- (void)setRxTotalBytes:(unsigned long long)newRxTotalBytes;
- (unsigned long long)txTotalBytes;
- (void)setTxTotalBytes:(unsigned long long)newTxTotalBytes;
- (unsigned long long)cumulatedRxTotalBytes;
- (void)setCumulatedRxTotalBytes:(unsigned long long)newCumulatedRxTotalBytes;
- (unsigned long long)cumulatedTxTotalBytes;
- (void)setCumulatedTxTotalBytes:(unsigned long long)newCumulatedTxTotalBytes;
- (NSUInteger)rxSpeed;
- (void)setRxSpeed:(NSUInteger)newRxSpeed;
- (NSUInteger)txSpeed;
- (void)setTxSpeed:(NSUInteger)newTxSpeed;
- (NSUInteger)signalLevel;
- (NSUInteger)signalStrength;
- (void)setSignalStrength:(NSUInteger)newSignalStrength;
- (NSUInteger)mode;
- (void)setMode:(NSUInteger)newMode;
- (BOOL)carrierAvailable;
- (NSString *)carrier;
- (void)setCarrier:(NSString *)newCarrier;
- (NSString *)apn;
- (void)setApn:(NSString *)newApn;
- (NSString *)imei;
- (void)setImei:(NSString *)newImei;
- (NSString *)imsi;
- (void)setImsi:(NSString *)newImsi;
- (NSString *)hwVersion;
- (void)setHwVersion:(NSString *)newHwVersion;
- (NSString *)manufacturer;
- (void)setManufacturer:(NSString *)newManufacturer;
- (NSString *)model;
- (void)setModel:(NSString *)newModel;
- (NSArray *)connectionRecords;
- (CWConnectionRecord *)currentRecord;
- (void)setCurrentRecord:(CWConnectionRecord *)newCurrentRecord;
- (CWPreferences *)preferences;
- (void)setPreferences:(CWPreferences *)newPreferences;

- (CWModesPreference)modesPreference;
- (void)setModesPreference:(CWModesPreference)newPreference;

- (BOOL)pinLock;
- (void)setPinLock:(BOOL)status;

//- (BOOL)alwaysDisabled;

- (BOOL)ongoingPIN;
- (void)setOngoingPIN:(BOOL)PINstatus;

- (void)checkTrafficLimit;

- (id)delegate;
- (void)setDelegate:(id)newDelegate;

@end

// delegate methods
@interface NSObject (CWModelDelegateMethods)
- (void)trafficLimitExceeded:(unsigned long long)limit traffic:(unsigned long long)traffic;
@end
