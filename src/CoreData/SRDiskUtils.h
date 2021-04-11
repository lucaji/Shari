//
//  SRDiskUtils.h
//  SHARI
//
//  Created by Luca Cipressi on 30/03/2014.
//  Copyright (c) 2014-2021 Luca Cipressi - lucaji.github.io - lucaji@mail.ru. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SRDiskUtils : NSObject

+ (NSString*)appDocumentsFolderName;
+ (NSString*)DocumentsPath;
+ (NSString *)CachesPath;
+ (NSArray<NSURL*>*)LocalDocumentsDirectoryListing;
+ (NSURL*)applicationDocumentsDirectoryUrl;
+ (void)cleanupEmptyDirectories;
+ (BOOL)checkIfEmptyDirectoryAtPath:(NSString *)path;
+(NSString* _Nullable)urlRelativePathFromDocumentsDirectory:(NSURL*)localUrl;

@end

NS_ASSUME_NONNULL_END
