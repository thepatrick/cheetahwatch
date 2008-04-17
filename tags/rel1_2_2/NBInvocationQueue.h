//
//  NBInvocationQueue.h
//  NBInvocationQueue
//
//  Created by Tim Scheffler on 19/12/2006.
//  Copyright 2006 Tim Scheffler. All rights reserved.
//

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