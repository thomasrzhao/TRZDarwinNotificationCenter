//
//  TRZDarwinNotificationCenter.h
//
//
//  Created by Thomas Zhao on 4/19/15.
//
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

/**
 * A protocol that represents the capabilities provided by a notification center.
 * This protocol is conformed to by both `TRZDarwinNotificationCenter` and the wrapper object returned by centerWithPrefix:.
 * Refer to `TRZDarwinNotificationCenter` for information regarding these methods.
 */
@protocol TRZNotificationCenter <NSObject>

- (id<NSObject>)addObserverForName:(NSString*)name queue:(nullable NSOperationQueue *)queue usingBlock:(void (^)(NSNotification *))block;

- (void)addObserver:(id)notificationObserver selector:(SEL)notificationSelector name:(NSString *)notificationName;

- (void)removeObserver:(id)notificationObserver;

- (void)removeObserver:(id)notificationObserver name:(nullable NSString *)notificationName;

- (void)postNotification:(NSNotification *)notification;

- (void)postNotificationName:(NSString *)notificationName;

@end

/**
 *  `TRZDarwinNotificationCenter` is a nearly API-compatible version of NSNotificationCenter that delivers and receives system-wide Darwin notifications.
 *
 *  Because the Darwin notification center does not support specifying an object or passing a userInfo object to the receiver, those parameters have been removed.
 *
 *  @warning As Darwin notification names are shared throughout the system, it's important to use a reverse-DNS naming system to avoid collisions. This differs from the standard naming scheme for NSNotifications, so please be cautious.
 */
@interface TRZDarwinNotificationCenter : NSObject<TRZNotificationCenter>

/**
 *  Returns the default notification center, representing the system-wide Darwin notification center.
 *
 *  @return The default Darwin notification center.
 */
+ (TRZDarwinNotificationCenter *)defaultCenter;

/**
 * Returns a wrapper around the default Darwin notification center that automatically prefixes notification names with the specified string.
 *
 * Therefore, you can do the following:
 * @code id<TRZNotificationCenter> notificationCenter = [TRZDarwinNotificationCenter darwinNotificationCenterWithPrefix:@"com.thomasrzhao"];
 [notificationCenter postNotificationName:@"TRZDemoNotification"];
 * @endcode
 * and have that be equivalent to:
 * @code TRZDarwinNotificationCenter* notificationCenter = [TRZDarwinNotificationCenter defaultCenter];
 [notificationCenter postNotificationName:@"com.thomasrzhao.TRZDemoNotification"];
 * @endcode
 * Note that if the prefix has trailing or leading periods, they will be removed automatically.
 *
 * @param prefix String to use as the prefix.
 *
 * @return A wrapper around the default Darwin notification center that prefixes the all notification names.
 */
+ (id<TRZNotificationCenter>)centerWithPrefix:(NSString*)prefix;

/**
 *  Adds an entry to the receiver’s dispatch table with a notification name, queue and a block to add to the queue.
 *
 *  @param name  The name of the notification for which to register the observer; that is, only notifications with this name are used to add the block to the operation queue.
 *  @param queue The operation queue to which _block_ should be added.
 *  @param block The block to be executed when the notification is received. The block is copied by the notification center and (the copy) held until the observer registration is removed. The block takes one argument, the notification.
 *
 *  @return An opaque object to act as the observer. You must invoke removeObserver: or removeObserver:name:object: before any object specified by addObserverForName:queue:usingBlock: is deallocated.
 */
- (id<NSObject>)addObserverForName:(NSString*)name queue:(nullable NSOperationQueue *)queue usingBlock:(void (^)(NSNotification *))block;

/**
 *  Adds an entry to the receiver’s dispatch table with an observer, a notification selector and notification name. The notification will be delivered on the main queue.
 *
 *  @param notificationObserver Object registering as an observer. This value must not be `nil`.
 *  @param notificationSelector Selector that specifies the message the receiver sends _notificationObserver_ to notify it of the notification posting. The method specified by _notificationSelector_ must have one and only one argument (an instance of `NSNotification`).
 *  @param notificationName     The name of the notification for which to register the observer; that is, only notifications with this name are delivered to the observer. This value must not be `nil`.
 */
- (void)addObserver:(id)notificationObserver selector:(SEL)notificationSelector name:(NSString *)notificationName;

/**
 *  Removes all the entries specifying a given observer from the receiver’s dispatch table.
 *
 *  @param notificationObserver The observer to remove. Must not be `nil`.
 */
- (void)removeObserver:(id)notificationObserver;

/**
 *  Removes matching entries from the receiver’s dispatch table.
 *
 *  @param notificationObserver Observer to remove from the dispatch table. Specify an observer to remove only entries for this observer. Must not be `nil`, or message will have no effect.
 *  @param notificationName     Name of the notification to remove from dispatch table. Specify a notification name to remove only entries that specify this notification name. When `nil`, the receiver does not use notification names as criteria for removal.
 */
- (void)removeObserver:(id)notificationObserver name:(nullable NSString *)notificationName;

/**
 *  Posts a given notification to the receiver. The `userInfo` and `object` properties of the notification are ignored.
 *
 *  @param notification The notification to post. This value must not be `nil`.
 */
- (void)postNotification:(NSNotification *)notification;

/**
 *  Creates a notification with a given name and posts it to the receiver.
 *
 *  @param notificationName The name of the notification.
 */
- (void)postNotificationName:(NSString *)notificationName;

@end

NS_ASSUME_NONNULL_END
