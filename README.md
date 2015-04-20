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

## Common Pitfalls

 - When using the block-based API, it is very important to retain the opaque handle object, probably by storing it in an instance variable. Because TRZDarwinNotificationCenter uses weak references to store all the observers, calling `addObserverForName:queue:usingBlock:` without saving the return value will not correctly register for the notification and nothing will happen if/when the notification is actually fired. It will also most likely result in a memory leak, as there is no longer any way to remove this observer. This class is a bit less forgiving than NSNotificationCenter in this regard.

 - Since Darwin notifications do not support the sender object and userInfo values in an NSNotification object, those values are ignored when using the postNotification: method.

