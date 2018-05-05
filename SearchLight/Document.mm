//
//  Document.m
//  SearchLight
//
//  Created by John Holdsworth on 01/03/2018.
//  Copyright © 2018 John Holdsworth. All rights reserved.
//
//  $Id: //depot/SearchLight/SearchLight/Document.mm#178 $
//

#import "Document.h"
#import "Preferences.h"
#import "FindWindow.h"
#import "SourceKit.h"

#if DEBUG
#define SLLog NSLog
#else
#define SLLog while(0) NSLog
#endif

static NSString *ARCHIVE = @"__ARCHIVE__";
static NSDictionary *typesToSkip = @{@"pch": @1, @"pkg": @1};
static NSDictionary *archiveCommands = @{@"z": @[@"gzcat", ARCHIVE],
                                         @"gz": @[@"gzcat", ARCHIVE],
                                         @"pdf": @[@"/usr/local/bin/pdftotext", ARCHIVE, @"-"],
                                         @"zip": @[@"unzip", @"-l", ARCHIVE],
                                         @"tar": @[@"tar", @"tfv", ARCHIVE],
                                         @"tgz": @[@"tar", @"tfvz", ARCHIVE],
                                         @"tgZ": @[@"tar", @"tfvZ", ARCHIVE]};
static NSDictionary *imageTypes = @{@"png": @1, @"jpg": @1, @"jpeg": @1, @"tif": @1, @"tiff": @1, @"gif": @1};
static NSDictionary *sourceTypes = @{@"mm": @1, @"m": @1,  @"c": @1, @"h": @1, @"cpp": @1, @"hpp": @1, @"s": @1,
                                     @"swift": @1, @"metal": @1, @"java": @1, @"pl": @1, @"pm": @1, @"py": @1,
                                     @"rb": @1, @"js": @1, @"css": @1, @"html": @1, @"htm": @1, @"xml": @1};
static NSString *kMDItemDateReceived = @"com_apple_mail_dateReceived";

@interface Match: NSObject {
@public
    NSString *path;
    NSRange range;
}
@end
@implementation Match
@end

@interface Document () <PreferencesChange, WebPolicyDelegate, WebUIDelegate> {
    IBOutlet NSSearchField *search, *fileFilter;
    IBOutlet NSButton *caseInsensitive, *searchCancel, *folder, *emails, *wildcard, *backButton;
    IBOutlet WebView *webView, *nextResultView;
    IBOutlet NSPopUpButton *lines, *when;

    NSMutableArray<WebView *> *webViews;
    NSMetadataQuery *metadataSearch;
    NSDateFormatter *dateFormatter;
    NSRegularExpression *regex, *fileNots;
    NSMutableArray<Match *> *matches;
    WebScriptObject *script;
    NSNumberFormatter *sizeFormatter;
    NSUInteger resultCount, limit, maxLine;
    BOOL hasRules, scanArchives, pdftotext;
}

@property (nonatomic) NSArray *searchScopes;

@end

static NSDictionary *fileData;
static NSMutableDictionary *typeIcons;

@implementation NSString(Contains)
- (BOOL)contains:(NSString *)str {
    return [self rangeOfString:str].location != NSNotFound;
}
- (NSRange)range {
    return NSMakeRange(0, self.length);
}
- (NSString *)replace:(NSString *)from with:(NSString *)to {
    return [self stringByReplacingOccurrencesOfString:from withString:to];
}
- (NSString *)regex:(NSString *)from with:(NSString *)to {
    return [self stringByReplacingOccurrencesOfString:from withString:to
                                              options:NSRegularExpressionSearch range:self.range];
}
@end

@implementation NSImage(IconURL)

- (NSString *)iconURL {
    CGImageRef cgRef = [self CGImageForProposedRect:NULL context:nil hints:nil];
    NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
    [newRep setSize:[self size]];
    return [NSString stringWithFormat:@"data:image/png;base64,%@",
            [[newRep representationUsingType:NSPNGFileType properties:@{}]
             base64EncodedStringWithOptions:0]];
}
@end

@implementation Document

- (instancetype)init {
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.
    }
    return self;
}

+ (BOOL)autosavesInPlace {
    return YES;
}


- (NSString *)windowNibName {
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"Document";
}

