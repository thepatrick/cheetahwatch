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

#import "CWModel.h"
#import <SystemConfiguration/SystemConfiguration.h>

// key for model in user defaults
#define CWModelKey      @"CWModel"

@implementation CWModel

/*+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
    
}*/

+ (void)initialize
{
    static BOOL beenHere;
    if (!beenHere) {
        // make derived attributes binding capable
        [self setKeys:[NSArray arrayWithObjects:@"mode", @"signalStrength", @"connected", @"modemAvailable", @"serviceAvailable", @"carrierAvailable", @"duration", nil] triggerChangeNotificationsForDependentKey:@"modelForIcon"];
		
        [self setKeys:[NSArray arrayWithObjects:@"connectionState", @"duration", nil] triggerChangeNotificationsForDependentKey:@"modelForConnectionState"];
        [self setKeys:[NSArray arrayWithObject:@"connectionState"] triggerChangeNotificationsForDependentKey:@"connected"];
        [self setKeys:[NSArray arrayWithObject:@"connectionState"] triggerChangeNotificationsForDependentKey:@"disconnected"];
		
        beenHere = YES;
    }
}

// return a model initialized from disk data
+ (id)persistentModel
{
    NSData *modelData = [[NSUserDefaults standardUserDefaults] objectForKey:CWModelKey];
    CWModel *model = nil;
    if (modelData) {
        model = [NSKeyedUnarchiver unarchiveObjectWithData:modelData];
    }
    if (model == nil) {
        // could not load model, create new, empty one
        model = [[CWModel new] autorelease];
    } 
    return model;
}

// object initializer
- (id)init
{
    if (self = [super init]) {
        connectionRecords = [NSMutableArray new];
        preferences = [CWPreferences new];
        lastPurgeDate = [[NSCalendarDate date] retain];
    }
    return self;
}

- (void)dealloc
{
    [currentRecord release];
    [connectionRecords release];
    [preferences release];
    [lastPurgeDate release];
    [lastTrafficWarningDate release];
    [super dealloc];
}

// coder protocol
- (id)initWithCoder:(NSCoder *)decoder
{
	if (self = [super init]) {
		connectionRecords = [[decoder decodeObjectForKey:@"connectionRecords"] retain];
		preferences = [[decoder decodeObjectForKey:@"preferences"] retain];
		lastPurgeDate = [[decoder decodeObjectForKey:@"lastPurgeDate"] retain];
        // calculate cumulated bytes
        [self calculateCumulatedBytes];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:connectionRecords forKey:@"connectionRecords"];
	[encoder encodeObject:preferences forKey:@"preferences"];
	[encoder encodeObject:lastPurgeDate forKey:@"lastPurgeDate"];
}

// reset fields to sensible values, e.g. after removal of modem
- (void)reset
{
    // use setters for binding notifications
    [self setSignalStrength:0];
    [self setMode:-1];
    [self setCarrier:nil];
    [self setApn:nil];
    [self setImei:nil];
    [self setImsi:nil];
    [self setHwVersion:nil];
    [self setManufacturer:nil];
    [self setModel:nil];
    [self setModesPreference:0];
    [self setPinLock:NO];
    [self setOngoingPIN:NO];
}

