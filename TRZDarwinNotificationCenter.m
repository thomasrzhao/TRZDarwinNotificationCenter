//
//  TRZDarwinNotificationCenter.m
//
//
//  Created by Thomas Zhao on 4/19/15.
//
//

#import "TRZDarwinNotificationCenter.h"
#import <CoreFoundation/CFNotificationCenter.h>

@interface TRZNotificationCenterPrefixWrapper<TRZNotificationCenter> : NSObject
@property (nonatomic, strong, readonly) id<TRZNotificationCenter> notificationCenter;
@property (nonatomic, strong, readonly) NSString* prefix;
- (nonnull instancetype)initWithNotificationCenter:(nonnull id<TRZNotificationCenter>)notificationCenter prefix:(nonnull NSString*)prefix;
@end

@interface TRZDarwinNotificationCenter ()
@property (nonatomic, assign) CFNotificationCenterRef darwinNotificationCenter;
@property (nonatomic, strong) NSMutableDictionary* registeredNotifications;
@property (nonatomic, strong) NSMutableSet* retainedObserverSet;
@end

@implementation TRZDarwinNotificationCenter

#ifdef DEBUG
#define CHECK_NOTIFICATION_NAME(name) do { \
if([name componentsSeparatedByString:@"."].count < 3) { \
NSLog(@"warning: Darwin notification names should be in reverse-DNS style to avoid system-wide collisions. \"%@\" does not appear to fit this criteria.", name); \
} } while (0)
#else
#define CHECK_NOTIFICATION_NAME(name)
#endif

- (instancetype)init
{
    self = [super init];
    if(self) {
        self.darwinNotificationCenter = CFNotificationCenterGetDarwinNotifyCenter();
        self.registeredNotifications = [[NSMutableDictionary alloc] init];
        self.retainedObserverSet = [[NSMutableSet alloc] init];
    }
    return self;
}

+ (TRZDarwinNotificationCenter*)defaultCenter {
    static TRZDarwinNotificationCenter* shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

+ (id<TRZNotificationCenter>)centerWithPrefix:(NSString*)prefix {
    id<TRZNotificationCenter> darwinCenter = (id<TRZNotificationCenter>)[TRZDarwinNotificationCenter defaultCenter];
    
    TRZNotificationCenterPrefixWrapper* wrapper = [[TRZNotificationCenterPrefixWrapper alloc] initWithNotificationCenter:darwinCenter prefix:prefix];
    
    return (id<TRZNotificationCenter>)wrapper;
}

- (id<NSObject>)addObserverForName:(NSString*)name queue:(NSOperationQueue *)queue usingBlock:(void (^)(NSNotification *))block {
    CHECK_NOTIFICATION_NAME(name);
    
    queue = (queue) ? queue : [NSOperationQueue mainQueue];
    
    NSObject* object = [[NSObject alloc] init];
    [self tz_addBlock:^{
        void (^executionBlock)(void) = ^void(void) {
            block([NSNotification notificationWithName:name object:nil]);
        };
        [queue addOperationWithBlock:executionBlock];
    } forObserver:object name:name retainObserver:true];
    return object;
}

- (void)addObserver:(id)notificationObserver selector:(SEL)notificationSelector name:(NSString *)notificationName {
    CHECK_NOTIFICATION_NAME(notificationName);
    
    __weak id observer = notificationObserver;
    [self tz_addBlock:^{
        NSInvocationOperation* operation = [[NSInvocationOperation alloc] initWithTarget:observer selector:notificationSelector object:[NSNotification notificationWithName:notificationName object:nil]];
        [[NSOperationQueue mainQueue] addOperation:operation];
    } forObserver:notificationObserver name:notificationName retainObserver:false];
}

- (void)tz_addBlock:(void (^)(void))block forObserver:(id)observer name:(NSString *)notificationName retainObserver:(BOOL)retainObserver {
    @synchronized(self.registeredNotifications) {
        NSMapTable* observerActionMap = self.registeredNotifications[notificationName];
        
        if(!observerActionMap.count) {
            CFNotificationCenterAddObserver(self.darwinNotificationCenter, (__bridge const void *)(self), &trz_darwin_notification_center_observed_notification, (__bridge CFStringRef)notificationName, NULL, 0);
            observerActionMap = [NSMapTable mapTableWithKeyOptions:NSMapTableWeakMemory|NSMapTableObjectPointerPersonality valueOptions:NSMapTableStrongMemory];
            self.registeredNotifications[notificationName] = observerActionMap;
        }
        
        NSMutableArray* actions = [observerActionMap objectForKey:observer];
        if(!actions) {
            actions = [NSMutableArray arrayWithObject:block];
            [observerActionMap setObject:actions forKey:observer];
        } else {
            [actions addObject:block];
        }
        
        if(retainObserver) {
            [self.retainedObserverSet addObject:observer];
        }
    }
}

- (void)removeObserver:(id)notificationObserver {
    if(!notificationObserver) return;
    
    @synchronized(self.registeredNotifications) {
        for(NSString* notificationName in [self.registeredNotifications allKeys]) {
            [self tz_removeObserver:notificationObserver name:notificationName];
        }
    }
}

- (void)removeObserver:(id)notificationObserver name:(nullable NSString *)notificationName {
    if(!notificationObserver) return;
    if(!notificationName) {
        [self removeObserver:notificationObserver];
        return;
    }
    
    [self tz_removeObserver:notificationObserver name:notificationName];
}

- (void)tz_removeObserver:(id)notificationObserver name:(nullable NSString *)notificationName {
    @synchronized(self.registeredNotifications) {
        NSMapTable* observerActionMap = self.registeredNotifications[notificationName];
        [observerActionMap removeObjectForKey:notificationObserver];
        
        if(!observerActionMap.count) {
            [self.registeredNotifications removeObjectForKey:notificationName];
            CFNotificationCenterRemoveObserver(self.darwinNotificationCenter, (__bridge const void *)(self), (__bridge CFStringRef)notificationName, nil);
        }
        
        [self.retainedObserverSet removeObject:notificationObserver];
    }
}

- (void)postNotification:(NSNotification *)notification {
    [self postNotificationName:notification.name];
}

- (void)postNotificationName:(NSString*)notificationName {
    CHECK_NOTIFICATION_NAME(notificationName);
    
    CFNotificationCenterPostNotification(self.darwinNotificationCenter, (__bridge CFStringRef)notificationName, NULL, NULL, true);
}

- (void)notifyNotificationName:(NSString*)notificationName {
    @synchronized(self.registeredNotifications) {
        NSMapTable* observersForName = self.registeredNotifications[notificationName];
        
        for(id observer in observersForName) {
            NSMutableArray* actions = (NSMutableArray*)[observersForName objectForKey:observer];
            for(void (^block)(void) in actions) {
                block();
            }
        }
    }
}

- (void)dealloc {
    CFNotificationCenterRemoveEveryObserver(self.darwinNotificationCenter, (__bridge const void *)(self));
}

void trz_darwin_notification_center_observed_notification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    TRZDarwinNotificationCenter* notificationCenter = (__bridge TRZDarwinNotificationCenter*)observer;
    [notificationCenter notifyNotificationName:(__bridge NSString *)(name)];
}
@end

