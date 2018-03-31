//
//  Preferences.h
//  SearchLight
//
//  Created by John Holdsworth on 04/03/2018.
//  Copyright © 2018 John Holdsworth. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol PreferencesChange
- (void)addRules;
@end

@interface Preferences : NSWindow

@property IBOutlet NSTextField *maxMatches, *initialLimit, *maxLine, *maxFile, *maxImage;
@property IBOutlet NSColorWell *headingColor, *matchColor, *previewColor;
@property IBOutlet NSColorWell *headingTextColor, *matchTextColor, *previewTextColor;

@property id<PreferencesChange> ruleDelegate;
@property NSUserDefaults *defaults;

@end

@interface NSColorWell (WebColor)
- (NSString *)webColor;
- (NSString *)borderColor;
@end

extern Preferences *preferences;