- (void)awakeFromNib {
    [super awakeFromNib];

//    webView.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
    if (@available(macOS 10_10, *)) {
        webView.window.titlebarAppearsTransparent = YES;
    }

    script = webView.windowScriptObject;
    webView.drawsBackground = FALSE;
    webViews = [NSMutableArray new];
    matches = [NSMutableArray new];

    NSURL *html = [[NSBundle mainBundle] URLForResource:@"Splash" withExtension:@"html"];
    [webView.mainFrame loadRequest:[NSURLRequest requestWithURL:html]];

    [self setupSearchHistory:search];
    [self setupSearchHistory:fileFilter];
    [self setNextResultView];

    if (fileData) {
        self.searchScopes = @[[NSURL URLWithString:fileData[@"searchScopes"]]];
        search.stringValue = fileData[@"search"];
        fileFilter.stringValue = fileData[@"fileFilter"];
        if (fileData[@"when"])
            [when selectItemWithTitle:fileData[@"when"]];
        if (fileData[@"lines"])
            [lines selectItemWithTitle:fileData[@"lines"]];
        caseInsensitive.state = [fileData[@"caseInsensitive"] boolValue];
        wildcard.state = [fileData[@"wildcard"] boolValue];
        emails.state = [fileData[@"emails"] boolValue];
    }
    else
        self.searchScopes = @[self.fileURL = [NSURL fileURLWithPath: NSHomeDirectory()]];

    typeIcons = [NSMutableDictionary new];
    dateFormatter = [NSDateFormatter new];
    dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    dateFormatter.timeStyle = NSDateFormatterShortStyle;
    sizeFormatter = [NSNumberFormatter new];
    sizeFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    pdftotext = [[NSFileManager defaultManager] fileExistsAtPath:@"/usr/local/bin/pdftotext"];

    [NSApp setServicesProvider:self];
    [webView.window makeKeyAndOrderFront:self];

//    static BOOL opened;
//    if (!opened && [NSHomeDirectory() contains:@"/Containers/"])
//        [self selectFolder:NSHomeDirectory()];
}

- (void)setSearchScopes:(NSArray *)searchScopes {
    _searchScopes = searchScopes;
    folder.toolTip = [searchScopes.firstObject path];;
}

static NSURL *opened;

- (IBAction)selectFolder:(id)sender {
    NSOpenPanel *open = [NSOpenPanel new];
    if ([sender isKindOfClass:[NSString class]])
        open.directoryURL = [NSURL URLWithString:sender];
    open.prompt = NSLocalizedString(@"Select Search Scope", @"Select Search Scope");
    open.allowsMultipleSelection = TRUE;
    open.canChooseDirectories = TRUE;
    open.canChooseFiles = FALSE;
//    open.showsHiddenFiles = TRUE;
    if ([open runModal] == NSFileHandlingPanelOKButton) {
        [super showWindows];
        self.fileURL = opened = (self.searchScopes = open.URLs).firstObject;
    }
}

- (void)selectHome {
    if (!opened) {
        [self selectFolder:NSHomeDirectory()];
        opened = self.fileURL;
    }
    else {
        [super showWindows];
        self.fileURL = (self.searchScopes = @[opened]).firstObject;
    }
}

- (void)showWindows {
}

- (IBAction)prefs:sender {
    [preferences makeKeyAndOrderFront:self];
}

- (IBAction)quit:sender {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if ([[NSAlert alertWithMessageText:@"SearchLight"
                         defaultButton:@"Quit" alternateButton:@"Cancel" otherButton:nil
             informativeTextWithFormat:@"%@", NSLocalizedString(@"Exit SearchLight. Are you sure? You can leave the app running on the MenuBar by just closing the window.", @"Exit")] runModal] == NSAlertDefaultReturn)
#pragma clang diagnostic pop
        [NSApp terminate:sender];
}

- (void)setupSearchHistory:(NSSearchField *)searchField {
    NSMenu *cellMenu = [[NSMenu alloc] initWithTitle:NSLocalizedString(@"Search Menu", @"Search Menu title")];
    NSMenuItem *item;

    item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Clear", @"Clear menu title")
                                      action:NULL keyEquivalent:@""];
    [item setTag:NSSearchFieldClearRecentsMenuItemTag];
    [cellMenu insertItem:item atIndex:0];

    item = [NSMenuItem separatorItem];
    [item setTag:NSSearchFieldRecentsTitleMenuItemTag];
    [cellMenu insertItem:item atIndex:1];

    item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Recent Searches", @"Recent Searches menu title")
                                      action:NULL keyEquivalent:@""];
    [item setTag:NSSearchFieldRecentsTitleMenuItemTag];
    [cellMenu insertItem:item atIndex:2];

    item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Recents", @"Recents menu title")
                                      action:NULL keyEquivalent:@""];
    [item setTag:NSSearchFieldRecentsMenuItemTag];
    [cellMenu insertItem:item atIndex:3];

    [searchField.cell setSearchMenuTemplate:cellMenu];
}

- (NSDictionary *)state {
    return @{@"searchScopes": [self.searchScopes[0] absoluteString] ?: @"",
             @"search": search.stringValue ?: @"",
             @"fileFilter": fileFilter.stringValue ?: @"",
             @"when": when.selectedItem.title ?: @"",
             @"lines": lines.selectedItem.title ?: @"",
             @"caseInsensitive": @(caseInsensitive.state),
             @"wildcard": @(wildcard.state),
             @"emails": @(emails.state)};
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    // Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
//    [NSException raise:@"UnimplementedMethod" format:@"%@ is unimplemented", NSStringFromSelector(_cmd)];
    return [NSJSONSerialization dataWithJSONObject:[self state]
                                     options:NSJSONWritingPrettyPrinted error:nil];
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    // Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning NO.
    // You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
    // If you override either of these, you should also override -isEntireFileLoaded to return NO if the contents are lazily loaded.
//    [NSException raise:@"UnimplementedMethod" format:@"%@ is unimplemented", NSStringFromSelector(_cmd)];
    NSError *error;
    fileData = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error) {
        [NSAlert alertWithError:error];
        return NO;
    }
    return YES;
}

