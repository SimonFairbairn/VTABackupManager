//
//  VTABackupManager.h
//
//  Created by Simon Fairbairn on 21/06/2013.
//
//  Copyright (c) 2013 Simon Fairbairn.
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//
//  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
//  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer
//  in the documentation and/or other materials provided with the distribution.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,
//  BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
//  SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
//  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "VTABackupManager.h"

#define VTABackupManagerErrorDomain @"VTA Backup Manager"

#define VTABackupManagerDebugLog 0

@interface VTABackupManager ()

@property (nonatomic, readwrite) NSArray *backupList;
@property (nonatomic, strong) NSMutableDictionary *dictionaryOfInsertedRelationshipIDs;

@property (nonatomic, readwrite, getter = isRunning) BOOL running;

@end

@implementation VTABackupManager

#pragma mark - Properties

-(NSMutableDictionary *)dictionaryOfInsertedRelationshipIDs {
    
    if ( !_dictionaryOfInsertedRelationshipIDs ) {
        _dictionaryOfInsertedRelationshipIDs = [[NSMutableDictionary alloc] init];
    }
    return _dictionaryOfInsertedRelationshipIDs;
}

-(NSString *)backupExtension {

    if ( !_backupExtension ) {
        _backupExtension = @"vtabackup";
    }
    return _backupExtension;
}

-(NSURL *)backupDirectory {
    
    if ( !_backupDirectory ) {
        _backupDirectory = [[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] objectAtIndex:0] URLByAppendingPathComponent:@"backups" isDirectory:YES];
    }
    return _backupDirectory;
}

-(NSArray *)backupList {
    
    if ( !_backupList ) {
        _backupList = [self listBackups];
    }
    return _backupList;
}

-(NSNumber *) backupsToKeep {
    
    if ( !_backupsToKeep ) {
        _backupsToKeep = @(5);
    }
    return _backupsToKeep;
}

#pragma mark - Initialisation

+ (instancetype)sharedManager {
    static dispatch_once_t predicate;
    static VTABackupManager *instance = nil;
    dispatch_once(&predicate, ^{instance = [[self alloc] init];});
    return instance;
}

#pragma mark - Methods

-(NSArray *)listBackups {
    
#if VTABackupManagerDebugLog
    NSLog(@"Listing files at: %@", [self backupDirectory]);
#endif
    
    NSMutableArray *mutableBackups = [[NSMutableArray alloc] init];
    NSArray *backups = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[self backupDirectory] includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension ENDSWITH '.%@'", self.backupExtension];
    [backups filteredArrayUsingPredicate:predicate];
    mutableBackups = [backups mutableCopy];
    
    NSMutableArray *mutableBackupArray = [NSMutableArray new];
    for ( NSURL *url in mutableBackups ) {
        if ( [[url path] rangeOfString:@"toDelete"].location == NSNotFound ) {
            VTABackupItem *item = [[VTABackupItem alloc] initWithFile:url];
            [mutableBackupArray addObject:item];
        }
    }
    
    NSSortDescriptor *dateStringSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"dateString" ascending:NO selector:@selector(localizedCaseInsensitiveCompare:)];

#if VTABackupManagerDebugLog
    NSLog(@"Full List: %@", backups);
    NSLog(@"Filtered List: %@", mutableBackupArray);
#endif
    return [mutableBackupArray sortedArrayUsingDescriptors:@[dateStringSortDescriptor]];
}

-(void)reloadDirectory {
    self.backupList = nil;
}

#pragma mark - Backup

-(void)backupEntityWithName:(NSString *)name
                  inContext:(NSManagedObjectContext *)context
          completionHandler:(void (^)(BOOL, NSError *))completion
             forceOverwrite:(BOOL)overwrite {
    [self backupEntityWithName:name inContext:context completionHandler:completion forceOverwrite:overwrite recursive:YES];
}