// write model to disk
- (void)synchronize
{
    // write model data back to user defaults
    NSData *modelData = [NSKeyedArchiver archivedDataWithRootObject:self];
    [[NSUserDefaults standardUserDefaults] setObject:modelData forKey:CWModelKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// calculate cumulated bytes
- (void)calculateCumulatedBytes
{
    NSEnumerator *enumerator = [connectionRecords objectEnumerator];
    CWConnectionRecord *record;
    unsigned long long rx = 0, tx = 0;
    while (record = [enumerator nextObject]) {
        if (record != currentRecord) {
            rx += [record rxBytes];
            tx += [record txBytes];
        }
    }
    [self setCumulatedRxTotalBytes:rx];
    [self setCumulatedTxTotalBytes:tx];
    [self setRxTotalBytes:rx + rxBytes];
    [self setTxTotalBytes:tx + txBytes];
}

// create new connection record
- (void)openNewConnection
{
    CWConnectionRecord *record = [[CWConnectionRecord new] autorelease];
    // set start time
    [record setStartDate:[NSDate date]];
    // add to history and remember as current record (do this KVO aware)
    [[self mutableArrayValueForKey:@"connectionRecords"] addObject:record];
    [self setCurrentRecord:record];
    // reset fields
    [self setDuration:0];
    [self setRxBytes:0];
    [self setTxBytes:0];
    [self setRxSpeed:0];
    [self setTxSpeed:0];
}

// close current record
- (void)closeConnection
{
    [self setCurrentRecord:nil];
    // reset persistent totals to current totals - don't use setters here
    [self setCumulatedRxTotalBytes:rxTotalBytes];
    [self setCumulatedTxTotalBytes:txTotalBytes];
    [self setRxBytes:0];
    [self setTxBytes:0];
    // synchronize model to disk - may not be needed if application terminates correctly, but the current HUAWEI drivers panic often
    [self synchronize];
}

// cleanup old connection log data and recalculate totals
- (void)cleanupOldConnectionLogs
{
    if ([preferences resetStatistics]) {
        NSDate *now = [NSDate date];
        NSCalendarDate *nextPurgeDate;
        if (lastPurgeDate == nil) {
            lastPurgeDate = [[NSCalendarDate date] retain];
        }
        // round date up to next midnight
        nextPurgeDate = [lastPurgeDate dateByAddingYears:0 months:0 days:0 hours:23 minutes:59 seconds:59];
        nextPurgeDate = [NSCalendarDate dateWithYear:[nextPurgeDate yearOfCommonEra] month:[nextPurgeDate monthOfYear] day:[nextPurgeDate dayOfMonth]
                                        hour:0 minute:0 second:0 timeZone:[nextPurgeDate timeZone]];
#ifdef DEBUG
        NSLog(@"CWModel: cleanup connection logs, lastPurgeDate = %@, nextPurgeDate = %@", lastPurgeDate, nextPurgeDate);
#endif
        // release old last purge date - autorelease because loops below might fall through
        [lastPurgeDate autorelease];
        // look at reset mode
#ifdef DEBUG
        NSLog(@"CWModel: cleanup mode = %d", [preferences resetMode]);
#endif
        if ([preferences resetMode] == CWResetStatisticsModeDay) {
            // clean up after x days
            while ([now compare:nextPurgeDate] == NSOrderedDescending) {
#ifdef DEBUG
                NSLog(@"CWModel: day step, lastPurgeDate = %@, nextPurgeDate = %@", lastPurgeDate, nextPurgeDate);
#endif
                lastPurgeDate = nextPurgeDate;
                nextPurgeDate = [nextPurgeDate dateByAddingYears:0 months:0 days:[preferences dayPeriod] hours:0 minutes:0 seconds:0];
            }
        } else if ([preferences resetMode] == CWResetStatisticsModeWeek) {
            // clean up after x weeks on a specific week day - a bit tricky
            while ([now compare:nextPurgeDate] == NSOrderedDescending) {
                NSInteger days = 7 * [preferences weekPeriod] - (7 - [preferences dayOfWeek] + [nextPurgeDate dayOfWeek]) % 7;
#ifdef DEBUG
                NSLog(@"CWModel: week step, lastPurgeDate = %@, nextPurgeDate = %@", lastPurgeDate, nextPurgeDate);
#endif
                lastPurgeDate = nextPurgeDate;
                nextPurgeDate = [nextPurgeDate dateByAddingYears:0 months:0 days:days hours:0 minutes:0 seconds:0];
            }
        } else if ([preferences resetMode] == CWResetStatisticsModeMonth) {
            // clean up after x months on a specific day of the month
            // this is a bit trickier since not all months have the same number of days and february additionally depends on leap years
            while ([now compare:nextPurgeDate] == NSOrderedDescending) {
                NSInteger month;
#ifdef DEBUG
                NSLog(@"CWModel: month step, lastPurgeDate = %@, nextPurgeDate = %@", lastPurgeDate, nextPurgeDate);
#endif
                lastPurgeDate = nextPurgeDate;
                // increase date by x months, then set the day - treat end of month specially
                nextPurgeDate = [nextPurgeDate dateByAddingYears:0 months:[preferences monthPeriod] days:0 hours:0 minutes:0 seconds:0];
                // set day, but make sure to handle overflow into next month correctly for shorter months
                month = [nextPurgeDate monthOfYear];
                nextPurgeDate = [NSCalendarDate dateWithYear:[nextPurgeDate yearOfCommonEra] month:[nextPurgeDate monthOfYear] day:[preferences dayOfMonth]
                                                hour:0 minute:0 second:0 timeZone:[nextPurgeDate timeZone]];
                while (month != [nextPurgeDate monthOfYear]) {
                    nextPurgeDate = [nextPurgeDate dateByAddingYears:0 months:0 days:-1 hours:0 minutes:0 seconds:0];
                }
            }
        }
        // remove old entries
#ifdef DEBUG
        NSLog(@"CWModel: removing entries older than %@", lastPurgeDate);
#endif
        while ([connectionRecords count] && [[[connectionRecords objectAtIndex:0] startDate] compare:lastPurgeDate] == NSOrderedAscending) {
            // remove this entry, it's too old
#ifdef DEBUG
        NSLog(@"CWModel: removing entry with start date %@", [[connectionRecords objectAtIndex:0] startDate]);
#endif
            [[self mutableArrayValueForKey:@"connectionRecords"] removeObjectAtIndex:0]; 
        }
        
        // recalculate persistent totals
        [self calculateCumulatedBytes];
        // retain last purge date
        [lastPurgeDate retain];
    }
}

// clear complete history
- (void)clearHistory
{
    if (currentRecord) {
        // there is currently an open connection, don't remove this one
        [currentRecord retain];
        [[self mutableArrayValueForKey:@"connectionRecords"] removeAllObjects];
        [[self mutableArrayValueForKey:@"connectionRecords"] addObject:currentRecord];
        [currentRecord release];
    } else {
        [[self mutableArrayValueForKey:@"connectionRecords"] removeAllObjects];        
    }
    // update grand total
    [self calculateCumulatedBytes];
}

// derived accessors - the ones returning self are only useful in combination with a value transformer
- (CWModel *)modelForIcon
{
    // return model, notify whenever icon should change
    return self;
}

- (CWModel *)modelForConnectionState
{
    // return model, notify whenever connection state or duration changes
    return self;
}

- (BOOL)connected
{
	return connectionState == kSCNetworkConnectionPPPConnected;
}

- (BOOL)disconnected
{
	return connectionState == kSCNetworkConnectionPPPDisconnected;
}

- (BOOL)isZTE
{
	if (([[self manufacturer] isEqual:@"Zte Incorporated"]) || ([[self manufacturer] isEqualTo:@"Zte Corporation"]))
		return YES;
	return NO;
}

// accessors
- (BOOL)modemAvailable
{
	return modemAvailable;
}

- (void)setModemAvailable:(BOOL)newModemAvailable
{
	modemAvailable = newModemAvailable;
}

- (BOOL)serviceAvailable
{
	return serviceAvailable;
}

- (void)setServiceAvailable:(BOOL)newServiceAvailable
{
	serviceAvailable = newServiceAvailable;
}

- (NSInteger)connectionState
{
	return connectionState;
}

- (void)setConnectionState:(NSInteger)newConnectionState
{
	connectionState = newConnectionState;
}

- (NSTimeInterval)duration
{
	return duration;
}

- (void)setDuration:(NSTimeInterval)newDuration
{
	duration = newDuration;
    // forward this to currentRecord
    [currentRecord setDuration:duration];
}

- (unsigned long long)rxBytes
{
	return rxBytes;
}

- (void)setRxBytes:(unsigned long long)newRxBytes
{
	rxBytes = newRxBytes;
    // forward this to currentRecord and recalculate total
    [currentRecord setRxBytes:rxBytes];
    [self setRxTotalBytes:cumulatedRxTotalBytes + rxBytes];
}

- (unsigned long long)txBytes
{
	return txBytes;
}

- (void)setTxBytes:(unsigned long long)newTxBytes
{
	txBytes = newTxBytes;
    // forward this to currentRecord and recalculate total
    [currentRecord setTxBytes:txBytes];
    [self setTxTotalBytes:cumulatedTxTotalBytes + txBytes];
}

- (unsigned long long)rxTotalBytes
{
	return rxTotalBytes;
}

- (void)setRxTotalBytes:(unsigned long long)newRxTotalBytes
{
	rxTotalBytes = newRxTotalBytes;
}

- (unsigned long long)txTotalBytes
{
	return txTotalBytes;
}

- (void)setTxTotalBytes:(unsigned long long)newTxTotalBytes
{
	txTotalBytes = newTxTotalBytes;
}

- (unsigned long long)cumulatedRxTotalBytes
{
	return cumulatedRxTotalBytes;
}

- (void)setCumulatedRxTotalBytes:(unsigned long long)newCumulatedRxTotalBytes
{
	cumulatedRxTotalBytes = newCumulatedRxTotalBytes;
}

- (unsigned long long)cumulatedTxTotalBytes
{
	return cumulatedTxTotalBytes;
}

- (void)setCumulatedTxTotalBytes:(unsigned long long)newCumulatedTxTotalBytes
{
	cumulatedTxTotalBytes = newCumulatedTxTotalBytes;
}

- (NSUInteger)rxSpeed
{
	return rxSpeed;
}

- (void)setRxSpeed:(NSUInteger)newRxSpeed
{
	rxSpeed = newRxSpeed;
}

- (NSUInteger)txSpeed
{
	return txSpeed;
}

- (void)setTxSpeed:(NSUInteger)newTxSpeed
{
	txSpeed = newTxSpeed;
}

- (NSUInteger)signalLevel
{
	return signalLevel;
}

- (NSUInteger)signalStrength
{
	return signalStrength;
}

- (void)setSignalStrength:(NSUInteger)newSignalStrength
{	// Signal level according to this: http://www.siptune.net/tiki-index.php?page=Signaalinaytot
	signalStrength = ( newSignalStrength == 99 ) ? signalStrength : newSignalStrength;
	signalLevel =
	( signalStrength < 3 ) ? 0 :
	( signalStrength < 8 ) ? 1 :
	( signalStrength < 14 ) ? 2 :
	( signalStrength < 20 ) ? 3 :
	( signalStrength < 26 ) ? 4 : 5;
}

- (NSUInteger)mode
{
	return mode;
}

- (void)setMode:(NSUInteger)newMode
{
	mode = newMode;
}

- (NSString *)carrier
{
	return carrier;
}

- (void)setCarrier:(NSString *)newCarrier
{
	[newCarrier retain];
	[carrier release];
	carrier = newCarrier;
}

- (BOOL)carrierAvailable
{
	if ( [self carrier] == NULL )
		return FALSE;
	return TRUE;
}

- (NSString *)apn
{
	return apn;
}

- (void)setApn:(NSString *)newApn
{
	[newApn retain];
	[apn release];
	apn = newApn;
}

- (NSString *)imei
{
	return imei;
}

- (void)setImei:(NSString *)newImei
{
	[newImei retain];
	[imei release];
	imei = newImei;
}

- (NSString *)imsi
{
	return imsi;
}

- (void)setImsi:(NSString *)newImsi
{
	[newImsi retain];
	[imsi release];
	imsi = newImsi;
}

- (NSString *)hwVersion
{
	return hwVersion;
}

- (void)setHwVersion:(NSString *)newHwVersion
{
	[newHwVersion retain];
	[hwVersion release];
	hwVersion = newHwVersion;
}

- (NSString *)manufacturer
{
	return manufacturer;
}

- (void)setManufacturer:(NSString *)newManufacturer
{
	[newManufacturer retain];
	[manufacturer release];
	manufacturer = newManufacturer;
}

- (NSString *)model
{
	return model;
}

- (void)setModel:(NSString *)newModel
{
	[newModel retain];
	[model release];
	model = newModel;
}

- (NSArray *)connectionRecords
{
	return connectionRecords;
}

- (CWConnectionRecord *)currentRecord
{
	return currentRecord;
}

- (void)setCurrentRecord:(CWConnectionRecord *)newCurrentRecord
{
	[newCurrentRecord retain];
	[currentRecord release];
	currentRecord = newCurrentRecord;
}

- (CWPreferences *)preferences
{
	return preferences;
}

- (void)setPreferences:(CWPreferences *)newPreferences
{
	[newPreferences retain];
	[preferences release];
	preferences = newPreferences;
}

- (CWModesPreference)modesPreference
{
    return modesPreference;
}

- (void)setModesPreference:(CWModesPreference)newPreference
{
    modesPreference = newPreference;
}

- (BOOL)pinLock
{return pinLock;}
- (void)setPinLock:(BOOL)status
{
#ifdef DEBUG
    NSLog(@"CWModel: setting pin lock: %@", status?@"YES":@"NO");
#endif
    pinLock = status;
}

- (BOOL)ongoingPIN
{return ongoingPIN;}
- (void)setOngoingPIN:(BOOL)PINstatus
{
    ongoingPIN = PINstatus;
}


- (void)checkTrafficLimit
{
    if ([preferences trafficWarning]) {
#ifdef DEBUG
        NSLog(@"CWModel: checking traffic limit");
#endif
        unsigned long long traffic;
        unsigned long long limit;
        switch ([preferences trafficWarningMode]) {
            case CWTrafficWarningModeReceived:
                traffic = [self rxTotalBytes];
                break;
            case CWTrafficWarningModeSent:
                traffic = [self txTotalBytes];
                break;
            case CWTrafficWarningModeAll:
                traffic = [self rxTotalBytes] + [self txTotalBytes];
                break;
        }
        switch ([preferences trafficWarningUnit]) {
            case CWTrafficWarningUnitMB:
                limit = [preferences trafficWarningAmount] * 1048576;
                break;
            case CWTrafficWarningUnitGB:
                limit = [preferences trafficWarningAmount] * 1073741824;
                break;
        }
        // warn (if already warned before, wait until traffic exceeds limit by another 20%)
        if (traffic >= limit) {
#ifdef DEBUG
            NSLog(@"CWModel: traffic limit exceeded (limit = %lld, actual = %lld)", limit, traffic);
#endif
            // check for last warning date - consider to enter exactly once when set to 'Never'
            if ((lastTrafficWarningDate == nil ||
                [preferences trafficWarningInterval] != 0) && [lastTrafficWarningDate timeIntervalSinceNow] < -[preferences trafficWarningInterval]) {
#ifdef DEBUG
                NSLog(@"CWModel: issuing traffic warning to user");
#endif
                // remember date of last warning
                [lastTrafficWarningDate release];
                lastTrafficWarningDate = [[NSDate date] retain];
                // call delegate to warn (application controller)
                if (delegate && [delegate respondsToSelector:@selector(trafficLimitExceeded:traffic:)]) {
                    [delegate trafficLimitExceeded:limit traffic:traffic];
                }
            }
        }            
    }
}

- (id)delegate
{
	return delegate;
}

- (void)setDelegate:(id)newDelegate
{
	delegate = newDelegate;
}

/*- (void) setValue: (id)anObject forUndefinedKey: (NSString*)aKey
{
    return;
}*/

@end