- (void)fastScan:(NSPasteboard *)pboard
        userData:(NSString *)userData error:(NSString **)error {
    if (![pboard canReadObjectForClasses:@[[NSString class]] options:@{}]) {
        *error = NSLocalizedString(@"Error: couldn't looup text.",
                                   @"pboard couldn't give string.");
        return;
    }

    search.stringValue = [pboard stringForType:NSPasteboardTypeString];
    [NSApp activateIgnoringOtherApps:YES];
    [self search:nil];
}

- (void)searchDirectory:(NSPasteboard *)pboard
               userData:(NSString *)userData error:(NSString **)error {
    NSArray *classes = @[[NSURL class]];
    NSDictionary *options = @{NSPasteboardURLReadingFileURLsOnlyKey: @(YES)};
    if (![pboard canReadObjectForClasses:classes options:options]) {
        *error = NSLocalizedString(@"Error: couldn't set directory.",
                                   @"pboard couldn't give URL.");
        return;
    }

    NSArray *fileURLs = [pboard readObjectsForClasses:classes options:options];
    SLLog(@"searchDirectory: %@", fileURLs);

    self.searchScopes = fileURLs;
    [NSApp activateIgnoringOtherApps:YES];
}

- (IBAction)search:sender;
{
    if ([sender isKindOfClass:NSSearchField.class] && ![sender stringValue].length)
        return;

    NSString *lcFileFilter = fileFilter.stringValue.lowercaseString,
        *nameItem = (id)kMDItemDisplayName, *searchItem = (id)kMDItemTextContent;
    for(NSString *imageType in imageTypes)
        if ([lcFileFilter contains:[@"." stringByAppendingString:imageType]] ||
            [lcFileFilter contains:[@"*." stringByAppendingString:imageType]])
            searchItem = nameItem;

    scanArchives = NO;
    for(NSString *archiveType in archiveCommands)
        if ([lcFileFilter hasPrefix:[@"." stringByAppendingString:archiveType]] ||
            [lcFileFilter hasPrefix:[@"*." stringByAppendingString:archiveType]])
            scanArchives = search.stringValue.length != 0;

    NSString *searchString = scanArchives && ![fileFilter.stringValue hasPrefix:@".pdf"] ?
                                                                @"" : search.stringValue;
    NSString *predicateString = [self parseQuery:searchString against:searchItem];

    if (fileFilter.stringValue.length) {
        NSString *fileQuery = [self parseQuery:fileFilter.stringValue
                                       against:(id)kMDItemDisplayName];
        predicateString = predicateString.length ?
                [NSString stringWithFormat:@"(%@) && (%@)", predicateString, fileQuery] : fileQuery;
    }

    if (NSInteger since = when.selectedTag)
        predicateString = [NSString stringWithFormat:@"%@ > $time.now(%ld) && (%@)",
                           kMDItemFSContentChangeDate, -since, predicateString];

    if (!emails.state)
        predicateString = [NSString stringWithFormat:@"%@ != com.apple.mail.emlx && (%@)",
                           kMDItemContentType, predicateString];

    SLLog(@"predicateString: %@", predicateString);
    if (!search.stringValue.length && !fileFilter.stringValue.length)
        return;

    @try {
        searchCancel.toolTip = predicateString;
        NSPredicate *searchPredicate = [NSPredicate predicateFromMetadataQueryString:predicateString];

        if ([searchCancel.title isEqualToString:@"Cancel"]) {
            [script callWebScriptMethod:@"appendMatch"
                          withArguments:@[@0, NSLocalizedString(@"\n<div class=heading>Cancelled", @"\n  Cancelled")]];
            [metadataSearch stopQuery];
            metadataSearch = nil;
            searchCancel.title = @"Search";
            return;
        }

        [self newWebView];

        searchCancel.title = @"Cancel";
        preferences.ruleDelegate = self;

        fileData = [self state];

        regex = nil;
        if (search.stringValue.length && searchItem != nameItem && lines.selectedTag)
            regex = [self regexFor:search];

        fileNots = [self regexFor:fileFilter];
//        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            [self initiateSearch:self.searchScopes predicate:searchPredicate];
//        });
    }
    @catch(NSException *e) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [[NSAlert alertWithMessageText:@"SearchLight"
                         defaultButton:@"OK" alternateButton:nil otherButton:nil
             informativeTextWithFormat:NSLocalizedString(@"Sorry, I couldn't parse that filter correctly.\n\n%@", @"Bad Query"), e.description] runModal];
#pragma clang diagnostic pop
    }
}

