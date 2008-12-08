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

#import "NBInvocationQueue.h"

#pragma mark -

@implementation NBThreadedInvocationGrabber : NSObject

- (NBInvocationQueue *)invocationQueue {
    return invocationQueue;
}

- (void)setInvocationQueue:(NBInvocationQueue *)value {
    if (invocationQueue != value) {
        [invocationQueue release];
        invocationQueue = [value retain];
    }
}

- (NSTimeInterval)delay {
    return delay;
}

- (void)setDelay:(NSTimeInterval)value {
    if (delay != value) delay = value;
}

- (id)target {
    return target;
}

- (void)setTarget:(id)value {
    if (target != value) {
        [target release];
        target = [value retain];
    }
}

- (NSInvocation *)invocation {
    return invocation;
}

- (void)setInvocation:(NSInvocation *)value {
    if (invocation != value) {
        [invocation release];
        invocation = [value retain];
    }
}



- (void) dealloc {
    [self setInvocationQueue:nil];
    [self setTarget:nil];
    [self setInvocation:nil];

    [super dealloc];
}

-(BOOL)respondsToSelector:(SEL)aSelector;
{
    BOOL result = [super respondsToSelector:aSelector];
    if (result == NO) 
        result = [[self target] respondsToSelector:aSelector];
    return result;
}

-(NSMethodSignature*)methodSignatureForSelector:(SEL)aSelector;
{
    NSMethodSignature *result = [super methodSignatureForSelector:aSelector];
    if (!result)
        result = [[self target] methodSignatureForSelector:aSelector];
    return result;
}

-(void)forwardInvocation:(NSInvocation *)anInvocation;
{
    [anInvocation setTarget:[self target]];
    [anInvocation retainArguments];
    [self setInvocation:anInvocation];
    
    // Now the invocation is complete so we can put it into the queue
    if (delay < 0) {
        [[self invocationQueue] enqueue:self];
    } else {
        // A delayed enqueu must be done on main thread, because the current thread might not have a runloop
        [self performSelectorOnMainThread:@selector(enqueueDelayed) withObject:nil waitUntilDone:NO];
    }
}

-(void)invoke;
{
    [[self invocation] invoke];
}

-(void)enqueueDelayed;    // must be called on main thread
{
    [[self invocationQueue] performSelector:@selector(enqueue:) withObject:self afterDelay:delay];
}

@end




#pragma mark -


@implementation NBInvocationQueue

-(id)init {
    if (self = [super init]) {
        elements = [[NSMutableArray alloc] init];
        lock = [[NSConditionLock alloc] initWithCondition:0];
        _numInvocations = 0;
    }
    return self;
}

-(void)dealloc {
    [elements release];
    [lock release];
    [super dealloc];
}


- (BOOL)shouldExitThread {
    return _shouldExitThread;
}

- (void)setShouldExitThread:(BOOL)value {
    if ( (value==YES) && (_numInvocations > 0) ) {
        NSLog(@"postponing setShouldExitThread. There are %d open invocations.", _numInvocations);
        [[self performThreadedWithTarget:self afterDelay:1.0] setShouldExitThread:YES];
        return;
    }

    if (_shouldExitThread != value) _shouldExitThread = value;
}

-(void)enqueue:(id)object {
    int count = [elements count];
    if (count == 0) [[NSNotificationCenter defaultCenter] postNotificationName:@"NBInvocationQueueDidBecomeFilled" object:self];
    
    [lock lock];
    [elements addObject:object];
    [lock unlockWithCondition:1];
}

-(id)dequeue {
    [lock lockWhenCondition:1];
    id element = [[[elements objectAtIndex:0] retain] autorelease];
    [elements removeObjectAtIndex:0];
    int count = [elements count];
    [lock unlockWithCondition:(count > 0)?1:0];
    
    if (0 == count) [[NSNotificationCenter defaultCenter] postNotificationName:@"NBInvocationQueueDidBecomeEmpty" object:self];
    
    return element;
}

-(id)tryDequeue {
    id element = NULL;
    if ([lock tryLock]) {
        if ([lock condition] == 1) {
            element = [[[elements objectAtIndex:0] retain] autorelease];
            [elements removeObjectAtIndex:0];
        }
        int count = [elements count];
        [lock unlockWithCondition:(count > 0)?1:0];

        if (0 == count) [[NSNotificationCenter defaultCenter] postNotificationName:@"NBInvocationQueueDidBecomeEmpty" object:self];
    }
    

    return element;
}


-(unsigned)count;
{
    unsigned count;
    [lock lock];
    count = [elements count];
    [lock unlockWithCondition:(count > 0)?1:0];
    return count;
}

-(void)runQueueThread;
{
    [self setShouldExitThread:NO];
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    _isRunning = YES;
    
    while (![self shouldExitThread]) {
        NSAutoreleasePool *tempPool = [[NSAutoreleasePool alloc] init]; {
            id obj = [self dequeue];
            _numInvocations--;
            if (![obj isKindOfClass:[NBThreadedInvocationGrabber class]]) {
                NSLog(@"ThreadSafeQueue: got wrong object: %@", obj);
            } else {
                NBThreadedInvocationGrabber *theGrabber = (NBThreadedInvocationGrabber*)obj;
                [theGrabber invoke];
            }
            
        }; [tempPool release];
    }
    
    [pool release];
    NSLog(@"NBInvocationQueue: Bye, bye");
    _isRunning = NO;
}

-(id)performThreadedWithTarget:(id)target;
{
    return [self performThreadedWithTarget:target afterDelay:-1.0];     // a negative afterDelay means putting it in the queue immediately 
}

-(id)performThreadedWithTarget:(id)target afterDelay:(NSTimeInterval)delay;
{
    id postGrabber = [[[NBThreadedInvocationGrabber alloc] init] autorelease];
    [postGrabber setTarget:target];
    [postGrabber setInvocationQueue:self];
    [postGrabber setDelay:delay];
    _numInvocations++;       // has to be done here and not in the enqeue method, because there might be some invocatons temporary on the main thread and not in the queue if they were schedule with a positive delay.
    return postGrabber;
}

-(BOOL)isActive;
{
    if (_numInvocations > 0) return YES;
    else return NO;
}

-(void)stopThreadWaitUntil:(BOOL)wait;      // stops the queue (if wait == YES it stops until all invocations have been processed)
    // must be called from main run loop
{
    [[self performThreadedWithTarget:self] setShouldExitThread:YES];
    double resolution = 1.0;
    BOOL isRunning;
    do {
        NSDate* next = [NSDate dateWithTimeIntervalSinceNow:resolution]; 
        isRunning = [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                             beforeDate:next];
    } while (isRunning && _isRunning && wait);
}

@end
