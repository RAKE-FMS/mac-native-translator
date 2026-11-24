#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Call on the main thread. Returns NO if no write was attempted.
BOOL MTAddDictionaryEntry(NSString *reading, NSString *phrase, void (^completion)(BOOL accepted));

/// Confirms that the matching entry is present in the local dictionary.
BOOL MTDictionaryContainsEntry(NSString *reading, NSString *phrase);

NS_ASSUME_NONNULL_END
