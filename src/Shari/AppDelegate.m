//
//  AppDelegate.m
//  Shari
//
//  Created by Luca Cipressi on 30/05/2017.
//  Copyright (c) 2017-2021 Luca Cipressi - lucaji.github.io - lucaji@mail.ru. All rights reserved.
//

#import "AppDelegate.h"
#import "ReaderConstants.h"
#import "LibraryViewController.h"
#import "MHWDirectoryWatcher.h"
#import "CoreDataManager.h"
#import "DocumentsUpdate.h"
#import "DocumentFolder.h"
#import "SRDiskUtils.h"
#include <sys/xattr.h>
#import "WebServer.h"

@interface AppDelegate () <WebServerDelegate>

@property (nonatomic) MHWDirectoryWatcher*eventDirectoryWatcher;
@property (nonatomic) LibraryViewController *rootViewController;

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    return [[DocumentsUpdate sharedInstance] handleOpenURL:url];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self registerAppDefaults]; // Register various application settings defaults
    
    (WebServer.sharedWebServer).type = kWebServerType_Website;
    WebServer.sharedWebServer.delegate = self;
    
    [self prePopulateCoreData]; // Pre-populate Core Data store with various default objects
    
    if ((launchOptions != nil) && (launchOptions[UIApplicationLaunchOptionsURLKey] != nil))
        {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kReaderSettingsCurrentDocument]; // Clear
        }
    
    NSString *documentsPath = [SRDiskUtils DocumentsPath]; // Application Documents path
//    u_int8_t value = 1; // Value for iCloud and iTunes 'do not backup' item setxattr() function
//    setxattr(documentsPath.fileSystemRepresentation, "com.apple.MobileBackup", &value, 1, 0, 0);
    
    self.eventDirectoryWatcher = [MHWDirectoryWatcher directoryWatcherAtPath:documentsPath
                                                                    callback:^{
                                                                        NSLog(@"directory changed... queueing doc update");
                                                                        [[DocumentsUpdate sharedInstance] queueDocumentsUpdate]; // Queue a documents update
                                                                    }];
    
    
    self.rootViewController = [[LibraryViewController alloc] initWithNibName:nil bundle:nil]; // Root
    self.window.rootViewController = self.rootViewController; // Set the root view controller
    [self.window makeKeyAndVisible]; // Make it the key window and visible
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    [self.eventDirectoryWatcher stopWatching];
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    [self.eventDirectoryWatcher startWatching];

}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    [[DocumentsUpdate sharedInstance] queueDocumentsUpdate]; // Queue a documents update

}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    // Saves changes in the application's managed object context before the application terminates.
}


#pragma mark Miscellaneous methods

- (void)registerAppDefaults
{
    NSNumber *hideStatusBar = @YES;
    NSDictionary *infoDictionary = [NSBundle mainBundle].infoDictionary;
    NSString *version = infoDictionary[(NSString *)kCFBundleVersionKey];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults]; // User defaults
    NSDictionary *defaults = @{kReaderSettingsHideStatusBar: hideStatusBar};
    [userDefaults registerDefaults:defaults]; [userDefaults synchronize]; // Save user defaults
    [userDefaults setObject:version forKey:kReaderSettingsAppVersion]; // App version
}

- (void)prePopulateCoreData
{
    NSManagedObjectContext *mainMOC = [[CoreDataManager singleton] mainManagedObjectContext];
    if ([DocumentFolder existsInMOC:mainMOC type:DocumentFolderTypeDefault] == NO) // Add default folder
        {
        NSString *folderName = NSLocalizedString(@"Documents", @"name"); // Localized default folder name
        [DocumentFolder insertInMOC:mainMOC name:folderName type:DocumentFolderTypeDefault]; // Insert it
        }
    
    if ([DocumentFolder existsInMOC:mainMOC type:DocumentFolderTypeRecent] == NO) // Add recent folder
        {
        NSString *folderName = NSLocalizedString(@"Recent", @"name"); // Localized recent folder name
        [DocumentFolder insertInMOC:mainMOC name:folderName type:DocumentFolderTypeRecent]; // Insert it
        }
}

#pragma mark - Web Server Delegate
- (void) webServerDidConnect:(WebServer*)server {
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    
}

- (void) webServerDidDownloadComic:(WebServer*)server {
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
    
}

// NOT USED THESE CALLBACKS
- (void) webServerDidUploadComic:(WebServer*)server {
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
//    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
//    [notificationCenter postNotificationName:ForceLibraryRebuildNotification object:nil userInfo:nil];
}

- (void) webServerDidUpdate:(WebServer*)server {
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter postNotificationName:ForceLibraryRebuildNotification object:nil userInfo:nil];
}

- (void) webServerDidDisconnect:(WebServer*)server {
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    
}


@end
