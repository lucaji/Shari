/*
 *  MHWDirectoryWatcher.h
 *  Created by Martin Hwasser on 12/19/11.
 */

#import <Foundation/Foundation.h>

@interface MHWDirectoryWatcher : NSObject

// Returns an initialized MHWDirectoryWatcher and begins to watch the path, if specified
+ (MHWDirectoryWatcher *)directoryWatcherAtPath:(NSString *)watchedPath
                               startImmediately:(BOOL)startImmediately
                                       callback:(dispatch_block_t)cb;

// Equivalent to calling +directoryWatcherAtPath:startImmediately and passing
// YES for startImmediately.
+ (MHWDirectoryWatcher *)directoryWatcherAtPath:(NSString *)watchPath
                                       callback:(dispatch_block_t)cb;

// Returns YES if started watching, NO if already is watching
@property (nonatomic, readonly) BOOL startWatching;

// Returns YES if stopped watching, NO if not watching
@property (nonatomic, readonly) BOOL stopWatching;

// The path being watched
@property (nonatomic, readonly, copy) NSString *watchedPath;

@end
