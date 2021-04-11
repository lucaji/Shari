//
//  CoreDataManager.h
//  SHARI
//
//  Created by Luca Cipressi on 30/05/2017.
//  Copyright (c) 2017-2021 Luca Cipressi - lucaji.github.io - lucaji@mail.ru. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface CoreDataManager : NSObject

+ (CoreDataManager *)singleton;

@property (nonatomic, readonly, copy) NSManagedObjectContext *mainManagedObjectContext;
@property (nonatomic, readonly) NSManagedObjectContext *newManagedObjectContext;

- (void)saveMainManagedObjectContext;

-(NSManagedObjectID*)objectIDForURL:(NSURL*)theUrl;

@end
