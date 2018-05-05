//
//  SourceKit.m
//  SearchLight
//
//  Created by John Holdsworth on 06/03/2018.
//  Copyright © 2018 John Holdsworth. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SourceKit.h"
#import "sourcekitd.h"
#import <dlfcn.h>

@implementation SourceKit {
    void *handle;
    void (*sourcekitd_initialize)(void);
    sourcekitd_uid_t (*sourcekitd_uid_get_from_cstr)(const char *string);
    sourcekitd_object_t (*sourcekitd_request_dictionary_create)(const sourcekitd_uid_t *keys,
                                                                const sourcekitd_object_t *values,
                                                                size_t count);
    void (*sourcekitd_request_dictionary_set_uid)(sourcekitd_object_t dict,
                                                  sourcekitd_uid_t key,
                                                  sourcekitd_uid_t uid);
    void (*sourcekitd_request_dictionary_set_string)(sourcekitd_object_t dict,
                                                     sourcekitd_uid_t key,
                                                     const char *string);
    void (*sourcekitd_request_dictionary_set_int64)(sourcekitd_object_t dict,
                                                    sourcekitd_uid_t key, int64_t val);
    void (*sourcekitd_request_description_dump)(sourcekitd_object_t obj);
    sourcekitd_response_t (*sourcekitd_send_request_sync)(sourcekitd_object_t req);
    void (*sourcekitd_request_release)(sourcekitd_object_t object);
    bool (*sourcekitd_response_is_error)(sourcekitd_response_t obj);
    void (*sourcekitd_response_description_dump_filedesc)(sourcekitd_response_t resp,
                                                          int fd);
    void (*sourcekitd_response_dispose)(sourcekitd_response_t obj);

    sourcekitd_uid_t requestID, editorOpenID, nameID, sourceFileID, enableMapID, enableSubID,  syntaxOnlyID;

    sourcekitd_variant_t (*sourcekitd_response_get_value)(sourcekitd_response_t resp);
    bool (*sourcekitd_variant_array_apply)(sourcekitd_variant_t array,
                                           sourcekitd_variant_array_applier_t applier);
    bool (*sourcekitd_variant_array_apply_f)(sourcekitd_variant_t array,
                                             sourcekitd_variant_array_applier_f_t applier,
                                             void *context);
    sourcekitd_uid_t (*sourcekitd_variant_dictionary_get_uid)(sourcekitd_variant_t dict,
                                                              sourcekitd_uid_t key);
    sourcekitd_variant_t (*sourcekitd_variant_dictionary_get_value)(sourcekitd_variant_t dict,
                                                                    sourcekitd_uid_t key);
    const char * (*sourcekitd_uid_get_string_ptr)(sourcekitd_uid_t obj);
    int64_t (*sourcekitd_variant_dictionary_get_int64)(sourcekitd_variant_t dict,
                                                       sourcekitd_uid_t key);
    size_t (*sourcekitd_variant_array_get_count)(sourcekitd_variant_t array);
    sourcekitd_variant_t (*sourcekitd_variant_array_get_value)(sourcekitd_variant_t array, size_t index);

    sourcekitd_uid_t syntaxID, kindID, offsetID, lengthID, editorCloseID;
}


+ (instancetype)shared {
    static SourceKit *sourceKit;
    if (!sourceKit)
        sourceKit = [SourceKit new];
    return sourceKit;
}

- (instancetype)init {
    if (!(self = [super init]))
        return nil;

//    NSOpenPanel *open = [NSOpenPanel new];
//    open.directoryURL = [NSURL URLWithString:@"/Applications/Xcode.app"];
//    open.prompt = NSLocalizedString(@"Select Search Scope", @"Select Search Scope");
//    open.allowsMultipleSelection = TRUE;
//    open.canChooseDirectories = TRUE;
//    open.canChooseFiles = FALSE;
//    if ([open runModal] != NSFileHandlingPanelOKButton)
//        return nil;

    static const char sourcektd[] = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/sourcekitd.framework/sourcekitd";
//    NSString *sourcektd = [[NSBundle mainBundle] pathForResource:@"sourcekitd" ofType:@"framework"];
    if (!(handle = dlopen(sourcektd, RTLD_NOW))) {
        NSLog(@"dlopen of sourcekitd for highlighting failed at: %s - %s", sourcektd, dlerror());
        return self;
    }

    sourcekitd_initialize = dlsym(handle, "sourcekitd_initialize");
    sourcekitd_uid_get_from_cstr = dlsym(handle, "sourcekitd_uid_get_from_cstr");
    sourcekitd_request_dictionary_create = dlsym(handle, "sourcekitd_request_dictionary_create");
    sourcekitd_request_dictionary_set_uid = dlsym(handle, "sourcekitd_request_dictionary_set_uid");
    sourcekitd_request_dictionary_set_string = dlsym(handle, "sourcekitd_request_dictionary_set_string");
    sourcekitd_request_dictionary_set_int64 = dlsym(handle, "sourcekitd_request_dictionary_set_int64");
    sourcekitd_send_request_sync = dlsym(handle, "sourcekitd_send_request_sync");
    sourcekitd_request_release = dlsym(handle, "sourcekitd_request_release");
    sourcekitd_send_request_sync = dlsym(handle, "sourcekitd_send_request_sync");
    sourcekitd_response_is_error = dlsym(handle, "sourcekitd_response_is_error");
    sourcekitd_response_description_dump_filedesc = dlsym(handle, "sourcekitd_response_description_dump_filedesc");
    sourcekitd_response_dispose = dlsym(handle, "sourcekitd_response_dispose");

    sourcekitd_response_get_value = dlsym(handle, "sourcekitd_response_get_value");
    sourcekitd_variant_array_apply = dlsym(handle, "sourcekitd_variant_array_apply");
    sourcekitd_variant_array_apply_f = dlsym(handle, "sourcekitd_variant_array_apply_f");
    sourcekitd_variant_dictionary_get_uid = dlsym(handle, "sourcekitd_variant_dictionary_get_uid");
    sourcekitd_variant_dictionary_get_value = dlsym(handle, "sourcekitd_variant_dictionary_get_value");
    sourcekitd_uid_get_string_ptr = dlsym(handle, "sourcekitd_uid_get_string_ptr");
    sourcekitd_variant_dictionary_get_int64 = dlsym(handle, "sourcekitd_variant_dictionary_get_int64");
    sourcekitd_variant_array_get_count = dlsym(handle, "sourcekitd_variant_array_get_count");
    sourcekitd_variant_array_get_value = dlsym(handle, "sourcekitd_variant_array_get_value");

    sourcekitd_initialize();

    requestID = sourcekitd_uid_get_from_cstr("key.request");
    editorOpenID = sourcekitd_uid_get_from_cstr("source.request.editor.open");
    nameID = sourcekitd_uid_get_from_cstr("key.name");
    sourceFileID = sourcekitd_uid_get_from_cstr("key.sourcefile");
    enableMapID = sourcekitd_uid_get_from_cstr("key.enablesyntaxmap");
    enableSubID = sourcekitd_uid_get_from_cstr("key.enablesubstructure");
    syntaxOnlyID = sourcekitd_uid_get_from_cstr("key.syntactic_only");

    syntaxID = sourcekitd_uid_get_from_cstr("key.syntaxmap");
    kindID = sourcekitd_uid_get_from_cstr("key.kind");
    offsetID = sourcekitd_uid_get_from_cstr("key.offset");
    lengthID = sourcekitd_uid_get_from_cstr("key.length");
    editorCloseID = sourcekitd_uid_get_from_cstr("source.request.editor.close");

    return self;
}

