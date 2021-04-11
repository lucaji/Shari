//
//  SRDiskUtils.m
//  SHARI
//
//  Created by Luca Cipressi on 30/03/2014.
//  Copyright (c) 2014-2021 Luca Cipressi - lucaji.github.io - lucaji@mail.ru. All rights reserved.
//

#import "SRDiskUtils.h"

@implementation SRDiskUtils

#pragma mark - Path Utilities

+ (NSString *)applicationPath {
    static dispatch_once_t predicate = 0;
    static NSString *_applicationPath = nil;
    dispatch_once(&predicate, ^{
        _applicationPath = [self DocumentsPath].stringByDeletingLastPathComponent; // Strip "Documents"
    });
    return _applicationPath;
}

+(NSString*)appDocumentsFolderName {
    static NSString *_appDocumentsFolderName = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        _appDocumentsFolderName = path.lastPathComponent;
    });
    return _appDocumentsFolderName;
}

+ (NSString *)DocumentsPath {
    static NSString *_sharedDocumentsDirectoryPath = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        _sharedDocumentsDirectoryPath = paths.firstObject;
    });
    return _sharedDocumentsDirectoryPath;
}

+ (NSString *)CachesPath {
    static NSString *_sharedCachesDirectoryPath = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        _sharedCachesDirectoryPath = paths.firstObject;
    });
    return _sharedCachesDirectoryPath;
}

+ (NSURL *)applicationDocumentsDirectoryUrl {
    static NSURL *_applicationDocumentsDirectoryUrl = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        _applicationDocumentsDirectoryUrl = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    });
    return _applicationDocumentsDirectoryUrl;
}

+ (NSURL *)applicationSupportDirectory {
    __autoreleasing NSError *error = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    return [fileManager URLForDirectory:NSApplicationSupportDirectory
                               inDomain:NSUserDomainMask
                      appropriateForURL:nil
                                 create:YES
                                  error:&error];
}

+ (NSArray <NSURL*>*)LocalDocumentsDirectoryListing {
    NSURL *directoryToScan = [NSURL fileURLWithPath:self.DocumentsPath];
    NSDirectoryEnumerator *dirEnumerator = [[NSFileManager defaultManager] enumeratorAtURL:directoryToScan
                                                                includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey, NSURLFileSizeKey,NSURLCreationDateKey]
                                                                                   options:NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsPackageDescendants
                                                                              errorHandler:nil];

    if (dirEnumerator == nil) return @[];

    // sort array
    NSArray<NSURL*> *sortedArray = [dirEnumerator.allObjects sortedArrayUsingComparator:^NSComparisonResult(NSURL *p1, NSURL *p2) {
        return [p1.path compare:p2.path options:NSNumericSearch];
    }];

    return sortedArray;
}

+ (void)checkIfEmptyDirectoryAtURL:(NSURL *)urlo {
    __autoreleasing NSError *error = nil;
    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray *list = [manager contentsOfDirectoryAtURL:urlo
                           includingPropertiesForKeys:nil
                                              options:NSDirectoryEnumerationSkipsHiddenFiles
                                                error:&error];
    if (list.count == 0 && error == nil) {
        // check if number of files == 0 ==> empty directory
        // check if error set (fullPath is not a directory and we should leave it alone)
        [manager removeItemAtURL:urlo error:&error];
    }
}

+ (BOOL)checkIfEmptyDirectoryAtPath:(NSString *)path {
    __autoreleasing NSError *error = nil;
    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray *list = [manager contentsOfDirectoryAtPath:path error:&error];
    if (list.count == 0 && error == nil) {
        // check if number of files == 0 ==> empty directory
        // check if error set (fullPath is not a directory and we should leave it alone)
        [manager removeItemAtPath:path error:&error];
        return YES;
    }
    return NO;
}

+ (void)cleanupEmptyDirectories {
    for (NSURL *u in self.LocalDocumentsDirectoryListing) {
        [self checkIfEmptyDirectoryAtPath:u.path];
    }
}


+(NSString* _Nullable)urlRelativePathFromDocumentsDirectory:(NSURL* _Nonnull)localUrl {
    NSString*appDocumentsFolderName = [SRDiskUtils appDocumentsFolderName];
    NSString*urlRelativePath = [NSString string];
    BOOL construct = NO;
    NSArray<NSString*>*components = (localUrl.path).pathComponents;
    for (NSString*component in components) {
        if (!construct && [component isEqualToString:appDocumentsFolderName]) {
            construct = YES;
            continue;
        }
        if (construct) {
            urlRelativePath = [urlRelativePath stringByAppendingPathComponent:component];
        }
    }
    return urlRelativePath.length>0?urlRelativePath:nil;
}



@end
