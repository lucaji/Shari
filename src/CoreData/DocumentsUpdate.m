//
//    DocumentsUpdate.m
//    Viewer v1.2.0
//
//    Created by Julius Oklamcak on 2012-09-01.
//    Copyright © 2011-2014 Julius Oklamcak. All rights reserved.
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

#import "ReaderConstants.h"
#import "DocumentsUpdate.h"
#import "CoreDataManager.h"
#import "ReaderDocument.h"
#import "SRDiskUtils.h"


@implementation DocumentsUpdate
{
    NSOperationQueue *workQueue;
}

#pragma mark DocumentsUpdate class methods

+ (DocumentsUpdate *)sharedInstance
{
    static dispatch_once_t predicate = 0;
    static DocumentsUpdate *object = nil; // Object
    dispatch_once(&predicate, ^{ object = [self new]; });
    return object; // DocumentsUpdate singleton
}



#pragma mark DocumentsUpdate instance methods

- (instancetype)init
{
    if ((self = [super init]))
        {
        workQueue = [NSOperationQueue new];
        workQueue.name = @"DocumentsUpdateWorkQueue";
        workQueue.maxConcurrentOperationCount = 1;
        }
    
    return self;
}

- (void)cancelAllOperations
{
    [workQueue cancelAllOperations];
}

- (void)queueDocumentsUpdate
{
    if (workQueue.operationCount < 1) // Limit the number of DocumentsUpdate operations in work queue
        {
        DocumentsUpdateOperation *updateOp = [DocumentsUpdateOperation new];
        
        //[updateOp setThreadPriority:0.25];
        updateOp.qualityOfService = NSQualityOfServiceBackground; // QoS
        
        [workQueue addOperation:updateOp]; // Queue up a documents update operation
        }
}

- (BOOL)handleOpenURL:(NSURL *)theURL {
    BOOL handled = NO; // Handled flag
    if (theURL.fileURL) {
        NSString *inboxFilePath = theURL.path; // File path string
        NSString *inboxPath = inboxFilePath.stringByDeletingLastPathComponent;
        
        if ([inboxPath.lastPathComponent isEqualToString:@"Inbox"]) // Inbox test
            {
            NSString *documentFile = inboxFilePath.lastPathComponent; // File name
            NSString *documentsPath = [SRDiskUtils DocumentsPath]; // Documents path
            NSString *documentFilePath = [documentsPath stringByAppendingPathComponent:documentFile];
            NSFileManager *fileManager = [NSFileManager new]; // File manager instance
            
            [fileManager moveItemAtPath:inboxFilePath toPath:documentFilePath error:NULL]; // Move
            [fileManager removeItemAtPath:inboxPath error:NULL]; // Delete Inbox directory
            
            NSManagedObjectContext *mainMOC = CoreDataManager.singleton.mainManagedObjectContext;
            NSArray *documentList = [ReaderDocument allInMOC:mainMOC withName:documentFile];
            ReaderDocument *document = nil; // ReaderDocument object
            
            if (documentList.count > 0) {
                document = documentList[0];
            } else {
                // Insert the new document into the object store
                document = [ReaderDocument insertInMOC:mainMOC name:documentFile path:documentsPath];
                [[CoreDataManager singleton] saveMainManagedObjectContext]; // Save changes
                }
            
            if (document != nil) {
                NSString *documentURI = [document.objectID URIRepresentation].absoluteString; // Document URI
                [[NSUserDefaults standardUserDefaults] setObject:documentURI forKey:kReaderSettingsCurrentDocument];
                NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
                [notificationCenter postNotificationName:DocumentsUpdateOpenNotification object:nil userInfo:nil];
                handled = YES; // We handled the open URL request
                }
            }
        }
    
    return handled;
}

#pragma mark Notification name strings

NSString *const DocumentsUpdateOpenNotification = @"DocumentsUpdateOpenNotification";

@end

#pragma mark -

//
//    DocumentsUpdateOperation class implementation
//

@implementation DocumentsUpdateOperation

#pragma mark DocumentsUpdateOperation methods

