//
//    ReaderThumbCache.m
//    Reader v2.8.6
//
//    Created by Julius Oklamcak on 2011-09-01.
//    Copyright © 2011-2015 Julius Oklamcak. All rights reserved.
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy
//    of this software and associated documentation files (the "Software"), to deal
//    in the Software without restriction, including without limitation the rights to
//    use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
//    of the Software, and to permit persons to whom the Software is furnished to
//    do so, subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//    CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "ReaderThumbCache.h"
#import "ReaderThumbQueue.h"
#import "ReaderThumbFetch.h"
#import "ReaderThumbView.h"

@implementation ReaderThumbCache
{
    NSCache *thumbCache;
}

#pragma mark - Constants

#define CACHE_SIZE 2097152

#pragma mark - ReaderThumbCache class methods

+ (ReaderThumbCache *)sharedInstance
{
    static dispatch_once_t predicate = 0;

    static ReaderThumbCache *object = nil; // Object

    dispatch_once(&predicate, ^{ object = [self new]; });

    return object; // ReaderThumbCache singleton
}

+ (NSString *)appCachesPath
{
    static dispatch_once_t predicate = 0;

    static NSString *theCachesPath = nil; // Application caches path string

    dispatch_once(&predicate, // Save a copy of the application caches path the first time it is needed
    ^{
        NSArray *cachesPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);

        theCachesPath = [cachesPaths[0] copy]; // Keep a copy for later abusage
    });

    return theCachesPath;
}

+ (NSString *)thumbCachePathForGUID:(NSString *)guid
{
    NSString *cachesPath = [ReaderThumbCache appCachesPath]; // Caches path

    return [cachesPath stringByAppendingPathComponent:guid]; // Append GUID
}

+ (void)createThumbCacheWithGUID:(NSString *)guid
{
    NSFileManager *fileManager = [NSFileManager new]; // File manager instance

    NSString *cachePath = [ReaderThumbCache thumbCachePathForGUID:guid]; // Thumb cache path

    [fileManager createDirectoryAtPath:cachePath withIntermediateDirectories:NO attributes:nil error:NULL];
}

+ (void)removeThumbCacheWithGUID:(NSString *)guid
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0),
    ^{
        NSFileManager *fileManager = [NSFileManager new]; // File manager instance

        NSString *cachePath = [ReaderThumbCache thumbCachePathForGUID:guid]; // Thumb cache path

        [fileManager removeItemAtPath:cachePath error:NULL]; // Remove thumb cache directory
    });
}

+ (void)touchThumbCacheWithGUID:(NSString *)guid
{
    NSFileManager *fileManager = [NSFileManager new]; // File manager instance

    NSString *cachePath = [ReaderThumbCache thumbCachePathForGUID:guid]; // Thumb cache path

    NSDictionary *attributes = @{NSFileModificationDate: [NSDate date]};

    [fileManager setAttributes:attributes ofItemAtPath:cachePath error:NULL]; // New modification date
}

+ (void)purgeThumbCachesOlderThan:(NSTimeInterval)age
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0),
    ^{
        NSDate *now = [NSDate date]; // Right about now time

        NSString *cachesPath = [ReaderThumbCache appCachesPath]; // Caches path

        NSFileManager *fileManager = [NSFileManager new]; // File manager instance

        NSArray *cachesList = [fileManager contentsOfDirectoryAtPath:cachesPath error:NULL];

        if (cachesList != nil) // Process caches directory contents
        {
            for (NSString *cacheName in cachesList) // Enumerate directory contents
            {
                if (cacheName.length == 36) // This is a very hacky cache ident kludge
                {
                    NSString *cachePath = [cachesPath stringByAppendingPathComponent:cacheName];

                    NSDictionary *attributes = [fileManager attributesOfItemAtPath:cachePath error:NULL];

                    NSDate *cacheDate = attributes[NSFileModificationDate]; // Cache date

                    NSTimeInterval seconds = [now timeIntervalSinceDate:cacheDate]; // Cache age

                    if (seconds > age) // Older than so remove the thumb cache
                    {
                        [fileManager removeItemAtPath:cachePath error:NULL];

                        #ifdef DEBUG
                            NSLog(@"%s purged %@", __FUNCTION__, cacheName);
                        #endif
                    }
                }
            }
        }
    });
}