-(void)backupEntityWithName:(NSString *)name
                  inContext:(NSManagedObjectContext *)context
          completionHandler:(void (^)(BOOL, NSError *))completion
             forceOverwrite:(BOOL)overwrite
                  recursive:(BOOL)recursive {
    
    // The URL for today's file
    NSURL *backupFileForToday = [self.backupDirectory URLByAppendingPathComponent:[VTABackupItem newFileNameWithExtension:self.backupExtension]];
    
    NSLog(@"Backup file for today: %@", backupFileForToday);
    
    // If we've already backed up today and we're not forcing an overwrite, we need go no further
    if ( !overwrite ) {
        
        if ( [[NSFileManager defaultManager] fileExistsAtPath:[backupFileForToday path]]) {

#if VTABackupManagerDebugLog
            NSLog(@"File exists, overwrite not set. No action to perform. Returning.");
#endif
            
            return;
        }
        
    }
    
    // Perform some sanity checking to prevent crashes
    if ( !context ) {
        NSDictionary *errorDictionary = @{NSLocalizedDescriptionKey : @"No NSManagedObjectContext found. Did you forget to set the context?"};
        NSError *error = [NSError errorWithDomain:VTABackupManagerErrorDomain code:NSCoreDataError  userInfo:errorDictionary];
        completion(NO, error);
        return;
    }
    
    
    if ( !name ) {
        NSDictionary *errorDictionary = @{NSLocalizedDescriptionKey : @"No entity given to backup. Did you forget to set the entity name?"};
        NSError *error = [NSError errorWithDomain:VTABackupManagerErrorDomain code:NSCoreDataError  userInfo:errorDictionary];
        completion(NO, error);
        return;
    }
    
    if ( ![context save:nil] ) {
        NSDictionary *errorDictionary = @{NSLocalizedDescriptionKey : @"Error saving context prior to backup"};
        NSError *error = [NSError errorWithDomain:VTABackupManagerErrorDomain code:NSCoreDataError  userInfo:errorDictionary];
        completion(NO, error);
        return;
    }
    
    self.running = YES;
    
    // Post notification that we will begin backing up
    NSNotification *note = [NSNotification notificationWithName:VTABackupManagerWillProcessBackupsNotification object:self];
    [[NSNotificationCenter defaultCenter] postNotification:note];
    
    // Create our private queue context
    NSManagedObjectContext *backgroundContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    backgroundContext.persistentStoreCoordinator = context.persistentStoreCoordinator;
    
    [backgroundContext performBlock:^{
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:name inManagedObjectContext:backgroundContext];
        
#if VTABackupManagerDebugLog
        sleep(3);
#endif
        
        BOOL success = YES;
        NSError *error;
        
        // First, we need to create the directory
        [[NSFileManager defaultManager] createDirectoryAtPath:[self.backupDirectory path] withIntermediateDirectories:YES attributes:nil error:&error ];

        if ( error ) {
            
#if VTABackupManagerDebugLog
            NSLog(@"Error creating directory: %@", [error localizedDescription]);
#endif
            
        }
        
        // Delete any remaining backups, unless the old backups to delete is set to 0 or below
        [self deleteOldBackups];
        
#define VTAEncoderKey @"VTAEncoderKey"
        
        // Let's get everything from database for the given entity
        NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:entity.name];
        NSArray *results = [backgroundContext executeFetchRequest:request error:&error];
        
#if VTABackupManagerDebugLog
        NSLog(@"Objects for entity: %@", results);
#endif
        // Time to archive the results
        NSArray *dictionary = [self dataFromArrayOfManagedObjects:results Recursive:recursive];
        NSMutableData * data = [[NSMutableData alloc] init];
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
        [archiver encodeObject:dictionary forKey:VTAEncoderKey];
        [archiver finishEncoding];
        
        if ( ![data writeToFile:[backupFileForToday path] atomically:YES] ) {
            NSDictionary *errorDictionary = @{NSLocalizedDescriptionKey : @"Error writing to file."};
            error = [NSError errorWithDomain:VTABackupManagerErrorDomain code:NSFileWriteUnknownError userInfo:errorDictionary];
        }
        //
        //        if ( [dictionary writeToFile:[backupFileForToday path] atomically:YES] ) {
        //            NSDictionary *errorDictionary = @{NSLocalizedDescriptionKey : @"Failed to archive the plist. This could indicate an error with the data within the plist, or you have specified a backup directory that is inaccessible."};
        //            error = [NSError errorWithDomain:VTABackupManagerErrorDomain code:NSFileWriteUnknownError userInfo:errorDictionary];
        //        }
        
        
        // If error is set, we weren't successful
        success = ( error ) ? NO : YES;
        
        dispatch_async(dispatch_get_main_queue(), ^{

            self.running = NO;
            
            self.backupList = nil;
            
            NSNotification *note = [NSNotification notificationWithName:VTABackupManagerDidProcessBackupsNotification object:nil];
            [[NSNotificationCenter defaultCenter] postNotification:note];
            
            completion(success, error);
        });
        
    }];
    
    
}

-(BOOL)deleteBackupAtURL:(NSURL *)URL {
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtURL:URL error:&error];
    if ( error ) {
#if VTABackupManagerDebugLog
        NSLog(@"%@", [error localizedDescription]);
#endif
        
        return NO;
    } else {
        // Destroy and recreate the list
        self.backupList = nil;
    }
    return YES;
}