- (void)main {
    __autoreleasing NSError *error = nil;
    NSString *documentsPath = [SRDiskUtils DocumentsPath];
    NSFileManager *fileManager = [NSFileManager new];
    NSArray *fileList = [fileManager contentsOfDirectoryAtPath:documentsPath error:&error];
    if (fileList != nil) {
        NSMutableSet *fileSet = [NSMutableSet set];
        for (NSString *fileName in fileList) {
            if ([fileName.pathExtension caseInsensitiveCompare:@"pdf"] == NSOrderedSame) {
                [fileSet addObject:fileName];
            }
        }
        
        NSMutableSet *dataSet = [NSMutableSet set]; // Database file name set
        NSMutableDictionary *nameDictionary = [NSMutableDictionary dictionary]; // Objects
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        NSManagedObjectContext *workMOC = [[CoreDataManager singleton] newManagedObjectContext];
        
        [notificationCenter addObserver:self selector:@selector(handleContextDidSaveNotification:)
                                   name:NSManagedObjectContextDidSaveNotification object:workMOC];
        
        NSArray *documentList = [ReaderDocument allInMOC:workMOC]; // All document objects
        
        for (ReaderDocument *document in documentList) {
            NSString *fileName = document.fileName; // Get the document file name
            nameDictionary[fileName] = document; // Track objects
            [dataSet addObject:fileName]; // Add the file name to the data set
        }
        
        NSMutableSet *addSet = [fileSet mutableCopy];
        [addSet minusSet:dataSet]; // Add set
        NSMutableSet *delSet = [dataSet mutableCopy];
        [delSet minusSet:fileSet]; // Delete set
        BOOL postUpdate = (addSet.count > 0) || (delSet.count > 0);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (postUpdate) [notificationCenter postNotificationName:DocumentsUpdateBeganNotification object:nil userInfo:nil];
        });
        
        for (NSString *fileName in addSet) {
            NSString *fullFilePath = [documentsPath stringByAppendingPathComponent:fileName];
            NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:fullFilePath error:NULL];
            NSDate *fileDate = fileAttributes[NSFileModificationDate]; // File date
//            NSTimeInterval timeInterval = fabs(fileDate.timeIntervalSinceNow); // File age
            
//            if (timeInterval > 10.0) // Add the file - iOS 5 file sharing sync hack'n'kludge'n'bodge
                {
                ReaderDocument *object = [ReaderDocument insertInMOC:workMOC name:fileName path:documentsPath];
                assert(object != nil); // Object insert failure should never happen
                }
            }
        
        for (NSString *fileName in delSet) // Enumerate documents to delete set
            {
            ReaderDocument *object = nameDictionary[fileName]; // Object
            [ReaderDocument deleteInMOC:workMOC object:object fm:fileManager]; // Delete
            }
        
        if (workMOC.hasChanges == YES) // Save changes
            {
            if ([workMOC save:&error] == NO) // Log any errors
                {
                NSLog(@"%s %@", __FUNCTION__, error); assert(NO);
                }
            }
        [notificationCenter removeObserver:self name:NSManagedObjectContextDidSaveNotification object:workMOC];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (postUpdate) [notificationCenter postNotificationName:DocumentsUpdateEndedNotification object:nil userInfo:nil];
            //        [notificationCenter postNotificationName:ForceLibraryRebuildNotification object:nil userInfo:nil];
            
        });
        }
    else // Log any errors
        {
        NSLog(@"%s %@", __FUNCTION__, error); assert(NO);
        }
}

#pragma mark Notification observer methods

- (void)handleContextDidSaveNotification:(NSNotification *)notification {
    dispatch_sync(dispatch_get_main_queue(), // Merge synchronously on main thread
                  ^{
                      NSManagedObjectContext *mainMOC = [[CoreDataManager singleton] mainManagedObjectContext];
                      [mainMOC mergeChangesFromContextDidSaveNotification:notification]; // Merge the changes
                  });
    NSDictionary *userInfo = notification.userInfo; // Notification information
    if (userInfo != nil) {
        NSMutableSet *deletedObjectIDs = [NSMutableSet new]; // Deleted set
        NSArray *deletedObjects = userInfo[NSDeletedObjectsKey];
        if (deletedObjects != nil) {
            for (NSManagedObject *object in deletedObjects) {
                [deletedObjectIDs addObject:object.objectID]; // Add object ID
            }
        }
        
        NSMutableSet *insertedObjectIDs = [NSMutableSet new]; // Inserted set
        NSArray *insertedObjects = userInfo[NSInsertedObjectsKey];
        if (insertedObjects != nil) {
            for (NSManagedObject *object in insertedObjects) {
                [insertedObjectIDs addObject:object.objectID]; // Add object ID
            }
        }
        
        NSMutableDictionary *updateInfo = [NSMutableDictionary new]; // Update info
        if (deletedObjectIDs.count > 0) {
            updateInfo[DocumentsUpdateDeletedObjectIDs] = deletedObjectIDs;
        }
        
        if (insertedObjectIDs.count > 0) {
            updateInfo[DocumentsUpdateAddedObjectIDs] = insertedObjectIDs;
        }
        
        if (updateInfo.count > 0) // Post an update notification
            {
            dispatch_async(dispatch_get_main_queue(), // Notify asynchronously on main thread
                           ^{
                               NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
                               [notificationCenter postNotificationName:DocumentsUpdateNotification object:nil userInfo:updateInfo];
                           });
            }
    }
}




#pragma mark Notification name strings

NSString *const ForceLibraryRebuildNotification = @"ForceLibraryRebuildNotification";
NSString *const DocumentsUpdateNotification = @"DocumentsUpdateNotification";
NSString *const DocumentsUpdateAddedObjectIDs = @"DocumentsUpdateAddedObjectIDs";
NSString *const DocumentsUpdateDeletedObjectIDs = @"DocumentsUpdateDeletedObjectIDs";
NSString *const DocumentsUpdateBeganNotification = @"DocumentsUpdateBeganNotification";
NSString *const DocumentsUpdateEndedNotification = @"DocumentsUpdateEndedNotification";

@end
