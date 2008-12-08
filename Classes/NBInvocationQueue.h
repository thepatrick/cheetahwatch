/* 
 * Copyright (c) 2006 Tim Scheffler
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

@interface NBInvocationQueue : NSObject {
    NSMutableArray* elements;
    NSConditionLock* lock; // 0 = no elements, 1 = elements

    BOOL _shouldExitThread;
    BOOL _isRunning;
    unsigned _numInvocations;
}

-(void)enqueue:(id)object;
-(id)dequeue; // Blocks until there is an object to return
-(id)tryDequeue; // Returns NULL if the queue is empty
-(unsigned)count;

-(BOOL)shouldExitThread;
-(void)setShouldExitThread:(BOOL)value;
-(void)runQueueThread;
-(void)stopThreadWaitUntil:(BOOL)wait;


-(id)performThreadedWithTarget:(id)target;
-(id)performThreadedWithTarget:(id)target afterDelay:(NSTimeInterval)delay;
-(BOOL)isActive;

@end


@interface NBThreadedInvocationGrabber : NSObject
{
    NBInvocationQueue *invocationQueue;
    NSTimeInterval delay;
    id target;
	NSInvocation *invocation;
}
- (NBInvocationQueue *)invocationQueue;
- (void)setInvocationQueue:(NBInvocationQueue *)value;

- (NSTimeInterval)delay;
- (void)setDelay:(NSTimeInterval)value;

- (id)target;
- (void)setTarget:(id)value;

- (NSInvocation *)invocation;
- (void)setInvocation:(NSInvocation *)value;

-(void)enqueueDelayed;  // must be called on main thread

@end