- (NSString *)parseQuery:(NSString *)query against:(NSString *)item {
    NSString *modifiers = caseInsensitive.state ?
        wildcard.state ? @"cdw" : @"cd" : wildcard.state ? @"w" : @"";
    NSMutableArray<NSString *> *ors = [NSMutableArray new];

    for (NSString *orClause in query.length ?
         [[self shorthand:query] componentsSeparatedByString:@" ,"] : @[]) {
        NSMutableArray<NSString *> *ands = [NSMutableArray new];

        for (__strong NSString *andClause in [orClause componentsSeparatedByString:@" +"]) {
            NSMutableString *pre = [NSMutableString new], *post = [NSMutableString new];
            andClause = [self unescape:[self unbracket:andClause pre:pre post:post]];
            [ands addObject:[NSString stringWithFormat:@"%@%@ = \"%@\"%@%@",
                             pre, item, [self stringEscape:andClause], modifiers, post]];
        }

        [ors addObject:[ands componentsJoinedByString:@" && "]];
    }

    return [ors componentsJoinedByString:@" || "];
}

- (NSString *)shorthand:(NSString *)query {
    return [[query replace:@" -" with:@" +-"] replace:@" !" with:@" +-"];
}

- (NSString *)unescape:(NSString *)string {
    return [string regex:@" \\\\([-+,!])" with:@" $1"];
}

- (NSString *)unbracket:(NSString *)string pre:(NSMutableString *)pre post:(NSMutableString *)post {
    if ([string hasPrefix:@"!"] || [string hasPrefix:@"-"]) {
        [pre appendString:@"!("];
        [post appendString:@")"];
        string = [string substringFromIndex:1];
    }
    while ([string hasPrefix:@"("]) {
        [pre appendString:@"("];
        string = [string substringFromIndex:1];
    }
    while ([string hasSuffix:@")"]) {
        [post appendString:@")"];
        string = [string substringToIndex:string.length-1];
    }
    return string;
}

- (NSString *)stringEscape:(NSString *)string {
    return [[string replace:@"\\" with:@"\\\\"] replace:@"\"" with:@"\\\""];
}

- (NSRegularExpression *)regexFor:(NSTextField *)field;
{
    static NSString *dotStar = @"\\E.*?\\Q";
    NSString *pattern = [[self shorthand:field.stringValue] replace:@"*" with:dotStar];
    NSMutableArray<NSString *> *ors = [[pattern componentsSeparatedByString:@" ,"] mutableCopy];
    NSMutableArray<NSString *> *nots = [NSMutableArray new];

    for (NSInteger i = 0; i < ors.count; i++) {
        NSMutableArray *ands = [NSMutableArray new];
        for (__strong NSString *andClause in [ors[i] componentsSeparatedByString:@" +"]) {
            andClause = [self unescape:andClause];
            if ([andClause hasPrefix:@"-"] || [andClause hasPrefix:@"!"])
                [nots addObject:[NSString stringWithFormat:@"/%@/",
                                 [andClause regex:@"^([-!])" with:@""]]];
            else {
                if ([andClause hasPrefix:dotStar])
                    andClause = [andClause substringFromIndex:dotStar.length];
                [ands addObject:[andClause
                                 stringByAppendingString:ands.count ? @"\\E)\\Q" : @""]];
            }
        }

        ors[i] = [NSString stringWithFormat:@"\\E(\\Q%@\\E)\\Q",
                  [ands componentsJoinedByString:@"\\E(.*?\\Q"]];
    }

    pattern = [NSString stringWithFormat:@"\\Q%@\\E",
               [field == fileFilter ? nots : ors componentsJoinedByString:@"\\E|\\Q"]];

    SLLog(@"regexPattern: %@", pattern);
    NSError *error;
    NSRegularExpression *regout;
    if (![pattern isEqualToString:@"\\Q\\E(\\Q\\E)\\Q\\E"] && ![pattern isEqualToString:@"\\Q\\E"])
        regout = [NSRegularExpression regularExpressionWithPattern:pattern options:caseInsensitive.state ?
                               NSRegularExpressionCaseInsensitive : 0 error:&error];
    if (error)
        [[NSAlert alertWithError:error] runModal];

    return regout;
}

