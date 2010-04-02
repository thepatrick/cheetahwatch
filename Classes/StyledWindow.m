//
//  StyledWindow.m
//  StyledWindow
//
//  Created by Jeff Ganyard on 11/3/06.
/*
	Copyright (c) 2006 Bithaus.

	Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

	Sending an email to ganyard (at) bithaus.com informing where the code is being used would be appreciated.
*/

/* large portions borrowed from Matt Gemmell's TunesWindow sample wth permission */

#import "StyledWindow.h"
#import "CTGradient.h"


@implementation StyledWindow

- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)styleMask backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag;
{
	NSUInteger newStyle;
	if (styleMask & NSTexturedBackgroundWindowMask)
		newStyle = styleMask;
	else
		newStyle = (NSTexturedBackgroundWindowMask | styleMask);
	
	if (self = [super initWithContentRect:contentRect styleMask:newStyle backing:bufferingType defer:flag]) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResize:) name:NSWindowDidResizeNotification object:self];
		return self;
	}
	return nil;
}

#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
- (void)setToolbar:(NSToolbar *)toolbar
{
	// Only actually call this if we respond to it on this machine
	if ([toolbar respondsToSelector:@selector(setShowsBaselineSeparator:)])
		[toolbar setShowsBaselineSeparator:NO];

	[super setToolbar:toolbar];
}
#endif


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResizeNotification object:self];
	
	[borderStartColor release];
	[borderEndColor release];
	[borderEdgeColor release];
	
	[super dealloc];
}

- (void)windowDidResize:(NSNotification *)aNotification
{
	[self setBackgroundColor:[self styledBackground]];
	if ([self forceDisplay])
		[self display];
}

- (void)setMinSize:(NSSize)aSize
{
	[super setMinSize:NSMakeSize(MAX(aSize.width, 150.0), MAX(aSize.height, 150.0))];
}

- (void)setFrame:(NSRect)frameRect display:(BOOL)displayFlag animate:(BOOL)animationFlag
{
	[self setForceDisplay:YES];
	[super setFrame:frameRect display:displayFlag animate:animationFlag];
	[self setForceDisplay:NO];
}

- (NSColor *)styledBackground
{
	NSImage *bg = [[NSImage alloc] initWithSize:[self frame].size];
	CTGradient *styledGradient;
	if (![self borderStartColor] || ![self borderEndColor])
		styledGradient = [CTGradient unifiedPressedGradient];
	else
		styledGradient = [CTGradient gradientWithBeginningColor:[self borderStartColor] endingColor:[self borderEndColor]];

	// Set min width of temporary pattern image to prevent flickering at small widths
	CGFloat minWidth = 300.0;
	
	// Create temporary image for top gradient
	NSImage *topImg = [[NSImage alloc] initWithSize:NSMakeSize(MAX(minWidth, [self frame].size.width), [self topBorder]+1.0)];
	[topImg lockFocus];
	[styledGradient fillRect:NSMakeRect(0, 1, [topImg size].width, [topImg size].height) angle:270.0];
	[topImg unlockFocus];
	
	// Create temporary image for bottom gradient
	NSImage *bottomImg = [[NSImage alloc] initWithSize:NSMakeSize(MAX(minWidth, [self frame].size.width), [self bottomBorder]+1.0)];
	[bottomImg lockFocus];
	[styledGradient fillRect:NSMakeRect(0, 0, [bottomImg size].width, [bottomImg size].height-1.0) angle:270.0];
	[bottomImg unlockFocus];
	
	// Begin drawing into our main image
	[bg lockFocus];
	
	// Composite current background color into bg
	[bgColor set];
	//[[NSColor whiteColor] set];
	NSRectFill(NSMakeRect(0, 0, [bg size].width, [bg size].height));
	
	// Composite bottom gradient
	[bottomImg drawInRect:NSMakeRect(0, 0, [bg size].width, [self bottomBorder]) 
				 fromRect:NSMakeRect(0, 0, [bg size].width, [self bottomBorder]) 
				operation:NSCompositeSourceOver 
				 fraction:1.0];
	[bottomImg release];

	// Composite top gradient
	[topImg drawInRect:NSMakeRect(0, [bg size].height - [self topBorder], [bg size].width, [self topBorder]) 
			  fromRect:NSMakeRect(0, 0, [bg size].width, [self topBorder]) 
			 operation:NSCompositeSourceOver 
			  fraction:1.0];
	[topImg release];

	// draw border edges
	if (![self borderEdgeColor])
		[[NSColor colorWithDeviceWhite:0.25 alpha:1.0] setFill];
	else
		[[self borderEdgeColor] setFill];		

	NSRectFill(NSMakeRect(0, [bg size].height - [self topBorder], [bg size].width, 1.0));
	NSRectFill(NSMakeRect(0, [self bottomBorder], [bg size].width, 1.0));
	
	[bg unlockFocus];
	
	return [NSColor colorWithPatternImage:[bg autorelease]];
}


- (BOOL)forceDisplay
{
	return forceDisplay;
}
- (void)setForceDisplay:(BOOL)flag
{
	forceDisplay = flag;
}


- (CGFloat)topBorder
{
	return topBorder;
}
- (void)setTopBorder:(CGFloat)newTopBorder
{
	topBorder = newTopBorder;
}


- (CGFloat)bottomBorder
{
	return bottomBorder;
}
- (void)setBottomBorder:(CGFloat)newBottomBorder
{
	bottomBorder = newBottomBorder;
}


- (NSColor *)borderStartColor
{
	return borderStartColor; 
}
- (void)setBorderStartColor:(NSColor *)newBorderStartColor
{
	if (borderStartColor != newBorderStartColor) {
		[newBorderStartColor retain];
		[borderStartColor release];
		borderStartColor = newBorderStartColor;
	}
}


- (NSColor *)borderEndColor
{
	return borderEndColor; 
}
- (void)setBorderEndColor:(NSColor *)newBorderEndColor
{
	if (borderEndColor != newBorderEndColor) {
		[newBorderEndColor retain];
		[borderEndColor release];
		borderEndColor = newBorderEndColor;
	}
}


- (NSColor *)borderEdgeColor
{
	return borderEdgeColor; 
}
- (void)setBorderEdgeColor:(NSColor *)newBorderEdgeColor
{
	if (borderEdgeColor != newBorderEdgeColor) {
		[newBorderEdgeColor retain];
		[borderEdgeColor release];
		borderEdgeColor = newBorderEdgeColor;
	}
}


- (NSColor *)bgColor
{
	return bgColor; 
}
- (void)setBgColor:(NSColor *)newBgColor
{
	if (bgColor != newBgColor) {
		[newBgColor retain];
		[bgColor release];
		bgColor = newBgColor;
	}
}

@end