-(void)deleteOldBackups {
    
#if VTABackupManagerDebugLog
    NSLog(@"List of backups before delete: %@", self.backupList);
#endif
    
    NSUInteger numberOfBackups = [self.backupsToKeep intValue];

    if ( [self.backupList count] < numberOfBackups ) {
        return;
    }

    if ( numberOfBackups == 0 ) return;
    
    
    NSArray *backupList = [self.backupList copy];
    for ( NSUInteger i = 0; i < [backupList count]; i++ ) {
        if ( i >= numberOfBackups ) {
            VTABackupItem *item = [backupList objectAtIndex:i];

#if VTABackupManagerDebugLog
            NSLog(@"Deleting file at: %@", item.fileURL);
#endif
            
            [self deleteBackupAtURL:item.fileURL];
            
        }
    }

    // Reset list
    self.backupList = nil;
    
#if VTABackupManagerDebugLog
    NSLog(@"List of backups before delete: %@", self.backupList);
#endif
    
}

#pragma mark - Restore

-(void)restoreFromURL:(NSURL *)URL
          intoContext:(NSManagedObjectContext *)context
withCompletitionHandler:(void (^)(BOOL, NSError *))completion {
 
    // Perform some sanity checking to prevent crashes
    if ( !context ) {
        NSDictionary *errorDictionary = @{NSLocalizedDescriptionKey : @"No NSManagedObjectContext found. Did you forget to set the context?"};
        NSError *error = [NSError errorWithDomain:VTABackupManagerErrorDomain code:NSCoreDataError  userInfo:errorDictionary];
        completion(NO, error);
        return;
    }
    
    self.running = YES;
    
    // Post notification that we will begin restoring
    NSNotification *note = [NSNotification notificationWithName:VTABackupManagerWillProcessRestoreNotification object:self];
    [[NSNotificationCenter defaultCenter] postNotification:note];
    
    NSManagedObjectContext *privateContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    privateContext.persistentStoreCoordinator = context.persistentStoreCoordinator;
    
    [privateContext performBlock:^{
        BOOL success = YES;
        NSError *error;
        
        NSData *fileData = [[NSMutableData alloc] initWithContentsOfFile:[URL path]];
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:fileData];
        NSDictionary *myDictionary = [unarchiver decodeObjectForKey:VTAEncoderKey];

#if VTABackupManagerDebugLog
        NSLog(@"%@", myDictionary);
#endif
        
        for (NSDictionary *objectDictionary in myDictionary ) {
            [self managedObjectFromStructure:objectDictionary withContext:privateContext];
        }
        
        // Empty the memory
        self.dictionaryOfInsertedRelationshipIDs = nil;
        
        [privateContext save:&error];
        success = (error) ? NO : YES;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            self.running = NO;
            
            NSNotification *note = [NSNotification notificationWithName:VTABackupManagerDidProcessRestoreNotification object:self];
            [[NSNotificationCenter defaultCenter] postNotification:note
             ];
            completion(success, error);
        });
        
    }];
}

#pragma mark - Archiving the Managed Object

#define VTABackupManagerManagedObjectNameKey @"ManagedObjectName"
#define VTABackupManagerManagedObjectIDKey @"ManagedObjectID"

-(NSArray *)dataFromArrayOfManagedObjects:(NSArray *)objects Recursive:(BOOL)recursive {
    NSMutableArray *processedObjects = [[NSMutableArray alloc] init];
    if ( [objects count] > 0 ) {
        for (NSManagedObject *object in objects ) {
            [processedObjects addObject:[self dataStructureFromManagedObject:object recursive:recursive]];
        }
    }
    return processedObjects;
}

// Modified code based on ideas found here:
// http://stackoverflow.com/questions/1371749/can-i-encode-a-subclass-of-nsmanagedobject
// http://stackoverflow.com/questions/2362323/json-and-core-data-on-the-iphone

- (NSDictionary*)dataStructureFromManagedObject:(NSManagedObject*)managedObject recursive:(BOOL)recursive
{
    NSDictionary *attributesByName = [[managedObject entity] attributesByName];
    NSDictionary *relationshipsByName = [[managedObject entity] relationshipsByName];
    NSMutableDictionary *valuesDictionary = [[managedObject dictionaryWithValuesForKeys:[attributesByName allKeys]] mutableCopy];
    [valuesDictionary setObject:[[managedObject entity] name] forKey:VTABackupManagerManagedObjectNameKey];
    [valuesDictionary setObject:[[managedObject objectID] URIRepresentation] forKey:VTABackupManagerManagedObjectIDKey];
    
    if ( recursive ) {
        // Go through the relationships
        for (NSString *relationshipName in [relationshipsByName allKeys]) {
            NSRelationshipDescription *description = [[[managedObject entity] relationshipsByName] objectForKey:relationshipName];
            // if the relationship is not a toMany relationsip, we just need the single object it points to
            if (![description isToMany]) {
                NSManagedObject *relationshipObject = [managedObject valueForKey:relationshipName];
                // If there is an object
                if ( relationshipObject ) {
                    [valuesDictionary setObject:[self dataStructureFromManagedObject:relationshipObject recursive:NO] forKey:relationshipName];
                } 
                continue;
            }
            // Otherwise, it's a set and each object needs to be added
            NSSet *relationshipObjects = [managedObject valueForKey:relationshipName];
            if ( [relationshipObjects count] > 0 ) {

                NSMutableArray *relationshipArray = [[NSMutableArray alloc] init];
                for (NSManagedObject *relationshipObject in relationshipObjects) {
                    [relationshipArray addObject:[self dataStructureFromManagedObject:relationshipObject recursive:NO]];
                }
                [valuesDictionary setObject:relationshipArray forKey:relationshipName];
                
            }
            
        }
    }
    
#if VTABackupManagerDebugLog
    NSLog(@"%@", valuesDictionary);
#endif
 
    return valuesDictionary;
}

