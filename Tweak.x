#import <UIKit/UIKit.h>

static void cleanKeychainExceptSaved() {
    // تحديد العناصر المستثناة التي لا يجب حذفها (الموجودة في الصور)
    // Service: com.codebysms مع الحسابات userIDKey و accessTokenKey
    
    NSArray *classesToMatch = @[
        (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecClassInternetPassword,
        (__bridge id)kSecClassCertificate,
        (__bridge id)kSecClassKey,
        (__bridge id)kSecClassIdentity
    ];
    
    for (id secClass in classesToMatch) {
        // استعلام لجلب جميع عناصر الـ Keychain الخاصة بالتطبيق
        NSMutableDictionary *query = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                       secClass, (__bridge id)kSecClass,
                                       (__bridge id)kSecMatchLimitAll, (__bridge id)kSecMatchLimit,
                                       (__bridge id)kCFBooleanTrue, (__bridge id)kSecReturnAttributes,
                                       nil];
        
        CFArrayRef result = NULL;
        if (SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result) == errSecSuccess) {
            NSArray *items = (__bridge_transfer NSArray *)result;
            for (NSDictionary *item in items) {
                NSString *service = item[(__bridge id)kSecAttrService];
                NSString *account = item[(__bridge id)kSecAttrAccount];
                
                // التحقق هل العنصر يتبع لـ com.codebysms وأحد مفاتيح الحساب المستثناة؟
                BOOL isProtected = [service isEqualToString:@"com.codebysms"] && 
                                   ([account isEqualToString:@"userIDKey"] || [account isEqualToString:@"accessTokenKey"]);
                
                // إذا لم يكن من ضمن المستثناءات، يتم حذفه فوراً
                if (!isProtected) {
                    NSMutableDictionary *delQuery = [NSMutableDictionary dictionaryWithDictionary:item];
                    [delQuery setObject:secClass forKey:(__bridge id)kSecClass];
                    SecItemDelete((__bridge CFDictionaryRef)delQuery);
                }
            }
        }
    }
}

// تنفيذ عملية التنظيف فور تشغيل التطبيق وإقلاعه
%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        cleanKeychainExceptSaved();
    });
}
