//
//  CWNetworks.m
//  CheetahWatch
//
//  Created by Patrick Quinn-Graham on 05/05/08.
//  Copyright 2008 Patrick Quinn-Graham. All rights reserved.
//

#import "CWNetworks.h"

#import <SCCSVParser/SCCSVParser.h>


@implementation CWNetworks

+networks
{
	CWNetworks *n = [[CWNetworks alloc] init];
	[n setupTheStuff];
	return [n autorelease];
}

- (id)init
{
    self = [super init];
    if (nil != self)
	{
		_data = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
	[_data release];
	[super dealloc];
}

-(BOOL)setupTheStuff
{
	BOOL success = NO;
	
	NSString *opList = [[NSBundle mainBundle] pathForResource:@"OperatorList" ofType:@"lst"];
		
	NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:opList];
	[stream open];
	
	SCCSVParseMachine *machine = [[SCCSVParseMachine alloc] init];
	SCCSVStringDictionaryFactory *factory = [[SCCSVStringDictionaryFactory alloc] initWithDataSetArray:_data];
	[machine parseStream:stream withFieldFactory:factory];
	if([_data count] > 0) {
		success = YES;
	}
	
	[factory release];
	[stream close];
	
	[machine release];
	return success;
}

-(NSString*)displayNameForCountry:(NSInteger)country andNetwork:(NSInteger)network
{
	NSPredicate * m = [NSPredicate predicateWithFormat:@"Country = %@ and Network = %@", [NSString stringWithFormat:@"%d", country], [NSString stringWithFormat:@"%d", network]];
	
	NSArray *t = [_data filteredArrayUsingPredicate:m];
	
	if([t count] != 1) {
		return [NSString stringWithFormat:@"Unknown (%@ %@ %d)", [NSString stringWithFormat:@"%d", country], [NSString stringWithFormat:@"%d", network], [t count]];
	}
	
	return [[t objectAtIndex:0] objectForKey:@"Display"];
}

@end