- (NSString *)getUUIDStringDict:(sourcekitd_variant_t)dict key:(sourcekitd_uid_t)key {
    sourcekitd_uid_t uuid = sourcekitd_variant_dictionary_get_uid(dict, key);
    return [NSString stringWithUTF8String:sourcekitd_uid_get_string_ptr(uuid)?:"?UUID"];
}

- (NSString *)formatFile:(NSString *)path {
    if (!handle)
        return nil;

    sourcekitd_object_t req = sourcekitd_request_dictionary_create(NULL, NULL, 0);
    const char *filePath = path.UTF8String;

    sourcekitd_request_dictionary_set_uid(req, requestID, editorOpenID);
    sourcekitd_request_dictionary_set_string(req, nameID, filePath);
    sourcekitd_request_dictionary_set_string(req, sourceFileID, filePath);
    sourcekitd_request_dictionary_set_int64(req, enableMapID, 1);
    sourcekitd_request_dictionary_set_int64(req, enableSubID, 0);
    sourcekitd_request_dictionary_set_int64(req, syntaxOnlyID, 1);

    sourcekitd_response_t resp = sourcekitd_send_request_sync(req);
    if (sourcekitd_response_is_error(resp)) {
        NSLog(@"soucekitd returns error reponse in highlighting %s, run from console", filePath);
        sourcekitd_response_description_dump_filedesc(resp, STDERR_FILENO);
        handle = NULL;
        return nil;
    }

    sourcekitd_variant_t dict = sourcekitd_response_get_value(resp);
    sourcekitd_variant_t map = sourcekitd_variant_dictionary_get_value(dict, syntaxID);

    NSMutableData *source = [NSMutableData dataWithContentsOfFile:path];
    NSMutableString *output = [NSMutableString new];
    size_t ptr = 0;

    [source appendBytes:&ptr length:sizeof ptr];

    for (size_t i=0, count = sourcekitd_variant_array_get_count(map); i<count; i++) {
        sourcekitd_variant_t dict = sourcekitd_variant_array_get_value(map, i);
        NSString *kind = [self getUUIDStringDict:dict key:self->kindID];
        int64_t offset = self->sourcekitd_variant_dictionary_get_int64(dict, self->offsetID);
        int64_t length = self->sourcekitd_variant_dictionary_get_int64(dict, self->lengthID);

        if (ptr < offset)
            ptr += [self spanFor:source.bytes + ptr length:offset - ptr rule:@"between" onto:output];

        ptr += [self spanFor:source.bytes + ptr length:length rule:kind.pathExtension onto:output];
    }

    [output appendFormat:@"%@", [NSString stringWithUTF8String:source.bytes + ptr]];

    sourcekitd_request_release(req);
    sourcekitd_response_dispose(resp);

    req = sourcekitd_request_dictionary_create(NULL, NULL, 0);
    sourcekitd_request_dictionary_set_uid(req, requestID, editorCloseID);
    sourcekitd_request_dictionary_set_string(req, nameID, filePath);
    sourcekitd_request_dictionary_set_string(req, sourceFileID, filePath);

    sourcekitd_response_dispose(sourcekitd_send_request_sync(req));
    sourcekitd_request_release(req);

    return output;
}

- (size_t)spanFor:(const void *)bytes length:(size_t)length rule:(NSString *)rule onto:(NSMutableString *)output {
    NSData *data = [NSData dataWithBytesNoCopy:(void *)bytes length:length freeWhenDone:NO];
    NSString *text = [self htmlEscape:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];

    if ([rule isEqualToString:@"url"])
        text = [NSString stringWithFormat:@"<a href=\"%@\">%@</a>", text, text];

    [output appendFormat:@"<span class=%@>%@</span>", rule, text];
    return length;
}

- (NSString *)htmlEscape:(NSString *)text;
{
    return [[text stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"]
            stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
}

@end
