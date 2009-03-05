/* 
 * Copyright (c) 2007-2008 Patrick Quinn-Graham
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

#import "CWHistorySupport.h"

@implementation CWHistorySupport

-(void)dealloc
{
	if(activeConnection != nil) {
		[activeConnection release];
	}
	[managedObjectContext release];
	[coordinator release];
	[model release];
	[super dealloc];
}

-(void)setupCoreData
{
	doAutoResetOnDisconnect = NO;
	firstRunSinceStartup = YES;	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *thePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:[[NSBundle mainBundle]  objectForInfoDictionaryKey:@"CFBundleName"]];
	//	NSLog(@"Application support path is: %@", thePath);
	
	NSFileManager *man = [NSFileManager defaultManager];
	if(![man fileExistsAtPath:thePath]) {
		//NSLog(@"Path doesn't exist yet, creating it now...");
		if(![man createDirectoryAtPath:thePath attributes:nil]) {
			NSLog(@"AppSupport path still doesn't exist. Um. Oh oh?");
		}
	}
	
	NSURL *url = [NSURL fileURLWithPath:[thePath stringByAppendingPathComponent:@"ConnectionLog.db"]];
	coreDataError = nil;
	
	NSArray *bundles = [NSArray arrayWithObject:[NSBundle mainBundle]];
	
	model = [NSManagedObjectModel mergedModelFromBundles:bundles];
	coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
	[coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:url options:nil error:&coreDataError];
	
	if(coreDataError != nil) {
		NSLog(@"setupCoreData addPersistentStoreWithType:etc... errored: %@", coreDataError);
		coreDataError = nil;
	}
	
	managedObjectContext = [[NSManagedObjectContext alloc] init];
	[managedObjectContext setPersistentStoreCoordinator: coordinator];
	
	[self calculateTotalUsageForCaching];
	
	[self autoClearUsageHistory];
}

-(void)setMainController:(NSObject*)cont
{
	mainController = cont;
}

#pragma mark -
#pragma mark Timer action
-(void)iCanHasCheezburger:(NSTimer*)timer
{
	if(activeConnection == nil) {
		activeConnection = [self doWeHaveAnUnclosedConnection];
		if(activeConnection == nil) {
			[cheezburgerWatch invalidate];
			cheezburgerWatch = nil;
			return;
		}
	}
	NSDate *lastSeenAt = [activeConnection valueForKey:@"lastSeen"];
	if(fabs([lastSeenAt timeIntervalSinceDate:[NSDate new]]) > 4) { // we should get updates every two seconds.
		[self markConnectionAsClosed];
		if(cheezburgerWatch != nil) {
			[mainController performSelector:@selector(clearConnectionUI)];
			[cheezburgerWatch invalidate];
			cheezburgerWatch = nil;
		} else {
		}
	}
	
	[managedObjectContext save:&coreDataError];
	if(coreDataError != nil) {
		NSLog(@"iCanHasCheezburger: save error: %@", coreDataError);
	}
}

#pragma mark -
#pragma mark Modem actions

-(void)flowReportSeconds:(NSNumber*)connected withTransmitRate:(NSNumber*)transmit receiveRate:(NSNumber*)receive totalSent:(NSNumber*)sent andTotalReceived:(NSNumber*)received
{
	BOOL brandNew = NO;
	
	if(activeConnection == nil) {
		[self doWeHaveAnUnclosedConnection];
		if(activeConnection == nil) {
			[self newConnection:connected];
			brandNew = YES;
		}
	}
	
	if(!brandNew) {
		NSNumber *lastConnected = [activeConnection valueForKey:@"connectedSeconds"];
		if([connected compare:lastConnected] != NSOrderedDescending) {
			//NSLog(@"flowReportSeconds: Closing connection because we've guessed a new connection has occurred.");
			[self markConnectionAsClosed];
			activeConnection = [self newConnection:connected];	
		}
	}
	// why wrap this like this? It's easier! :)
	if(!brandNew && firstRunSinceStartup) {
		NSDate *lastStartTime = [activeConnection valueForKey:@"startTime"];
		float lastSecondsCounter = fabs([lastStartTime timeIntervalSinceDate:[NSDate new]]);
		if(lastSecondsCounter > ([connected floatValue] + 5)) {
			//NSLog(@"flowReportSeconds: Closing connection because we've guessed it's a new connection.");
			[self markConnectionAsClosed];
			activeConnection = [self newConnection:connected];	
		} else {
			//NSLog(@"flowReportSeconds: Resuming previous connection...");
		}
	}	
	firstRunSinceStartup = NO;

	[activeConnection setValue:connected forKey:@"connectedSeconds"];
	[activeConnection setValue:sent forKey:@"sentData"];
	[activeConnection setValue:received forKey:@"recvData"];
	[activeConnection setValue:[NSDate new] forKey:@"lastSeen"];
	
	[self calculateTotalUsage];
	
	if(cheezburgerWatch == nil) {
		cheezburgerWatch = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(iCanHasCheezburger:) userInfo:nil repeats:YES];
	}
}

-(NSManagedObject*)newConnection:(NSNumber*)connectedTime
{
	//NSLog(@"Creating new connection...");
	activeConnection = [NSEntityDescription insertNewObjectForEntityForName:@"Connection" inManagedObjectContext:managedObjectContext];
	[activeConnection setValue:connectedTime forKey:@"connectedSeconds"];
	[activeConnection setValue:[NSNumber numberWithBool:NO] forKey:@"hasTerminated"];
	[activeConnection setValue:[NSDate new] forKey:@"lastSeen"];
	[activeConnection setValue:[NSDate new] forKey:@"startTime"];	
	//NSLog(@"Done.");
	[self calculateTotalUsageForCaching];
	return activeConnection;
}

-(NSManagedObject*)doWeHaveAnUnclosedConnection
{
	NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"Connection" inManagedObjectContext:managedObjectContext];
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	[request setEntity:entityDescription];
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"hasTerminated = 0"];
	[request setPredicate:predicate];
	
	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"startTime" ascending:NO];
	[request setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
	[sortDescriptor release];
	
	NSArray *array = [managedObjectContext executeFetchRequest:request error:&coreDataError];
	if(coreDataError != nil || array == nil) {
		NSLog(@"doWeHaveAnUnclosedConnection executeFetchRequest errored: %@ (or array was nil)", coreDataError);
		coreDataError = nil;
	}
	if ([array count] == 0) {	
		return false;
	}
	
	activeConnection = [array objectAtIndex:0];
	return [array objectAtIndex:0];
}

-(void)markConnectionAsClosed
{
	if(activeConnection == nil)
		return; // no connection.. duh.
	
	//	NSLog(@"Marking connection as closed...");
	
	[activeConnection setValue:[NSNumber numberWithBool:YES] forKey:@"hasTerminated"];
	[managedObjectContext save:&coreDataError];
	if(coreDataError != nil) {
		NSLog(@"Error in closing last connection: %@", coreDataError);
		coreDataError = nil;
	}
	
	[activeConnection release];
	activeConnection = nil;
	//	NSLog(@"Done.");
	//	NSLog(@"mOC: %@", managedObjectContext);
	[managedObjectContext save:&coreDataError];
	if(coreDataError != nil) {
		NSLog(@"markConnectionAsClosed save error: %@", coreDataError);
	}
	
	[self calculateTotalUsageForCaching];
	
	if(doAutoResetOnDisconnect) {
		[self actuallyClearUsageHistory];
		doAutoResetOnDisconnect = NO;
	}
}

#pragma mark -
#pragma mark Totals

-(void)calculateTotalUsage
{
	SInt64 thisSent = 0, thisRecv = 0;
	
	if(activeConnection != nil) {
		thisRecv = [[activeConnection valueForKey:@"recvData"] longLongValue];
		thisSent = [[activeConnection valueForKey:@"sentData"] longLongValue];
	}
	
	cachedTotalSent = (cachedSent + thisSent);
	cachedTotalRecv = (cachedRecv + thisRecv);
	
	[self shouldWeAlertForRecieved:cachedRecv andSent:cachedSent];
	
	//NSLog(@"Totals: Sent %i, Received %i", cachedTotalSent, cachedTotalRecv);
}
-(void)calculateTotalUsageForCaching
{
	//NSLog(@"calculateTotalUsageForCaching: Begin...");
	NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"Connection" inManagedObjectContext:managedObjectContext];
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	[request setEntity:entityDescription];
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"hasTerminated = 1"];
	[request setPredicate:predicate];
	
	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"startTime" ascending:NO];
	[request setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
	[sortDescriptor release];
	
	NSArray *array = [managedObjectContext executeFetchRequest:request error:&coreDataError];
	if(coreDataError != nil || array == nil) {
		NSLog(@"calculateTotalUsage executeFetchRequest errored: %@ (or array was nil)", coreDataError);
		coreDataError = nil;
	}
	if ([array count] == 0) {	
		return;
	}
	
	cachedSent = 0;
	cachedRecv = 0;
	int results = [array count], i = 0;
	
	// [activeConnection valueForKey:@"startTime"]
	for(i = 0; i < results; i++) {
		cachedRecv = cachedRecv + [[[array objectAtIndex:i] valueForKey:@"recvData"] longLongValue];
		cachedSent = cachedSent + [[[array objectAtIndex:i] valueForKey:@"sentData"] longLongValue];
	}
	
	//NSLog(@"Caching totals: Sent %lld, Received %lld", cachedSent, cachedRecv);
}

-(BOOL)shouldWeAlertForRecieved:(SInt64)totalRecv andSent:(SInt64)totalSent
{
	NSUserDefaults *dd = [NSUserDefaults standardUserDefaults];
	// do nothing if disabled
	if (![dd boolForKey:@"CWActivateUsageWarning"]) {
		return NO;
	}
	
	if ([dd boolForKey:@"CWSuppressUsageWarning"] && 
			[[dd stringForKey:@"CWSuppressUsageWarningForAmount"] isEqualToString:[dd stringForKey:@"CWActivateUsageWarningAmount"]]) {
		//(@"User has acknowledged a warning, and we haven't cleared that yet.");
		return NO;
	}
	
	// next, when do we do it?
	NSInteger whenToAlert = [dd integerForKey:@"CWActivateUsageWarningWhen"];
	int alertAmount = [[dd stringForKey:@"CWActivateUsageWarningAmount"] intValue];
	NSInteger alertMultiplier = [dd integerForKey:@"CWActivateUsageWarningValueMultiplier"];
	
	NSString *multiplierLabel;
	if(alertMultiplier == 1) {
		alertMultiplier = (1024 * 1024 * 1024);
		multiplierLabel = @"GB";
	} else {
		alertMultiplier = (1024 * 1024);
		multiplierLabel = @"MB";
	}
	
	NSString *whenLabel;
	SInt64 amountToTestFor = 0;
	switch (whenToAlert) {
		case 0:
			amountToTestFor = (totalRecv + totalSent) / alertMultiplier;
			whenLabel = @"total usage";
			break;
		case 1:
			amountToTestFor = totalRecv / alertMultiplier;
			whenLabel = @"received data";
			break;
		case 2:
			amountToTestFor = totalSent / alertMultiplier;
			whenLabel = @"sent data";
			break;
		default:
			break;
	}
	
	//NSLog(@"amountToTestFor %ld alertAmount %d", amountToTestFor, alertAmount);
	
	if(amountToTestFor == 0 || alertAmount == 0) {
		return NO; // uh... just... don't.
	}
	
	if (amountToTestFor < alertAmount) {
		return NO; // not worth worrying about yet!
	}

	[dd setValue:[dd stringForKey:@"CWActivateUsageWarningAmount"] forKey:@"CWSuppressUsageWarningForAmount"];
	[dd setBool:YES forKey:@"CWSuppressUsageWarning"];

	NSAlert *alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:@"OK"];
	[alert setMessageText:[NSString stringWithFormat:@"Your %@ (%lld %@) has exceeded your warning limit (%d %@).", whenLabel, amountToTestFor, multiplierLabel, alertAmount, multiplierLabel]];
	[alert setInformativeText:@"You will not be warned again until you clear the usage history.\n\nTo change this warning go to Usage History and choose Preferences..."];
	[alert setAlertStyle:NSWarningAlertStyle];
	[alert beginSheetModalForWindow:nil modalDelegate:nil didEndSelector:nil contextInfo:nil];
	
	return YES;
}

-(BOOL)autoClearUsageHistory
{
	NSUserDefaults *dd = [NSUserDefaults standardUserDefaults];
	// do nothing if disabled
	if (![dd boolForKey:@"CWAutoReset"]) {
		return NO;
	}
		
	NSString *mode = [dd stringForKey:@"CWUsageFrequency"];
	
	NSDate *lastReset = [dd valueForKey:@"CWAutoResetLastReset"];
	float lastResetTimeSinceNow = [lastReset timeIntervalSinceNow];

	BOOL shouldReset = NO;
	
	if([mode isEqualToString:@"daily"]) {
		//NSLog(@"Mode is Daily");
			// every days?
		NSInteger everyDays = [[dd stringForKey:@"CWAutoResetDailyDays"] integerValue];
		
		if(lastResetTimeSinceNow < (float)-(everyDays * 60 * 60 * 24)) {
			shouldReset = YES;
		}
		
	} else if([mode isEqualToString:@"weekly"]) {
		NSLog(@"Mode is Weekly");
	
		NSInteger everyWeeks = [dd integerForKey:@"CWAutoResetWeeklyWeeks"];
		if(lastResetTimeSinceNow < (float)-(everyWeeks * 60 * 60 * 24 * 7)) {
			
			NSInteger dayOfWeek = [[[NSDate date] descriptionWithCalendarFormat:@"%w" timeZone:[NSTimeZone localTimeZone]
																		 locale:[NSLocale currentLocale]] integerValue];			
			NSLog(@"current day of week is %d", dayOfWeek);

			if([dd boolForKey:@"CWAutoResetWeeklySunday"] && dayOfWeek == 0)
					shouldReset = YES;
			if([dd boolForKey:@"CWAutoResetWeeklyMonday"] && dayOfWeek == 1) 
				shouldReset = YES;
			if([dd boolForKey:@"CWAutoResetWeeklyTuesday"] && dayOfWeek == 2) 
				shouldReset = YES;
			if([dd boolForKey:@"CWAutoResetWeeklyWednesday"] && dayOfWeek == 3) 
				shouldReset = YES;
			if([dd boolForKey:@"CWAutoResetWeeklyThursday"] && dayOfWeek == 4) 
				shouldReset = YES;
			if([dd boolForKey:@"CWAutoResetWeeklyFriday"] && dayOfWeek == 5) 
				shouldReset = YES;
			if([dd boolForKey:@"CWAutoResetWeeklySaturday"] && dayOfWeek == 6) 
				shouldReset = YES;
			
		}
		
	} else if([mode isEqualToString:@"monthly"]) {
		NSLog(@"Mode is Monthly");
	} else {
		NSLog(@"Mode is... er.... what?");	
	}
	
	if(!shouldReset) 
		return NO;
	
	NSLog(@"We think we should reset, though not if now isn't a good time.");
	
	if(activeConnection != nil) {
		doAutoResetOnDisconnect = YES;
		NSLog(@"We have an active connection so can't reset right this second, defer.");
		return YES;
	}
	
	// - calculate when we next need to do this
	// √ is it now? NO? return NO;
	// √ are we connected? YES? set an ivar so that when we disconnect we know to handle it then
	// √ no?
	[self actuallyClearUsageHistory];
	return YES;
}

-(void)actuallyClearUsageHistory
{
	
	// are we archiving? 
	//	yes?
	//		get the objects
	//		write out to ~/Library/Application Support/CheetahWatch/Archive_Y-m-d.log
	//			with format	"Connection Start", "Duration", "Sent", "Received"
	// -clearHistory
}

#pragma mark -
#pragma mark Control the history data
-(void)clearHistory
{

	NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"Connection" inManagedObjectContext:managedObjectContext];
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	[request setEntity:entityDescription];
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"hasTerminated = 1"];
	[request setPredicate:predicate];
	
	NSArray *array = [managedObjectContext executeFetchRequest:request error:&coreDataError];
	if(coreDataError != nil || array == nil) {
		NSLog(@"doWeHaveAnUnclosedConnection executeFetchRequest errored: %@ (or array was nil)", coreDataError);
		coreDataError = nil;
		return;
	}
	
	NSEnumerator *enumerator;
	NSManagedObject *obj;

	enumerator = [array objectEnumerator];
	while((obj = [enumerator nextObject]) != nil)
	{
		NSLog(@"should delete %@", obj);
		[managedObjectContext deleteObject:obj];
	}
	
	[managedObjectContext save:&coreDataError];
	if(coreDataError != nil) {
		NSLog(@"coreDataError on delete: %@", coreDataError);
	}
	
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"CWSuppressUsageWarning"];

	[self calculateTotalUsageForCaching];
	[self calculateTotalUsage];

}


#pragma mark -
#pragma mark Accessors

-(SInt64)cachedTotalSent
{
	return cachedTotalSent;
}
-(SInt64)cachedTotalRecv
{
	return cachedTotalRecv;
}


@end