- (NSManagedObject*)managedObjectFromStructure:(NSDictionary*)objectDictionary withContext:(NSManagedObjectContext *)context recursive:(BOOL)recursive {
    
    NSString *objectName = [objectDictionary objectForKey:VTABackupManagerManagedObjectNameKey];

    NSMutableDictionary *structureDictionary = [objectDictionary mutableCopy];
    [structureDictionary removeObjectForKey:VTABackupManagerManagedObjectNameKey];
    [structureDictionary removeObjectForKey:VTABackupManagerManagedObjectIDKey];
    NSManagedObject *managedObject = [NSEntityDescription insertNewObjectForEntityForName:objectName inManagedObjectContext:context];
    
    // for each item in this dictionary
    for ( NSString *key in objectDictionary ) {
        // If there is any relationship information, this has to be removed
        if ( [[structureDictionary objectForKey:key] isKindOfClass:[NSDictionary class]] ) {
            // toOne relationship
            // Get the relationship details

            
            if ( recursive ) {
                NSDictionary *detailDictionary = [structureDictionary objectForKey:key];
                NSURL *relationshipObjectID  = [detailDictionary objectForKey:VTABackupManagerManagedObjectIDKey ];
                NSManagedObject *existingObject = [self.dictionaryOfInsertedRelationshipIDs objectForKey:relationshipObjectID];
                NSManagedObject *singleObject;
                if ( !existingObject) {
                    singleObject = [self managedObjectFromStructure:[structureDictionary objectForKey:key] withContext:context recursive:NO];
                    [self.dictionaryOfInsertedRelationshipIDs setObject:singleObject forKey:[detailDictionary objectForKey:VTABackupManagerManagedObjectIDKey]];
                    
                } else {
                    singleObject = [self.dictionaryOfInsertedRelationshipIDs objectForKey:relationshipObjectID];
                }
                NSString *relationshipName = [detailDictionary objectForKey:VTABackupManagerManagedObjectNameKey];
                [managedObject setValue:singleObject forKey:relationshipName];
                
            }
            [structureDictionary removeObjectForKey:key];

        } else if ( [[structureDictionary objectForKey:key] isKindOfClass:[NSArray class]] ) {
            // toMany relationship
            // We have an array of items
            if ( recursive ) {
                NSMutableSet *mutableSet = [[NSMutableSet alloc] init];
#if VTABackupManagerDebugLog
                NSLog(@"%@", [structureDictionary objectForKey:key]);
#endif
                for ( NSDictionary *detailDictionary in [structureDictionary objectForKey:key]) {
//                    // This should be the same for everything in this loop

                    NSURL *relationshipObjectID  = [detailDictionary objectForKey:VTABackupManagerManagedObjectIDKey ];
                    NSManagedObject *existingObject = [self.dictionaryOfInsertedRelationshipIDs objectForKey:relationshipObjectID];
                    NSManagedObject *singleObject;
                    if ( !existingObject) {
                        singleObject = [self managedObjectFromStructure:detailDictionary withContext:context recursive:NO];
                        [self.dictionaryOfInsertedRelationshipIDs setObject:singleObject forKey:[detailDictionary objectForKey:VTABackupManagerManagedObjectIDKey]];
//
                    } else {
                        singleObject = [self.dictionaryOfInsertedRelationshipIDs objectForKey:relationshipObjectID];
                    }
                    [mutableSet addObject:singleObject];
//
                }
                if ( mutableSet ) {
//
                    [managedObject setValue:mutableSet forKey:key];
                }
            }

            [structureDictionary removeObjectForKey:key];
            
        }
    }
    
    [managedObject setValuesForKeysWithDictionary:structureDictionary];
    
    return managedObject;
}

- (NSManagedObject*)managedObjectFromStructure:(NSDictionary*)objectDictionary withContext:(NSManagedObjectContext *)context {
    return [self managedObjectFromStructure:objectDictionary withContext:context recursive:YES];
}

@end
