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

#import "CWConnectionRecord.h"


@implementation CWConnectionRecord

// coder protocol
- (id)initWithCoder:(NSCoder *)decoder
{
	if (self = [super init]) {
		startDate = [[decoder decodeObjectForKey:@"startDate"] retain];
		duration = [decoder decodeDoubleForKey:@"duration"];
		rxBytes = [decoder decodeInt64ForKey:@"rxBytes"];
		txBytes = [decoder decodeInt64ForKey:@"txBytes"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:startDate forKey:@"startDate"];
	[encoder encodeDouble:duration forKey:@"duration"];
	[encoder encodeInt64:rxBytes forKey:@"rxBytes"];
	[encoder encodeInt64:txBytes forKey:@"txBytes"];
}

// accessors
- (NSDate *)startDate
{
	return startDate;
}

- (void)setStartDate:(NSDate *)newStartDate
{
	[newStartDate retain];
	[startDate release];
	startDate = newStartDate;
}

- (NSTimeInterval)duration
{
	return duration;
}

- (void)setDuration:(NSTimeInterval)newDuration
{
	duration = newDuration;
}

- (unsigned long long)rxBytes
{
	return rxBytes;
}

- (void)setRxBytes:(unsigned long long)newRxBytes
{
	rxBytes = newRxBytes;
}

- (unsigned long long)txBytes
{
	return txBytes;
}

- (void)setTxBytes:(unsigned long long)newTxBytes
{
	txBytes = newTxBytes;
}

@end