@implementation TRZNotificationCenterPrefixWrapper
- (instancetype)initWithNotificationCenter:(id<TRZNotificationCenter>)notificationCenter prefix:(NSString*)prefix {
    self = [super init];
    if(self) {
        _notificationCenter = notificationCenter;
        _prefix = [prefix stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"."]];
    }
    return self;
}

- (id<NSObject>)addObserverForName:(NSString*)name queue:(nullable NSOperationQueue *)queue usingBlock:(void (^)(NSNotification *))block {
    name = [self prefixedName:name];
    return [self.notificationCenter addObserverForName:name queue:queue usingBlock:block];
}

- (void)addObserver:(id)notificationObserver selector:(SEL)notificationSelector name:(NSString *)notificationName {
    notificationName = [self prefixedName:notificationName];
    return [self.notificationCenter addObserver:notificationObserver selector:notificationSelector name:notificationName];
}

- (void)removeObserver:(id)notificationObserver {
    [self.notificationCenter removeObserver:notificationObserver];
}

- (void)removeObserver:(id)notificationObserver name:(nullable NSString *)notificationName {
    notificationName = [self prefixedName:notificationName];
    [self.notificationCenter removeObserver:notificationObserver name:notificationName];
}

- (void)postNotification:(NSNotification *)notification {
    NSNotification* prefixedNotification = [NSNotification notificationWithName:[self prefixedName:notification.name] object:nil];
    [self.notificationCenter postNotification:prefixedNotification];
}

- (void)postNotificationName:(NSString *)notificationName {
    notificationName = [self prefixedName:notificationName];
    [self.notificationCenter postNotificationName:notificationName];
}


- (NSString*)prefixedName:(NSString*)name {
#ifdef DEBUG
    if([name rangeOfString:self.prefix].location == 0) {
        NSLog(@"warning: Notification name \"%@\" already contains prefix \"%@\", forming the doubly-prefixed name \"%@.%@\" This is probably not what you expected.", name, self.prefix, self.prefix, name);
    }
#endif
    return [NSString stringWithFormat:@"%@.%@", self.prefix, name];
}

@end