#pragma mark - ReaderThumbCache instance methods

- (instancetype)init
{
    if ((self = [super init])) // Initialize
    {
        thumbCache = [NSCache new]; // Cache

        thumbCache.name = @"ReaderThumbCache";

        [thumbCache setTotalCostLimit:CACHE_SIZE];
    }

    return self;
}

- (id)thumbRequest:(ReaderThumbRequest *)request priority:(BOOL)priority
{
    @synchronized(thumbCache) // Mutex lock
    {
        id object = [thumbCache objectForKey:request.cacheKey];

        if (object == nil) // Thumb object does not yet exist in the cache
        {
            object = [NSNull null]; // Return an NSNull thumb placeholder object

            [thumbCache setObject:object forKey:request.cacheKey cost:2]; // Cache the placeholder object

            ReaderThumbFetch *thumbFetch = [[ReaderThumbFetch alloc] initWithRequest:request]; // Create a thumb fetch operation

            thumbFetch.queuePriority = (priority ? NSOperationQueuePriorityNormal : NSOperationQueuePriorityLow); // Queue priority

            request.thumbView.operation = thumbFetch;
            
            //[thumbFetch setThreadPriority:(priority ? 0.55 : 0.35)]; // Thread priority
            //iOS8 QualityOfService http://nshipster.com/nsoperation/
            //        Quality of Service Constants
            //        Constants indicating the priority with which system resources are given to the operation
            //
            //        Declaration
            //        OBJECTIVE-C
            //#define NSOperationQualityOfService                  NSQualityOfService
            //#define NSOperationQualityOfServiceUserInteractive   NSQualityOfServiceUserInteractive
            //#define NSOperationQualityOfServiceUserInitiated     NSQualityOfServiceUserInitiated
            //#define NSOperationQualityOfServiceUtility           NSQualityOfServiceUtility
            //#define NSOperationQualityOfServiceBackground        NSQualityOfServiceBackground
            
            //        NSOperationQualityOfServiceUserInteractive
            //        The operation corresponds to a graphically interactive task, involving scrolling or animation in some form. Because they are user interactive, operations with this service level are given the highest priority for any needed system resources.
            //
            //            Available in iOS 8.0 and later.
            //
            //        NSOperationQualityOfServiceUserInitiated
            //        The operation corresponds to a task that the user initiated. Tasks with this service level are given a relatively high priority for system resources because they were initiated by the user and therefore correspond to work the user wants done soon.
            //
            //            Available in iOS 8.0 and later.
            //
            //        NSOperationQualityOfServiceUtility
            //        The operation corresponds to tasks initiated by the app but reflecting relatively important work being done on behalf of the user. Tasks with this service level are given a medium priority for system resources.
            //
            //            Available in iOS 8.0 and later.
            //
            //        NSOperationQualityOfServiceBackground
            //        The operation corresponds to tasks that are initiated by the app and represent noncritical tasks. Operations with this priority are given the lowest priority for system resources.
            //            
            //            Available in iOS 8.0 and later.
            
            //set QualityOfService for NSOperationQualityOfServiceUtility
            thumbFetch.qualityOfService = NSQualityOfServiceUtility; // QoS

            [[ReaderThumbQueue sharedInstance] addLoadOperation:thumbFetch]; // Queue the operation
        }

        return object; // NSNull or UIImage
    }
}

- (void)setObject:(UIImage *)image forKey:(NSString *)key
{
    @synchronized(thumbCache) // Mutex lock
    {
        NSUInteger bytes = (image.size.width * image.size.height * 4.0f);

        [thumbCache setObject:image forKey:key cost:bytes]; // Cache image
    }
}

- (void)removeObjectForKey:(NSString *)key
{
    @synchronized(thumbCache) // Mutex lock
    {
        [thumbCache removeObjectForKey:key];
    }
}

- (void)removeNullForKey:(NSString *)key
{
    @synchronized(thumbCache) // Mutex lock
    {
        id object = [thumbCache objectForKey:key];

        if ([object isMemberOfClass:[NSNull class]])
        {
            [thumbCache removeObjectForKey:key];
        }
    }
}

- (void)removeAllObjects
{
    @synchronized(thumbCache) // Mutex lock
    {
        [thumbCache removeAllObjects];
    }
}

@end
