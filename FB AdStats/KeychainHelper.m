// KeychainHelper.m
#import "KeychainHelper.h"
#import "Constants.h"
#import <Security/Security.h>

@implementation KeychainHelper

+ (NSDictionary *)baseQueryForKey:(NSString *)key {
    return @{
        (__bridge id)kSecClass       : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService : kKeychainService,
        (__bridge id)kSecAttrAccount : key
    };
}

+ (BOOL)saveValue:(NSString *)value forKey:(NSString *)key {
    if (!value || !key) return NO;

    // Always delete first to avoid errSecDuplicateItem
    [self deleteValueForKey:key];

    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableDictionary *query = [[self baseQueryForKey:key] mutableCopy];
    query[(__bridge id)kSecValueData]      = data;
    // Accessible only when device is unlocked; excluded from iCloud backup
    query[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;

    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    if (status != errSecSuccess) {
        NSLog(@"[Keychain] Save failed for key '%@' — OSStatus: %d", key, (int)status);
    }
    return status == errSecSuccess;
}

+ (NSString *)loadValueForKey:(NSString *)key {
    if (!key) return nil;

    NSMutableDictionary *query = [[self baseQueryForKey:key] mutableCopy];
    query[(__bridge id)kSecReturnData]  = @YES;
    query[(__bridge id)kSecMatchLimit]  = (__bridge id)kSecMatchLimitOne;

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);

    if (status == errSecSuccess && result) {
        NSData *data = (__bridge_transfer NSData *)result;
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }

    if (status != errSecItemNotFound) {
        NSLog(@"[Keychain] Load failed for key '%@' — OSStatus: %d", key, (int)status);
    }
    return nil;
}

+ (BOOL)deleteValueForKey:(NSString *)key {
    if (!key) return NO;
    NSDictionary *query = [self baseQueryForKey:key];
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    return status == errSecSuccess || status == errSecItemNotFound;
}

+ (BOOL)hasValueForKey:(NSString *)key {
    return [self loadValueForKey:key] != nil;
}

@end
