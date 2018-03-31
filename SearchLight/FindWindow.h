//
//  FindWindow.h
//  SearchLight
//
//  Created by John Holdsworth on 03/03/2018.
//  Copyright © 2018 John Holdsworth. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface FindWindow : NSWindow

@end

@interface WebView(Findable)
- (void)makeFindable;
@end
