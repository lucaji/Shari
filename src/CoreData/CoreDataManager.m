//
//  CoreDataManager.m
//  SHARI
//
//  Created by Luca Cipressi on 30/05/2017.
//  Copyright (c) 2017-2021 Luca Cipressi - lucaji.github.io - lucaji@mail.ru. All rights reserved.
//

#import "CoreDataManager.h"
#import "SRDiskUtils.h"

@interface CoreDataManager()


@end

@implementation CoreDataManager {
    NSManagedObjectModel *mainManagedObjectModel;

    NSPersistentStoreCoordinator *mainPersistentStoreCoordinator;

    NSManagedObjectContext *mainManagedObjectContext;
}

#pragma mark CoreDataManager class methods

+ (CoreDataManager *)singleton {
    static dispatch_once_t oncePredicate = 0;
    static CoreDataManager *sharedManager = nil;
    dispatch_once(&oncePredicate, ^{
        sharedManager = [self new];
    });
    return sharedManager;
}

+ (NSURL *)applicationDocumentsDirectory {
    return [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
}

+ (NSURL *)applicationSupportDirectory {
    return [NSFileManager.defaultManager URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:NULL];
}

+ (NSURL *)applicationCoreDataStoreFileURL {
    return [[CoreDataManager applicationSupportDirectory] URLByAppendingPathComponent:@"ReaderStore.sqlite"];
}

#pragma mark CoreDataManager instance methods

- (NSManagedObjectModel *)mainManagedObjectModel {
    if (mainManagedObjectModel == nil) {
        assert(NSThread.isMainThread);
        NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Reader" withExtension:@"momd"];
        mainManagedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    }
    return mainManagedObjectModel;
}

- (NSPersistentStoreCoordinator *)mainPersistentStoreCoordinator {
    if (mainPersistentStoreCoordinator == nil) {
        assert(NSThread.isMainThread);
        NSURL *storeURL = [CoreDataManager applicationCoreDataStoreFileURL];
        __autoreleasing NSError *error = nil;
        NSDictionary *migrate = @{NSMigratePersistentStoresAutomaticallyOption: @YES,
                                NSInferMappingModelAutomaticallyOption: @YES};

        mainPersistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self mainManagedObjectModel]];
        if ([mainPersistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:migrate error:&error] == nil) {
            // TODO:
            // Replace this implementation with code to handle the error appropriately.

            // assert() causes the application to generate a crash log and terminate. You should not use this function in a
            // shipping application, although it may be useful during development. If it is not possible to recover from the
            // error, display an alert panel that instructs the user to quit the application by pressing the Home button.

            // Typical reasons for an error here include:
            // * The persistent store is not accessible;
            // * The schema for the persistent store is incompatible with current managed object model.
            // Check the error message to determine what the actual problem was.

            // If the persistent store is not accessible, there is typically something wrong with the file path.
            // Often, a file URL is pointing into the application's resources directory instead of a writeable directory.

            // If you encounter schema incompatibility errors during development, you can reduce their frequency by:
            // * Simply deleting the existing store:
            // [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]

            // * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
            // [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
            // [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];

            // Lightweight migration will only work for a limited set of schema changes.
            // Consult "Core Data Model Versioning and Data Migration Programming Guide" for details.

            NSLog(@"%s %@", __FUNCTION__, error);
            assert(NO);
        }
    }
    return mainPersistentStoreCoordinator;
}

- (NSManagedObjectContext *)mainManagedObjectContext {
    if (mainManagedObjectContext == nil) {
        assert(NSThread.isMainThread);
        NSPersistentStoreCoordinator *coordinator = [self mainPersistentStoreCoordinator];
        if (coordinator != nil) {
            mainManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
            mainManagedObjectContext.persistentStoreCoordinator = coordinator;
        }
    }
    return mainManagedObjectContext;
}

- (NSManagedObjectContext *)newManagedObjectContext {
    NSManagedObjectContext *someManagedObjectContext = nil;
    NSPersistentStoreCoordinator *coordinator = [self mainPersistentStoreCoordinator];
    if (coordinator != nil) {
        someManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        someManagedObjectContext.persistentStoreCoordinator = coordinator;
    }
    return someManagedObjectContext;
}

- (void)saveMainManagedObjectContext {
    assert(NSThread.isMainThread);
    if (mainManagedObjectContext != nil) {
        __autoreleasing NSError *error = nil;
        if (mainManagedObjectContext.hasChanges) {
            if ([mainManagedObjectContext save:&error] == NO) {
                // TODO:
                // Replace this implementation with code to handle the error appropriately.

                // assert() causes the application to generate a crash log and terminate. You should not use this function in a
                // shipping application, although it may be useful during development. If it is not possible to recover from the
                // error, display an alert panel that instructs the user to quit the application by pressing the Home button.

                NSLog(@"%s %@", __FUNCTION__, error); assert(NO);
            }
        }
    }
}

-(NSManagedObjectID*)objectIDForURL:(NSURL*)theUrl {
    NSPersistentStoreCoordinator *mainPSC = self.mainManagedObjectContext.persistentStoreCoordinator;
    NSManagedObjectID *objectID = [mainPSC managedObjectIDForURIRepresentation:theUrl];
    return objectID;
}

@end