- (void)addRules {
    if ([preferences.defaults objectForKey:@"headingColor"] || hasRules) {
        [self addRule:@"div.heading { background-color: %@; }"
                 from:preferences.headingColor.webColor extra:nil to:webView];
        [self addRule:@"div.heading, div.heading > a:link { color: %@; }"
                 from:preferences.headingTextColor.webColor extra:nil to:webView];
        [self addRule:@"div.match { background-color: %@; border: 1px solid %@; }"
                 from:preferences.matchColor.webColor extra:preferences.headingColor.borderColor to:webView];
        [self addRule:@"div.match, div.match > a:link { color: %@; }"
                 from:preferences.matchTextColor.webColor extra:nil to:webView];
        [self addRule:@"div.preview { background-color: %@; }"
                 from:preferences.previewColor.webColor extra:nil to:webView];
        [self addRule:@"table, a:link, span.linenumber { color: %@; }"
                 from:preferences.previewTextColor.webColor extra:nil to:webView];
        hasRules = YES;
    }
    [self addRule:@"img.image { max-width: %@; }"
             from:@(webView.frame.size.width - 60.).stringValue extra:nil to:webView];
}

- (void)addRule:(NSString *)rule from:(NSString *)well extra:(NSString *)extra to:(WebView *)webView {
    [webView.windowScriptObject callWebScriptMethod:@"addRule"
                                      withArguments:@[[NSString stringWithFormat:rule,
                                                       well, extra]]];
}

// Initialize Search Method
- (void)initiateSearch:(NSArray *)searchScopes predicate:(NSPredicate *)searchPredicate;
{
    // Create the metadata query instance. The metadataSearch @property is
    // declared as retain
    [metadataSearch stopQuery];
    metadataSearch = [[NSMetadataQuery alloc] init];
    limit = preferences.initialLimit.intValue;
    maxLine = preferences.maxLine.intValue;
    resultCount = 0;
    SLLog(@"initiateSearch:");

//    [script callWebScriptMethod:@"startQuery" withArguments:@[]];

    // Register the notifications for batch and completion updates
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(queryDidUpdate:)
                                                 name:NSMetadataQueryDidUpdateNotification
                                               object:metadataSearch];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(initalGatherComplete:)
                                                 name:NSMetadataQueryDidFinishGatheringNotification
                                               object:metadataSearch];

    [metadataSearch setPredicate:searchPredicate];
    [metadataSearch setSearchScopes:searchScopes];

//    metadataSearch.valueListAttributes = @[(id)kMDItemPath];

    // Configure the sorting of the results so it will order the results by the
    // date emial received then display name
    [metadataSearch setSortDescriptors:@[
         [[NSSortDescriptor alloc] initWithKey:kMDItemDateReceived ascending:NO],
         [[NSSortDescriptor alloc] initWithKey:(id)kMDItemDisplayName ascending:YES],
         [[NSSortDescriptor alloc] initWithKey:(id)kMDItemFSContentChangeDate ascending:NO]]];

    // Begin the asynchronous query
    [metadataSearch startQuery];
}

// Method invoked when notifications of content batches have been received
- (void)queryDidUpdate:sender;
{
    [metadataSearch disableUpdates];

    // Look at each element returned by the search
    // - note it returns the entire list each time this method is called, NOT just the changes
    SLLog(@"queryDidUpdate: %d", (int)[metadataSearch resultCount]);

    // Process the content. In this case the application simply
    // iterates over the content, printing the display name key for
    // each image
    NSString *mailHome = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)
                          .firstObject stringByAppendingPathComponent:@"Mail"];
    for (NSUInteger i=0; i < [metadataSearch resultCount]; i++) {
        @try {
            NSMetadataItem *theResult = [metadataSearch resultAtIndex:i];
//            NSLog(@"result at %lu - %@ %@ %@", i, theResult.attributes, [metadataSearch valueOfAttribute:(NSString *)kMDItemTitle forResultAtIndex:i],  [theResult valueForAttribute:(id)kMDItemPath]);
            NSString *name = [theResult valueForAttribute:(id)kMDItemDisplayName],
                *path = [theResult valueForAttribute:(id)kMDItemPath] ?:
                        [[theResult valueForAttribute:(id)kMDItemURL] path] ?:
                        name, *type = path.pathExtension.lowercaseString ?: @"";

            if ([path contains:@"TurboWeb"] || [path contains:@"CachedData"])
                continue;
            if (!emails.state && [path hasPrefix:mailHome])
                continue;
            if ([fileNots firstMatchInString:path options:0 range:path.range])
                continue;

            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
            NSDate *date = attributes.fileModificationDate ?:
                [theResult valueForAttribute:(id)kMDItemFSContentChangeDate] ?:
                [NSDate dateWithTimeIntervalSince1970:0.];
            NSString *icon = attributes.fileType == NSFileTypeDirectory ?
                [[NSWorkspace sharedWorkspace] iconForFile:path].iconURL : [self iconForType:type];

            NSString *file = path.lastPathComponent, *dir = path.stringByDeletingLastPathComponent,
                    *link = [dir stringByReplacingOccurrencesOfString:NSHomeDirectory() withString:@"~"],
                    *size = [sizeFormatter stringFromNumber:attributes[NSFileSize]] ?: @"";
            id div;
            if (imageTypes[type]) {
                div = [script callWebScriptMethod:@"appendImage" withArguments:@[icon, name,
                                file, dir, link, [dateFormatter stringFromDate:date], size]];
                if (lines.selectedTag)
                    [self->script callWebScriptMethod:@"appendMatch" withArguments:@[div,
                     [NSString stringWithFormat:@"<img class=image src=\"file://%@\">", path]]];
            }
            else {
                if ([type isEqualToString:@"emlx"])
                    div = [script callWebScriptMethod:@"appendEmail" withArguments:@[icon, name, file, dir, link,
                        [dateFormatter stringFromDate:[theResult valueForAttribute:kMDItemDateReceived] ?: date],
                        size, [theResult valueForAttribute:(id)kMDItemAuthors] ?: @"",
                        [theResult valueForAttribute:(id)kMDItemAuthorEmailAddresses] ?: @""]];
                else {
                    NSArray *proj = @[];
                    if (sourceTypes[type])
                        if (NSString *project = [self projectForSourceFile:path])
                            proj = @[project, [self iconForType:project.pathExtension], project.lastPathComponent];

                    div = [script callWebScriptMethod:@"appendFile" withArguments:@[icon, name,
                        file, dir ?: @"", link, [dateFormatter stringFromDate:date], size, proj,
                        [theResult valueForAttribute:(id)kMDItemURL] ?: @0]];
                }

                if (!typesToSkip[type] &&
                    attributes.fileType != NSFileTypeDirectory &&
                    attributes.fileSize <= preferences.maxFile.integerValue)
                    [self addMatches:path to:div];
            }
        }
        @catch (NSException *e) {
            NSLog(@"Caught exception: %@", e);
        }

        if (++resultCount >= limit) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            if ([[NSAlert alertWithMessageText:@"SearchLight"
                                 defaultButton:@"Continue" alternateButton:@"Enough already!" otherButton:nil
                     informativeTextWithFormat:NSLocalizedString(@"%d results found so far.  Keep searching?\nIf you press \"Continue\" the threshold will be doubled.\nYou can raise this threshold in the app's preferences.", @"Keep Searching?"),
                  (int)resultCount] runModal] == NSAlertDefaultReturn) {
#pragma clang diagnostic pop
                limit *= 2;
            }
            else {
                searchCancel.title = @"Search";
                [metadataSearch stopQuery];
                return;
            }
        }
    }

    SLLog(@"Done...");
    [metadataSearch enableUpdates];
}

