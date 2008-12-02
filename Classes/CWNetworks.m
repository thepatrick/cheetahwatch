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
