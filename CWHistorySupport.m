/* CheetahWatch, v1.2
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
-(void)setMainController:(NSObject*)cont
{
	mainController = cont;
}
//@TODO RENAME!
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
-(void)flowReportSeconds:(NSNumber*)connected withTransmitRate:(NSNumber*)transmit receiveRate:(NSNumber*)receive totalSent:(NSNumber*)sent andTotalReceived:(NSNumber*)received
{
	BOOL brandNew = NO;
	
	if(activeConnection == nil) {
		// we need a new connection
		[self doWeHaveAnUnclosedConnection];
		if(activeConnection == nil) {
			// but we didn't have one un-resumed
			//NSLog(@"No connection exists already, so we're going to make one.");
			[self newConnection:connected];
			brandNew = YES;
		} else {
			//NSLog(@"Retrieved an unterminated connection: %@", activeConnection);
		}
	}// else {
	//	NSLog(@"activeConnection wasn't nil, it was %i", [activeConnection objectID]);
	//}
	
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

-(void)setupCoreData
{
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
}

-(void)calculateTotalUsage
{
	int thisSent = 0, thisRecv = 0;
	
	if(activeConnection != nil) {
		thisRecv = [[activeConnection valueForKey:@"recvData"] intValue];
		thisSent = [[activeConnection valueForKey:@"sentData"] intValue];
	}
	
	cachedTotalSent = (cachedSent + thisSent);
	cachedTotalRecv = (cachedRecv + thisRecv);
	
	//NSLog(@"Totals: Sent %i, Received %i", cachedTotalSent, cachedTotalRecv);
}

-(int)cachedTotalSent
{
	return cachedTotalSent;
}
-(int)cachedTotalRecv
{
	return cachedTotalRecv;
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
		cachedRecv = cachedRecv + [[[array objectAtIndex:i] valueForKey:@"recvData"] intValue];
		cachedSent = cachedSent + [[[array objectAtIndex:i] valueForKey:@"sentData"] intValue];
	}
	
	//NSLog(@"Caching totals: Sent %i, Received %i", cachedSent, cachedRecv);
}

-(void)clearHistory
{

	NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"Connection" inManagedObjectContext:managedObjectContext];
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	[request setEntity:entityDescription];
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"hasTerminated = 1"];
	[request setPredicate:predicate];
	
//	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"startTime" ascending:NO];
//	[request setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
//	[sortDescriptor release];
	
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

	[self calculateTotalUsageForCaching];
	[self calculateTotalUsage];

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

	NSLog(@"Marking connection as closed...");
	
	[activeConnection setValue:[NSNumber numberWithBool:YES] forKey:@"hasTerminated"];
	[managedObjectContext save:&coreDataError];
	if(coreDataError != nil) {
		NSLog(@"Error in closing last connection: %@", coreDataError);
		coreDataError = nil;
	}
		
	[activeConnection release];
	activeConnection = nil;
	NSLog(@"Done.");
	NSLog(@"mOC: %@", managedObjectContext);
	[managedObjectContext save:&coreDataError];
	if(coreDataError != nil) {
		NSLog(@"markConnectionAsClosed save error: %@", coreDataError);
	}
	
	[self calculateTotalUsageForCaching];
}

@end