- (void)addMatches:(NSString * _Nonnull)path to:(id _Nonnull)div {
    NSInteger maxMatches = preferences.maxMatches.integerValue, surroundingLines = self->lines.selectedTag;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        if (NSString *contents = [self loadAndNormalise:path]) {
            __block NSInteger matchCount = 0;
            NSRegularExpression *regex = self->regex;
            [regex enumerateMatchesInString:contents options:0 range:contents.range
             usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
                 NSRange range = result.range;
                 NSUInteger start = [self next:-surroundingLines from:range.location in:contents];
                 NSUInteger end = [self next:surroundingLines from:NSMaxRange(range) in:contents];

                 NSString *line = [contents substringWithRange:NSMakeRange(start, end-start)];
                 NSRange found = NSMakeRange(range.location-start, range.length);
                 static NSString *linkPlaceholder = @"__LINK__PLACEHOLDER__";
                 line = [self htmlEscape:[line stringByReplacingCharactersInRange:found
                                                                       withString:linkPlaceholder]];
                 Match *match = [Match new];
                 match->path = path;
                 match->range = range;

                 dispatch_async(dispatch_get_main_queue(), ^{
                     NSString *link = [NSString stringWithFormat:@"<a href='match://%d'>%@</a>",
                                       (int)self->matches.count,
                                       [self htmlEscape:[contents substringWithRange:result.range]]];
                     NSString *html = [line replace:linkPlaceholder with:link];
                     [self->matches addObject:match];

                     [self->script callWebScriptMethod:@"appendMatch" withArguments:@[div, html]];
                 });

                 if (++matchCount >= maxMatches) {
                     *stop = TRUE;
                     dispatch_async(dispatch_get_main_queue(), ^{
                         [self->script callWebScriptMethod:@"appendEndMatches" withArguments:@[div]];
                     });
                 }
             }];
        }
    });
}

