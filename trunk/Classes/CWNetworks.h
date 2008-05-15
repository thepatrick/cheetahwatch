//
//  CWNetworks.h
//  CheetahWatch
//
//  Created by Patrick Quinn-Graham on 05/05/08.
//  Copyright 2008 Patrick Quinn-Graham. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol SCCSVFieldFactory;

@interface CWNetworks : NSObject {

	NSMutableArray *_data;

}

+networks;
-(BOOL)setupTheStuff;
-(NSString*)displayNameForCountry:(NSInteger)country andNetwork:(NSInteger)network;

@end
