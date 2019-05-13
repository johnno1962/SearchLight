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
    NSStatusItem *statusItem;
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
    [NSApp setServicesProvider:self];
    NSUpdateDynamicServices();
#if 0
    menuBarItem.title = [self menuBarApp] ? @"Quit MenuBar" : runMenuBar;
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
    [NSApp activateIgnoringOtherApps:YES];
}
#else
    menuBarItem.hidden = TRUE;
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
    if (![[NSDocumentController sharedDocumentController] documents].firstObject)
        [[NSDocumentController sharedDocumentController] newDocument:self];
    [[[NSDocumentController sharedDocumentController] documents].firstObject selectHome];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)fastScan:(NSPasteboard *)pboard
        userData:(NSString *)userData error:(NSString **)error {
  if (![pboard canReadObjectForClasses:@[[NSString class]] options:@{}]) {
    *error = NSLocalizedString(@"Error: couldn't looup text.",
                               @"pboard couldn't provide string.");
    return;
  }

  [self wakeUp:self];
  Document *search = [NSDocumentController sharedDocumentController].documents.firstObject;
  NSString *string = [pboard stringForType:NSPasteboardTypeString];
  [search performSelector:@selector(search:) withObject:string afterDelay:0.5];
}
#endif

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
        [[NSFileManager defaultManager] createDirectoryAtPath:agentPath.stringByDeletingLastPathComponent
                                  withIntermediateDirectories:NO  attributes:nil error:NULL];
        [agentPlist writeToFile:agentPath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
    else {
        [[self menuBarApp] terminate];
        menuBarItem.title = runMenuBar;
        [[NSFileManager defaultManager] removeItemAtPath:agentPath error:NULL];
    }
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
