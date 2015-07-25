# TRZDarwinNotificationCenter

This is a drop-in replacement for NSNotificationCenter that uses the Darwin notification system to communicate between processes. You can use this to, for example, communicate between a WatchKit extension and its running host app to keep things in sync.

The API closely resembles that of NSNotificationCenter, so it's easy to use. You can use it from both Swift and Objective-C.

## Posting Notifications

Posting notifications works exactly like NSNotificationCenter, except that you can't specify a userInfo or object parameter, as those aren't supported by the Darwin notification center. 

### Swift

```swift
TRZDarwinNotificationCenter.defaultCenter().postNotificationName("com.thomasrzhao.TRZDemoNotification")
```

### Objective-C

```objective-c
[[TRZDarwinNotificationCenter defaultCenter] postNotificationName:@"com.thomasrzhao.TRZDemoNotification"];
```

Since Darwin notifications are broadcast system-wide, the reverse-DNS naming scheme should be used to prevent conflicts.


## Observing Notifications

You can observe notifications with either the traditional target-action pattern, or with the newer block-based syntax.

### Swift

```swift
TRZDarwinNotificationCenter.defaultCenter().addObserver(self, selector:Selector("receivedNotification:"), name:"com.thomasrzhao.TRZDemoNotification")
```

or

```swift
self.notificationHandle = TRZDarwinNotificationCenter.defaultCenter().addObserverForName("com.thomasrzhao.TRZDemoNotification", queue: nil) { (notification) -> Void in
    //do something here
}
```

### Objective-C


```objective-c
[[TRZDarwinNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedNotification:) name:@"com.thomasrzhao.TRZDemoNotification"];
```

or

```objective-c
self.notificationHandle = [[TRZDarwinNotificationCenter defaultCenter] addObserverForName:@"com.thomasrzhao.TRZDemoNotification" queue:nil usingBlock:^(NSNotification* notification) {
    //do something here
}];
```


## Unregistering Notifications

As with NSNotificationCenter, it's important to remove observers to avoid memory errors. To do so, just call removeObserver with the same observer and name objects you passed in to addObserver. If using the block-based API, pass in the opaque handle object returned from `addObserverForName:queue:usingBlock:`. You can do this in `dealloc` in Objective-C or in `deinit` in Swift.


### Swift

```swift
TRZDarwinNotificationCenter.defaultCenter().removeObserver(self, name:"com.thomasrzhao.TRZDemoNotification")
```

or

```swift
TRZDarwinNotificationCenter.defaultCenter().removeObserver(self.notificationHandle, name:"com.thomasrzhao.TRZDemoNotification")
```

### Objective-C

```objective-c
[[TRZDarwinNotificationCenter defaultCenter] removeObserver:self name:@"com.thomasrzhao.TRZDemoNotification"];
```

or

```objective-c
[[TRZDarwinNotificationCenter defaultCenter] removeObserver:self.notificationHandle name:@"com.thomasrzhao.TRZDemoNotification"];
```


## Automatic Prefixing

As an alternative to prefixing every notification name string with a reverse-DNS prefix, you can use `centerWithPrefix:` to create a wrapper object around the default Darwin center that automatically appends a prefix to any notification name passed in.

### Swift

```swift
let notificationCenter = TRZDarwinNotificationCenter.centerWithPrefix("com.thomasrzhao");
notificationCenter.postNotificationName("TRZDemoNotification");
```

### Objective-C

```objective-c
id<TRZNotificationCenter> notificationCenter = [TRZDarwinNotificationCenter centerWithPrefix:@"com.thomasrzhao"];
[notificationCenter postNotificationName:@"TRZDemoNotification"];
```


## Common Pitfalls

 - When using the block-based API, it is *very* important to call `removeObserver:name:` with the returned handle object when the notification's action is no longer needed. If the handle object is not removed as an observer, the block will not be deallocated and you will have a memory leak.

 - Since Darwin notifications do not support the sender object and userInfo values in an NSNotification object, those values are ignored when using the `postNotification:` method.

 - The wrapper object returned from `centerWithPrefix:` still uses `defaultCenter` under the hood. Calling `centerWithPrefix:` multiple times will result in multiple wrapper object instances, but since they simply wrap the `defaultCenter`, they will all behave identically.
 
    For example, in the following code snippet:
    ```swift
    let center1 = TRZDarwinNotificationCenter.centerWithPrefix("com.thomasrzhao");
    let center2 = TRZDarwinNotificationCenter.centerWithPrefix("com.thomasrzhao");
    center1.addObserverForName("TRZDemoNotification", ...);
    center2.postNotificationName("TRZDemoNotification");
    ```

    The observer attached to `center1` will receive the notification posted from `center2` because they use the same prefix. In fact, an observer attached to the `defaultCenter` could also have received the notification if it were added for `"com.thomasrzhao.TRZDemoNotification"`.
    
    Also, the NSNotification object sent to the observer will have the full, prefixed name for its name property.
    
 - You should probably not subclass or call `init` directly. There is only one Darwin notification center present throughout the OS, so having multiple instances of this class is probably more confusion than it's worth. If you do decide to create multiple instances of TRZDarwinNotificationCenter, each instance will behave independently of one another, meaning an observer attached to one instance will not be called if a notification is posted from another.