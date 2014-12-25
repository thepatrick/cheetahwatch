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

const static size_t defaultWidth = 22;

- (void)setImage:(NSImage *)newImage
{
  [newImage retain];
  [customImage release];
  customImage = newImage;
  [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect
{
  CGFloat scale = [[NSScreen mainScreen] backingScaleFactor];
  NSRect newRect = NSMakeRect(0,0, customImage.size.width < defaultWidth ? defaultWidth : customImage.size.width, defaultWidth);
  [self setFrame:newRect];

  newRect.origin.x = ([self frame].size.width - customImage.size.width) / (2.0 * scale);
  newRect.origin.y = ([self frame].size.height - customImage.size.height) / (2.0 * scale);

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
