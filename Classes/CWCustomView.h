//
//  CWCustomView.h
//  CheetahWatch
//
//  Created by Rauta Oskari on 18.2.2012.
//  Copyright (c) 2012 RoadRunner.cx. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CWApplication.h"

@class CWApplication;
@interface CWCustomView : NSPopUpButton {
    __weak CWApplication *controller;
	NSImage *customImage;
}

- (id)initWithFrame:(NSRect)frame controller:(CWApplication *)ctrlr;
- (void)setImage:(NSImage *)newImage;

@end
