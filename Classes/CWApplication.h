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

#import <Cocoa/Cocoa.h>

@class CWModel, CWModem, CWDialer, CWCustomView, MAAttachedWindow;

@interface CWApplication : NSApplication {

    // attributes
    CWModel *model;
	CWModem *modem;
    CWDialer *dialer;
    NSTimer *timer;
    NSStatusItem *statusItem;
	CWCustomView *statusItemView;
    BOOL trafficWarningDialogOpen;
	BOOL wasConnected;
    
    // IBOutlets
    IBOutlet NSMenu *statusItemMenu;
    IBOutlet NSWindow *firstRunWindow;
    IBOutlet NSWindow *apnWindow;
    IBOutlet NSTextField *apnField;
	IBOutlet NSWindow *pinWindow;
	NSString *pinRequestDesc;
	NSString *pukRequestDesc;
    IBOutlet NSSecureTextField *pinField;
    IBOutlet NSWindow *pukWindow;
    IBOutlet NSSecureTextField *pukField;
    IBOutlet NSSecureTextField *newPinField;
    IBOutlet NSMenu *modesPrefMenu;
}

// IB Actions
- (IBAction)connectButtonAction:(id)sender;
- (IBAction)showAboutPanelAction:(id)sender;
- (IBAction)setApnMenuAction:(id)sender;
- (IBAction)clearHistoryMenuAction:(id)sender;
- (IBAction)setModesPref:(id)sender;
- (IBAction)setPinLock:(id)sender;

// accessors
- (CWModel *)model;
- (void)setModel:(CWModel *)newModel;
- (CWModem *)modem;
- (void)setModem:(CWModem *)newModem;
- (CWDialer *)dialer;
- (void)setDialer:(CWDialer *)newDialer;


@end