// KeychainHelper.h
#import <Foundation/Foundation.h>

@interface KeychainHelper : NSObject

/// Save or overwrite a string value in the Keychain
+ (BOOL)saveValue:(NSString *)value forKey:(NSString *)key;

/// Retrieve a string value from the Keychain; returns nil if not found
+ (nullable NSString *)loadValueForKey:(NSString *)key;

/// Delete a Keychain item; returns YES if deleted or was already absent
+ (BOOL)deleteValueForKey:(NSString *)key;

/// Returns YES if a value exists for the given key
+ (BOOL)hasValueForKey:(NSString *)key;

@end
