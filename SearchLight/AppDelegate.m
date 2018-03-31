//
//  AppDelegate.m
//  SearchLight
//
//  Created by John Holdsworth on 01/03/2018.
//  Copyright © 2018 John Holdsworth. All rights reserved.
//

#import "AppDelegate.h"
#import "Preferences.h"
#import "Document.h"

@implementation AppDelegate {
    IBOutlet NSMenuItem *menuBarItem;
}

static NSString *runMenuBar = @"Run MenuBar";

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults valueForKey:@"mainSearch"])
        [defaults setValue:@[@"john +sam",
                             @"john +(sam ,peter)"] forKey:@"mainSearch"];
    if (![defaults valueForKey:@"fileSearch"]) {
        [defaults setValue:@[@"-*Downloads -*Auto*",
                             @".png ,.jpg ,.jpeg",
                             @"-Library"] forKey:@"fileSearch"];
    }
    NSUpdateDynamicServices();
    menuBarItem.title = [self menuBarApp] ? @"Quit MenuBar" : runMenuBar;
}

- (NSRunningApplication *)menuBarApp {
    return [NSRunningApplication
            runningApplicationsWithBundleIdentifier:@"com.johnholdsworth.SearchLightMenuBar"].firstObject;
}

- (IBAction)toggleMenuBar:sender {
    NSString *agentPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)
                           .firstObject stringByAppendingPathComponent:@"LaunchAgents/searchlight.launch.plist"];
    if ([[sender title] isEqualToString:runMenuBar]) {
        NSURL *url = [[NSBundle mainBundle] URLForResource:@"SearchLightMenuBar" withExtension:@"app"];
        [[NSWorkspace sharedWorkspace] openURL:url];
        menuBarItem.title = @"Quit MenuBar";

        NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"searchlight.launch" ofType:@"plist"];
        NSString *agentPlist = [NSString stringWithContentsOfFile:plistPath encoding:NSUTF8StringEncoding error:NULL];

        NSString *execPath = [NSBundle bundleWithURL:url].executablePath;
        if (@available(macOS 10_13, *)) {
            execPath = [NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSLocalDomainMask, YES)
                        .firstObject stringByAppendingPathComponent:@"SearchLight.app/Contents/Resources/SearchLightMenuBar.app/Contents/MacOS/SearchLightMenuBar"];
        }
        agentPlist = [agentPlist stringByReplacingOccurrencesOfString:@"__APPPATH__" withString:execPath];
        [agentPlist writeToFile:agentPath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
    else {
        [[self menuBarApp] terminate];
        menuBarItem.title = runMenuBar;
        [[NSFileManager defaultManager] removeItemAtPath:agentPath error:NULL];
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
    return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    return NSTerminateNow;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification;
{
    if (![[NSDocumentController sharedDocumentController] documents].count)
        [[NSDocumentController sharedDocumentController] newDocument:self];
//    [NSApp activateIgnoringOtherApps:YES];
}

- (IBAction)openStyles:sender {
    [[NSWorkspace sharedWorkspace] openURL:[[NSBundle mainBundle] URLForResource:@"Styles" withExtension:@"css"]];
}

- (IBAction)help:sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://johnholdsworth.com/searchlight.html"]];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
