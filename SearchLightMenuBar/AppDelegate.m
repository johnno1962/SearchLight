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

@implementation NSString(Contains)
- (BOOL)contains:(NSString *)str {
    return [self rangeOfString:str].location != NSNotFound;
}
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

- (IBAction)selectFolder:(id)sender {
    NSOpenPanel *open = [NSOpenPanel openPanel];
    open.directoryURL = [NSURL URLWithString:sender];
    open.prompt = NSLocalizedString(@"Select Search Scope", @"Select Search Scope");
    open.allowsMultipleSelection = TRUE;
    open.canChooseDirectories = TRUE;
    open.canChooseFiles = FALSE;
    //    open.showsHiddenFiles = TRUE;
    if ([open runModal] == NSFileHandlingPanelOKButton)
        ;//self.fileURL = (self.searchScopes = open.URLs).firstObject;
}

- (IBAction)wakeUp:sender {
    if ([NSHomeDirectory() contains:@"/Containers/"])
        [self selectFolder:NSHomeDirectory()];
    NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath].stringByDeletingLastPathComponent
                  .stringByDeletingLastPathComponent.stringByDeletingLastPathComponent];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
