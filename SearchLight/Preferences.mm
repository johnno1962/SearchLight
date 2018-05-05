//
//  Preferences.m
//  SearchLight
//
//  Created by John Holdsworth on 04/03/2018.
//  Copyright © 2018 John Holdsworth. All rights reserved.
//

#import "Preferences.h"

//#import "validatereceipt.m"

Preferences *preferences;

@implementation NSColorWell (WebColor)

- (NSString *)stringValue {
    return [CIColor colorWithCGColor:self.color.CGColor].stringRepresentation;
}

- (void)setStringValue:(NSString *)value {
    self.color = [NSColor colorWithCIColor:[CIColor colorWithString:value]];
}

- (NSString *)formatColor:(NSString *)format {
    const CGFloat *components = CGColorGetComponents(self.color.CGColor);
    return [NSString stringWithFormat:format,
            (int)(components[0]*255.99), (int)(components[1]*255.99), (int)(components[2]*255.99)];
}

- (NSString *)webColor {
    return [self formatColor:@"#%02x%02x%02x"];
}

- (NSString *)borderColor {
    return [self formatColor:@"rgba(%d, %d, %d, 0.4)"];
}
@end

@implementation Preferences {
    IBOutlet NSBox *colorPrefs, *themes;
    IBOutlet NSPopUpButton *themeSelect;
    NSInteger lastTheme;
}

static NSArray *limitParams = @[@"initialLimit", @"maxMatches", @"maxLine", @"maxFile", @"maxImage"];
static NSArray *colorParams = @[@"headingColor", @"matchColor", @"previewColor",
                                @"headingTextColor", @"matchTextColor", @"previewTextColor"];

- (void)awakeFromNib {
    [super awakeFromNib];
    preferences = self;
    self.defaults = [NSUserDefaults standardUserDefaults];

    for (NSString *key in [limitParams arrayByAddingObjectsFromArray:colorParams])
        if (NSString *value = [self.defaults objectForKey:key])
            [[self valueForKey:key] setStringValue:value];

    [themeSelect.menu removeAllItems];
    for(NSBox *theme in themes.subviews[0].subviews)
        [themeSelect addItemWithTitle:theme.title];
#if 0
    NSString *receipt = [NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSLocalDomainMask, YES)
                .firstObject stringByAppendingPathComponent:@"Lightning.app/Contents/_MASReceipt/receipt"];
    BOOL lightning = initializeSemaphors(receipt);
    NSLog(@"Lightning? %hhd", lightning);

    if (!lightning) {
        NSMutableData *guidData = [(__bridge NSData*)copy_mac_address() mutableCopy];
        const char salt1[] = "gqmp6jxn4tn2tyhwqdcwcpkc0000gn", *salt2 = receipt.UTF8String ?: salt1;
        [guidData appendBytes:salt1 length:sizeof salt1];
        [guidData appendBytes:salt2 length:strlen(salt2)];
        unsigned char sha1[SHA_DIGEST_LENGTH];
        SHA1((const unsigned char *)[guidData bytes], [guidData length], sha1);

        time_t seal = 283746511, expires = [self.defaults integerForKey:@"expires"], clock = 0;
        NSMutableString *hash = [NSMutableString new];
        for (int i=0; i<sizeof sha1; i++)
            [hash appendFormat:@"%02x", sha1[i]];
        for (int i=0; i<hash.length; i++)
            seal += [hash characterAtIndex:i]*23;

        if (seal != [self.defaults integerForKey:@"seal"]) {
            NSString *url = [NSString stringWithFormat:@"https://birch.tchmachines.com/~johnhol/lightning/cgi-bin/lease.cgi?hash=%@", hash];
            NSError *error;
            NSString *lease = [NSString stringWithContentsOfURL:[NSURL URLWithString:url]
                                                       encoding:NSUTF8StringEncoding error:&error];
            if (error)
                NSLog(@"Could not get lease %@", error);
            static char message[1024];
            if (sscanf(lease.UTF8String?:"", "%ld %ld %ld %1023c", &seal, &expires, &clock, message) < 3) {
                NSLog(@"Could not parse lease %@", lease);
                [self appStore:NSLocalizedString(@"Unable to install evaluation period due to a networking error. Purchasing and installing \"Lightning\" from the Mac AppStore is an alternative to avoid this problem.", @"Networking")];
            }
            else {
                [self.defaults setInteger:seal forKey:@"seal"];
                [self.defaults setInteger:expires - clock + time(NULL) forKey:@"expires"];
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                if ([[NSAlert alertWithMessageText:@"SearchLight"
                                     defaultButton:@"Evaluate" alternateButton:@"Purchase Now" otherButton:nil
                         informativeTextWithFormat:message[0] ? [NSString stringWithUTF8String:message] :
                      NSLocalizedString(@"Welcome to SearchLight! You can use it without restriction until %sAfter this, an AppStore purchase may be required.", @"Intro"), ctime(&expires)]
                     runModal] == NSAlertAlternateReturn)
                      [self appStore:NSLocalizedString(@"Purchase the author's Web Browser \"Lightning\" to remove any restrictions on using this program.", @"Purchase")];
            }
        }

        if (seal != [self.defaults integerForKey:@"seal"] || time(NULL) > expires)
            [self appStore:NSLocalizedString(@"Your evaluation period for SearchLight has expired. Please purchase and install \"Lightning\" from the Mac App Store and SearchLight will be available again and you'll be supporting the author in future development.", @"Expired")];
    }
}

- (void)appStore:(NSString *)message {
    if ([[NSAlert alertWithMessageText:@"SearchLight"
                         defaultButton:@"Purchase" alternateButton:@"Exit" otherButton:nil
             informativeTextWithFormat:@"%@", message] runModal] == NSAlertDefaultReturn)
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"macappstores://itunes.apple.com/us/app/lightning/id412736557?mt=12"]];
    [NSApp terminate:nil];
#endif
}

- (void)save:(NSArray *)params {
    for (NSString *key in params)
        [self.defaults setObject:[[self valueForKey:key] stringValue] forKey:key];
}

- (IBAction)saveParams:(id)sender {
    [self save:limitParams];
}

- (IBAction)saveColors:(id)sender {
    if (sender)
        [themeSelect selectItemAtIndex:lastTheme = 0];
    [self save:colorParams];
    [self.ruleDelegate addRules];
}

- (IBAction)resetColors:(id)sender {
    for (NSString *key in colorParams)
        [self.defaults removeObjectForKey:key];
    [self.ruleDelegate addRules];
}

- (IBAction)themeChanged:(NSPopUpButton *)sender {
    NSInteger themeNember = themeSelect.indexOfSelectedItem;
    NSArray<NSColorWell *> *prefs = colorPrefs.subviews[0].subviews,
        *custom = themes.subviews[0].subviews[0].subviews[0].subviews,
        *theme = themes.subviews[0].subviews[themeNember].subviews[0].subviews;

    if (lastTheme == 0)
        for (NSInteger i=0; i < theme.count; i++)
            custom[i].color = prefs[i].color;

    for (NSInteger i=0; i < theme.count; i++)
        prefs[i].color = theme[i].color;

    lastTheme = themeNember;
    if ([themeSelect.selectedItem.title isEqualToString:@"Default"])
        [self resetColors:sender];
    else
        [self saveColors:nil];
}
@end