- (NSString * _Nullable)loadAndNormalise:(NSString * _Nonnull)path {
    NSString *ext = path.pathExtension.lowercaseString;
    if (NSArray *command = archiveCommands[ext]) {
        if (scanArchives || (regex && pdftotext && [ext isEqualToString:@"pdf"])) {
            if ([ext isEqualToString:@"gz"] &&
                [path.stringByDeletingPathExtension.pathExtension.lowercaseString isEqualToString:@"tar"])
                command = archiveCommands[@"tgz"];
            if ([ext isEqualToString:@"z"] &&
                [path.stringByDeletingPathExtension.pathExtension.lowercaseString isEqualToString:@"tar"])
                command = archiveCommands[@"tgZ"];
            NSMutableArray *args = [command mutableCopy];
            for (int i=0; i<args.count; i++)
                if ([args[i] isEqualToString:ARCHIVE])
                    args[i] = path;

            NSTask *task = [NSTask new];
            task.launchPath = @"/usr/bin/env";
            task.arguments = args;
            task.standardOutput = [NSPipe new];
            [task launch];
            NSData *data = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
            [task waitUntilExit];
            [[task.standardOutput fileHandleForReading] closeFile];
            if (data.length && task.terminationStatus == EXIT_SUCCESS)
                return [self normalise:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?:
                                    [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding]];
        }
        return nil;
    }

    NSError *error;
    if (NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error]
                  ?: [NSString stringWithContentsOfFile:path encoding:NSISOLatin1StringEncoding error:&error]) {
        return [self normalise:contents];
    }

    NSLog(@"Could not open %@ - %@", path, error);
    return nil;
}

- (NSString * _Nonnull)normalise:(NSString * _Nonnull)contents {
    while ([contents contains:@"\r\n"])
        contents = [contents replace:@"\r\n" with:@"\n"];
    if ([contents contains:@"\r"])
        contents = [contents replace:@"\r" with:@"\n"];
    return contents;
}

- (NSUInteger)next:(NSInteger)dir from:(NSUInteger)loc in:(NSString * _Nonnull)contents;
{
    NSStringCompareOptions backwards = dir < 0 ? NSBackwardsSearch : 0;
    dir = abs((int)dir);
    while (dir--) {
        NSRange range = backwards ? NSMakeRange(0, loc) : NSMakeRange(loc, contents.length-loc);
        loc = [contents rangeOfString:@"\n" options:backwards range:range].location;
        if (loc == NSNotFound)
            return backwards ? 0 : contents.length;
        if (!backwards)
            loc++;
    }
    return loc + (backwards ? 1 : 0);
}

- (NSString * _Nonnull)iconForType:(NSString * _Nonnull)type {
    static NSMutableDictionary *typeIcons;
    if (!typeIcons)
        typeIcons = [NSMutableDictionary new];
    return typeIcons[type] ?:
        (typeIcons[type] = [[NSWorkspace sharedWorkspace] iconForFileType:type].iconURL) ?: typeIcons[@""];
}

- (NSString * _Nullable)projectForSourceFile:(NSString * _Nonnull)sourceFile {
    NSString *directory = sourceFile.stringByDeletingLastPathComponent;
    static NSMutableDictionary *cache;
    if (!cache)
        cache = [NSMutableDictionary new];
    if (NSString *projectFile = cache[directory])
        return (id)projectFile != [NSNull null] ? projectFile : nil;

    if ([directory isEqualToString:@"/"])
        return nil;

    NSString *projectFile = [self projectForSourceFile:directory];
    cache[directory] = projectFile ?: [NSNull null];
    if (projectFile)
        return projectFile;

    NSArray<NSString *> *fileList = [[NSFileManager defaultManager]
                                     contentsOfDirectoryAtPath:directory error:NULL];

    if (NSString *projectFile =
        [self fileWithExtension:@"xcworkspace" inFiles:fileList] ?:
        [self fileWithExtension:@"xcodeproj" inFiles:fileList])
        return cache[directory] = [directory stringByAppendingPathComponent:projectFile];

    return nil;
}

- (NSString * _Nullable)fileWithExtension:(NSString * _Nonnull)extension inFiles:(NSArray * _Nonnull)files {
    for (NSString *file in files)
        if ([file.pathExtension isEqualToString:extension])
            return file;
    return nil;
}

// Method invoked when the initial query gathering is completed
- (void)initalGatherComplete:sender;
{
    SLLog(@"initalGatherComplete: %d", (int)[metadataSearch resultCount]);
    // Stop the query, the single pass is completed.
    if (![metadataSearch resultCount])
        [script callWebScriptMethod:@"appendResult"
                      withArguments:@[NSLocalizedString(@"No results", @"No results")]];
    else
        [self queryDidUpdate:sender];

    searchCancel.title = @"Search";
    [metadataSearch stopQuery];

//    NSLog(@"\n%@", [(DOMHTMLElement *)[[[webView mainFrame] DOMDocument] documentElement] outerHTML]);

    // Remove the notifications to clean up after ourselves.
    // Also release the metadataQuery.
    // When the Query is removed the query results are also lost.
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSMetadataQueryDidUpdateNotification
                                                  object:metadataSearch];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSMetadataQueryDidFinishGatheringNotification
                                                  object:metadataSearch];

    [script callWebScriptMethod:@"appendTotal" withArguments:@[@(resultCount)]];

    metadataSearch = nil;
    if (![metadataSearch resultCount])
        [search.window makeFirstResponder:search];
    else
        [webView.window makeFirstResponder:webView];
}

