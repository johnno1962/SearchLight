//
//  AppDelegate.m
//  SearchLightMenuBar
//
//  Created by John Holdsworth on 08/03/2018.
//  Copyright © 2018 John Holdsworth. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate () {
    NSStatusItem *statusItem;
}

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    NSStatusBar *statusBar = [NSStatusBar systemStatusBar];
    statusItem = [statusBar statusItemWithLength:statusBar.thickness];
    statusItem.image = [NSImage imageNamed:@"SrchLight"];
    statusItem.toolTip = @"SearchLight";
    statusItem.highlightMode = YES;
    statusItem.enabled = YES;
    statusItem.title = @"";

    statusItem.button.target = self;
    statusItem.button.action = @selector(wakeUp:);
}

- (IBAction)wakeUp:sender {
    NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath].stringByDeletingLastPathComponent
                  .stringByDeletingLastPathComponent.stringByDeletingLastPathComponent];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
