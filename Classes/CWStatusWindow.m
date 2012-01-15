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

#import "CWStatusWindow.h"


@implementation CWStatusWindow

// based on code from http://www.cocoarocket.com/articles/disclosureTriangles.html
- (IBAction)disclosureButtonAction:(id)sender
{
    NSRect frame = [self frame];
    // The -7 accounts for the space between the box and its neighboring views
    CGFloat sizeChange = [extraBox frame].size.height - 7;
    switch ([sender state]) {
        case NSOnState:
            // show the extra box.
            [extraBox setHidden:NO];
            // make the window bigger.
            frame.size.height += sizeChange;
            // move the origin.
            frame.origin.y -= sizeChange;
            break;
        case NSOffState:
            // hide the extra box.
            [extraBox setHidden:YES];
            // make the window smaller.
            frame.size.height -= sizeChange;
            // move the origin.
            frame.origin.y += sizeChange;
            break;
        default:
            break;
    }
    [self setFrame:frame display:YES animate:YES];
}


- (void)awakeFromNib
{
    // reset button state to saved state
    NSInteger state = [[[NSUserDefaults standardUserDefaults] valueForKey:@"CWStatusWindowDiscloseButtonState"] integerValue];
    if (state == NSOffState) {
        [self disclosureButtonAction:disclosureButton];
    }
}

@end