- (void)showMatch:(NSUInteger)selno;
{
    Match *match = matches[selno];
    if (NSString *contents = [self loadAndNormalise:match->path]) {
        NSString *html = sourceTypes[match->path.pathExtension] ?
                          [[SourceKit shared] formatFile:match->path] : nil;
        if (html)
            html = [self normalise:html];
        else {
            static NSString *linkPlaceholder = @"__LINK__PLACEHOLDER__";
            html = [[self htmlEscapeAll:[contents stringByReplacingCharactersInRange:match->range
                                                                          withString:linkPlaceholder]]
                    replace:linkPlaceholder
                    with:[NSString stringWithFormat:@"<span class=highlight>%@</span>",
                                [contents substringWithRange:match->range]]];
        }

        NSInteger rangeLine = [self lineForRange:match->range in:contents];
        NSArray<NSString *> *lines = [html componentsSeparatedByString:@"\n"];
        NSMutableString *body = [NSMutableString stringWithString:@"<div class=preview>"];

        for(int line = 0; line < lines.count; line++) {
            html = lines[line];
            if (line == rangeLine && ![html contains:@"<a href="]) {
                NSRange range = html.range;
                while (NSTextCheckingResult *match = [regex firstMatchInString:html
                                                                       options:0 range:range]) {
                    NSString *span = [NSString stringWithFormat:@"<span class=highlight>%@</span>",
                                      [html substringWithRange:match.range]];
                    html = [html stringByReplacingCharactersInRange:match.range withString:span];
                    range.location += span.length;
                    range.length = html.length - range.location;
                }
            }

            [body appendFormat:@"<span class=%@>%05d</span> %@\n",
             line == rangeLine ? @"highlight" :
             line == rangeLine - 3 || (rangeLine - 3 < 0 && line == 0) ?
             @"linenumber id=matchLocation" : @"linenumber", line+1, html];
        }

        [self newWebView];
        [script callWebScriptMethod:@"setSource" withArguments:@[match->path, body]];
    }
}

- (NSInteger)lineForRange:(NSRange)range in:(NSString * _Nonnull)string {
    NSUInteger numberOfLines = 0, stringLength = [string length];

    for (NSUInteger index = 0; index <= range.location && index < stringLength; numberOfLines++)
        index = NSMaxRange([string lineRangeForRange:NSMakeRange(index, 0)]);

    return numberOfLines - 1;
}

- (void)setNextResultView {
    nextResultView = [[WebView alloc] initWithFrame:webView.frame frameName:@"" groupName:@""];
    nextResultView.autoresizingMask = webView.autoresizingMask;
    nextResultView.drawsBackground = FALSE;
    nextResultView.policyDelegate = self;
    nextResultView.UIDelegate = self;
    NSURL *html = [[NSBundle mainBundle] URLForResource:@"Results" withExtension:@"html"];
    [nextResultView.mainFrame loadRequest:[NSURLRequest requestWithURL:html]];
}

- (void)exchangeWebView:(WebView *)newWebView {
    NSView *parent = [webView superview];
    newWebView.frame = webView.frame;
    [webView removeFromSuperview];

    webView = newWebView;
    [parent addSubview:webView];
    script = webView.windowScriptObject;
    [webView makeFindable];
    [self addRules];

    backButton.enabled = webViews.count != 0;
}

- (void)newWebView {
    [webViews addObject:webView];
    [self exchangeWebView:nextResultView];
    [self setNextResultView];
}

- (IBAction)back:sender {
    if (WebView *oldWebView = webViews.lastObject) {
        [webViews removeLastObject];
        [self exchangeWebView:oldWebView];
    }
}

- (NSString *)htmlEscape:(NSString *)text;
{
    return [self htmlEscapeAll:text.length > maxLine ? [text substringToIndex:maxLine] : text];
}

- (NSString *)htmlEscapeAll:(NSString *)text;
{
    return [[text replace:@"&" with:@"&amp;"] replace:@"<" with:@"&lt;"];
}

- (void)webView:(WebView *)webView addMessageToConsole:(NSDictionary *)message;
{
    NSLog( @"addMessageToConsole: %@", message );
}

- (void)webView:(WebView *)sender runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame;
{
    NSLog( @"runJavaScriptAlertPanelWithMessage: %@", message );
}

- (void)webView:(WebView *)aWebView decidePolicyForNavigationAction:(NSDictionary *)actionInformation
        request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id < WebPolicyDecisionListener >)listener;
{
    if (request.URL.isFileURL &&
        ([request.URL.path.lastPathComponent isEqualToString:@"Splash.html"] ||
         [request.URL.path.lastPathComponent isEqualToString:@"Results.html"])) {
        [listener use];
        return;
    }
    else if ([request.URL.scheme isEqualToString:@"match"])
        [self showMatch:request.URL.resourceSpecifier.lastPathComponent.integerValue];
    else if ([request.URL.absoluteString.lastPathComponent isEqualToString:@"Resources"])
        [listener use];
    else
        [[NSWorkspace sharedWorkspace] openURL:request.URL];
    [listener ignore];
}
@end
