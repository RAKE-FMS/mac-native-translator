#import "KeyboardServicesBridge.h"
#import <dlfcn.h>
#import <sqlite3.h>

@protocol MTTextReplacementEntry <NSObject>
- (void)setShortcut:(NSString *)shortcut;
- (void)setPhrase:(NSString *)phrase;
- (void)setNeedsSaveToCloud:(BOOL)value;
@end

@protocol MTTextReplacementStore <NSObject>
- (void)addEntries:(NSArray *)entries
     removeEntries:(NSArray *)removedEntries
withCompletionHandler:(void (^)(id _Nullable error))completion;
@end

BOOL MTAddDictionaryEntry(NSString *reading, NSString *phrase, void (^completion)(BOOL))
{
    static void *framework;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        framework = dlopen("/System/Library/PrivateFrameworks/KeyboardServices.framework/KeyboardServices",
                           RTLD_LAZY | RTLD_LOCAL);
    });
    if (!framework) {
        return NO;
    }

    Class entryClass = NSClassFromString(@"_KSTextReplacementEntry");
    Class storeClass = NSClassFromString(@"_KSTextReplacementClientStore");
    SEL addEntries = @selector(addEntries:removeEntries:withCompletionHandler:);
    if (![entryClass instancesRespondToSelector:@selector(setShortcut:)] ||
        ![entryClass instancesRespondToSelector:@selector(setPhrase:)] ||
        ![entryClass instancesRespondToSelector:@selector(setNeedsSaveToCloud:)] ||
        ![storeClass instancesRespondToSelector:addEntries]) {
        return NO;
    }

    BOOL requestedWrite = NO;
    @autoreleasepool {
        @try {
            id<MTTextReplacementEntry> entry = [[entryClass alloc] init];
            static id<MTTextReplacementStore> store;
            if (!store) {
                store = [[storeClass alloc] init];
            }
            if (!entry || !store) {
                return NO;
            }

            [entry setShortcut:reading];
            [entry setPhrase:phrase];
            [entry setNeedsSaveToCloud:YES];

            requestedWrite = YES;
            [store addEntries:@[entry] removeEntries:@[] withCompletionHandler:^(id error) {
                NSError *serviceError = [error isKindOfClass:NSError.class] ? error : nil;
                // KeyboardServices also reports successful writes with error-domain code zero.
                BOOL accepted = !error || (serviceError.code == 0 &&
                    [serviceError.domain isEqualToString:@"KSTextReplacementErrorDomain"]);
                completion(accepted);
            }];
        } @catch (NSException *exception) {
            if (requestedWrite) {
                completion(NO);
            }
        }
    }
    return requestedWrite;
}

BOOL MTDictionaryContainsEntry(NSString *reading, NSString *phrase)
{
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/KeyboardServices/TextReplacements.db"];
    sqlite3 *database = NULL;
    sqlite3_stmt *statement = NULL;
    const char *query =
        "SELECT 1 FROM ZTEXTREPLACEMENTENTRY "
        "WHERE ZSHORTCUT = ?1 AND ZPHRASE = ?2 AND COALESCE(ZWASDELETED, 0) = 0 LIMIT 1";
    BOOL found =
        sqlite3_open_v2(path.fileSystemRepresentation, &database, SQLITE_OPEN_READONLY, NULL) == SQLITE_OK &&
        sqlite3_prepare_v2(database, query, -1, &statement, NULL) == SQLITE_OK &&
        sqlite3_bind_text64(statement, 1, reading.UTF8String,
                            [reading lengthOfBytesUsingEncoding:NSUTF8StringEncoding], SQLITE_TRANSIENT, SQLITE_UTF8) == SQLITE_OK &&
        sqlite3_bind_text64(statement, 2, phrase.UTF8String,
                            [phrase lengthOfBytesUsingEncoding:NSUTF8StringEncoding], SQLITE_TRANSIENT, SQLITE_UTF8) == SQLITE_OK &&
        sqlite3_step(statement) == SQLITE_ROW;
    sqlite3_finalize(statement);
    sqlite3_close(database);
    return found;
}
