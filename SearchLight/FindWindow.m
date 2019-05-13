//
//  FindWindow.m
//  SearchLight
//
//  Created by John Holdsworth on 03/03/2018.
//  Copyright © 2018 John Holdsworth. All rights reserved.
//

#import "FindWindow.h"
#import <WebKit/WebKit.h>
#import "Document.h"

@implementation FindWindow {
    IBOutlet NSSearchField *find;
@public
    IBOutlet WebView *webView;
}

- (IBAction)performFindPanelAction2:(id)sender {
    switch ([sender tag]) {
        case NSFindPanelActionSetFindString:
            find.stringValue = [[webView selectedDOMRange] toString];
        case NSFindPanelActionShowFindPanel:
            [find.window makeKeyAndOrderFront:self];
            [find selectText:self];
            break;
        case NSFindPanelActionNext:
            [self findNext:sender];
            break;
        case NSFindPanelActionPrevious:
            [webView searchFor:find.stringValue direction:NO caseSensitive:NO wrap:YES];
            break;
    }
}

- (IBAction)findNext:sender {
    [webView searchFor:find.stringValue direction:YES caseSensitive:NO wrap:YES];
}

- (void)swipeWithEvent:(NSEvent *)event {
//    NSLog(@"%@", event.description);
    if (event.type == NSEventTypeSwipe) {
        if (event.deltaX < 0)
            [(Document *)webView.UIDelegate back:self];
        else
            [(Document *)webView.UIDelegate forward:self];
    }
    else
        [super swipeWithEvent:event];
}

@end

@implementation WebView(Findable)
- (void)makeFindable {
    FindWindow *window = (FindWindow *)self.window;
    if (window)
        window->webView = self;
}
@end
