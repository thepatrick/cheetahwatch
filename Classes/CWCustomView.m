//
//  CWCustomView.m
//  CheetahWatch
//
//  Created by Rauta Oskari on 18.2.2012.
//  Copyright (c) 2012 RoadRunner.cx. All rights reserved.
//

#import "CWCustomView.h"
#import "CWApplication.h"

@implementation CWCustomView

- (void)setImage:(NSImage *)newImage
{
	[newImage retain];
    [customImage release];
    customImage = newImage;	
    [self setNeedsDisplay:YES];
}

- (void)setToolTip:(NSString *)string
{
	
}
/*
- (void)mouseDown:(NSEvent *)event
{
    [controller toggleAttachedWindowAtPoint];
//    clicked = !clicked;
    [self setNeedsDisplay:YES];
}
*/

- (void)drawRect:(NSRect)rect 
{

	NSRect newRect = NSMakeRect(0,0, customImage.size.width < 22 ? 22 : customImage.size.width, 22);
	[self setFrame:newRect];
	
	newRect.origin.x = ([self frame].size.width - customImage.size.width) / 2.0;
	newRect.origin.y = ([self frame].size.height - customImage.size.height) / 2.0;
	
	[customImage setScalesWhenResized: YES];

	[customImage drawInRect: newRect fromRect: NSZeroRect operation: NSCompositeCopy fraction: 1.0f];
}

- (id)initWithFrame:(NSRect)frame controller:(CWApplication *)ctrlr
{
    self = [super initWithFrame:frame pullsDown:YES];
    if (self) {
        controller = ctrlr; // deliberately weak reference.
    }
    return self;
}

- (void)dealloc
{
    controller = nil;
    [super dealloc];
}

@end
