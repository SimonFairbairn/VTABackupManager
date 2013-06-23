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
#define VTABackupManagerFileExtenstion @"vtabackup"

#define debugLog 1


@interface VTABackupManager ()

@property (nonatomic, readwrite) NSArray *backupList;

// Declared as a property as we're not expecting to be used very much
@property (nonatomic, strong) NSDateFormatter *dateFormatter;

@end

@implementation VTABackupManager

#pragma mark - Initialisation
-(VTABackupManager *)initWithManagedObjectContext:(NSManagedObjectContext *)context entityToBackup:(NSEntityDescription *)entity {
    self = [super init];
    if ( self ) {
        _context = context;
        _entity = entity;
    }
    return self;
    
}

-(id)init {
    return [self initWithManagedObjectContext:nil entityToBackup:nil];
}


#pragma mark - Properties

-(NSString *)backupPrefix {
    if ( !_backupPrefix ) {
        _backupPrefix = @"backup";
    }
    return _backupPrefix;
}

-(NSURL *)backupDirectory {
    if ( !_backupDirectory ) {
        _backupDirectory = [[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] objectAtIndex:0] URLByAppendingPathComponent:@"backups" isDirectory:YES];
    }
    return _backupDirectory;
}

-(NSDateFormatter *)dateFormatter {
    if ( !_dateFormatter ) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        _dateFormatter.timeZone = [NSTimeZone localTimeZone];
        // We DON'T want localised strings in this case
        _dateFormatter.dateFormat = @"yyyy-MM-dd";
    }
    
    return _dateFormatter;
}
-(NSArray *)backupList {
    if ( !_backupList ) {
        _backupList = [self listBackups];
    }
    return _backupList;
}

-(NSNumber *)daysToKeep {
    if ( !_daysToKeep ) {
        _daysToKeep = @(14);
    }
    return _daysToKeep;
}


#pragma mark - Methods


-(NSString *)stringForDate:(NSDate *)date {
    
    
    // Currently, 9pm UTC
    
    // This is saying "Give me the point in absolute time where these components were true, and as if the time zone
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    calendar.timeZone = [NSTimeZone defaultTimeZone];
    NSDateComponents *localComponents = [calendar components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit )  fromDate:date];
    localComponents.calendar = calendar;
    
    NSString *dateString = [NSString stringWithFormat:@"%@-%@.%@", self.backupPrefix, [self.dateFormatter stringFromDate:[localComponents date]], VTABackupManagerFileExtenstion];
#if debugLog
    NSLog(@"%@", dateString);
#endif
    return dateString;
}


-(NSArray *)listBackups {
    
#if debugLog
    NSLog(@"Starting list update with sleep");
#endif
    
    
    NSMutableArray *mutableBackups = [[NSMutableArray alloc] init];
    NSArray *backups = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[[self backupDirectory] path] error:nil] ;
    mutableBackups = [backups mutableCopy];
    for ( NSString *path in backups ) {
        if ( ![[path pathExtension] isEqualToString:VTABackupManagerFileExtenstion] ) {
            [mutableBackups removeObject:path];
        }
    }
    
    
    [mutableBackups sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        // if obj1 > obj2 return (NSComparisonResult)NSOrderedDescending;
        NSURL *file1URL = obj1;
        NSURL *file2URL = obj2;
        NSString *file1Datestring = [[[file1URL lastPathComponent] stringByDeletingPathExtension] stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@-", self.backupPrefix] withString:@""];
        NSString *file2Datestring = [[[file2URL lastPathComponent] stringByDeletingPathExtension] stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@-", self.backupPrefix] withString:@""];
        NSDate *file1Date = [self.dateFormatter dateFromString:file1Datestring];
        NSDate *file2Date = [self.dateFormatter dateFromString:file2Datestring];
        
        //        NSString *backupPath = [[[path lastPathComponent] stringByDeletingPathExtension] stringByReplacingOccurrencesOfString:@"backup-" withString:@""];
        //        NSDate *backupDate = [self.dateFormatter dateFromString:backupPath];
        
        if ( [file1Date laterDate:file2Date] ) {
            return NSOrderedDescending;
        }
        if ( [file1Date earlierDate:file2Date] ) {
            return NSOrderedAscending;
        }
        return NSOrderedSame;
        
        NSDictionary *file1Atts = [[NSFileManager defaultManager] attributesOfItemAtPath:[[[self backupDirectory] URLByAppendingPathComponent:obj1] path] error:nil];
        NSDictionary *file2Atts = [[NSFileManager defaultManager] attributesOfItemAtPath:[[[self backupDirectory] URLByAppendingPathComponent:obj2] path] error:nil];
        if ( [[file1Atts objectForKey:NSFileCreationDate] laterDate:[file2Atts objectForKey:NSFileCreationDate]]) {
            return NSOrderedDescending;
        }
        if ( [[file1Atts objectForKey:NSFileCreationDate] earlierDate:[file2Atts objectForKey:NSFileCreationDate]]) {
            return NSOrderedDescending;
        }
        
        
        
        return NSOrderedSame;
    }];
    
    
    
    
    NSMutableArray *backupArray = [[NSMutableArray alloc] init];
    
    for (NSString *path in mutableBackups) {
        NSString *backupPath = [[[path lastPathComponent] stringByDeletingPathExtension] stringByReplacingOccurrencesOfString:@"backup-" withString:@""];
        NSDate *backupDate = [self.dateFormatter dateFromString:backupPath];
        NSArray *backupObjects = [NSArray arrayWithObjects:path,backupDate, nil];
        [backupArray addObject:backupObjects];
        
    }
    self.backupList = [backupArray copy];
    return backupArray;
}




#pragma mark - Backup

-(void)backupWithCompletionHandler:(void (^)(BOOL, NSError *))completion forceOverwrite:(BOOL)overwrite {
    [self backupWithCompletionHandler:completion forceOverwrite:overwrite recursive:YES];
}


-(void)backupWithCompletionHandler:(void (^)(BOOL success, NSError *error))completion forceOverwrite:(BOOL)overwrite recursive:(BOOL)recursive {
    
    
    // The URL for today's file
    NSURL *backupFileForToday = [self.backupDirectory URLByAppendingPathComponent:[self stringForDate:[NSDate date] ] ];
    
    // If we've already backed up today and we're not forcing an overwrite, we need go no further
    if ( !overwrite ) {
        if ( [[NSFileManager defaultManager] fileExistsAtPath:[backupFileForToday path]  ]) {
#if debugLog
            
            NSLog(@"File exists, overwrite not set. No action to perform. Returning.");
#endif
            return;
        } 
    }
    
    // Perform some sanity checking to prevent crashes
    if ( !self.context ) {
        NSDictionary *errorDictionary = @{NSLocalizedDescriptionKey : @"No NSManagedObjectContext found. Did you forget to set the context?"};
        NSError *error = [NSError errorWithDomain:VTABackupManagerErrorDomain code:NSCoreDataError  userInfo:errorDictionary];
        completion(NO, error);
        return;
    }
    if ( !self.entity ) {
        
        NSDictionary *errorDictionary = @{NSLocalizedDescriptionKey : @"No entity given to backup. Did you forget to set the entity name?"};
        NSError *error = [NSError errorWithDomain:VTABackupManagerErrorDomain code:NSCoreDataError  userInfo:errorDictionary];
        completion(NO, error);
        return;
    }
    
    // Post notification that we will begin backing up
    NSNotification *note = [NSNotification notificationWithName:VTABackupManagerWillProcessBackupsNotification object:self];
    [[NSNotificationCenter defaultCenter] postNotification:note];
    
    
    // Create our private queue context
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    context.persistentStoreCoordinator = self.context.persistentStoreCoordinator;

    [context performBlock:^{
        BOOL success = YES;
        NSError *error;

        // First, we need to create the directory
        [[NSFileManager defaultManager] createDirectoryAtPath:[self.backupDirectory path] withIntermediateDirectories:YES attributes:nil error:&error ];
        if ( error ) {
#if debugLog
            NSLog(@"Error creating directory: %@", [error localizedDescription]);
#endif      
        }
        
        // Delete any remaining backups, unless the old backups to delete is set to 0 or below
        if ( !self.daysToKeep || [self.daysToKeep intValue] < 1) {
            [self deleteOldBackups];
        }
        
#define VTAEncoderKey @"VTAEncoderKey"

        // Let's get everything from database for the given entity
        NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:self.entity.name];
        NSArray *results = [context executeFetchRequest:request error:&error];

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
            completion(success, error);
        });
        
    }];
    
    
}

-(void)deleteOldBackups {
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    calendar.timeZone = [NSTimeZone defaultTimeZone];
    NSDateComponents *localComponents = [calendar components:(NSDayCalendarUnit )  fromDate:[NSDate date]];
    localComponents.calendar = calendar;
    [localComponents setDay:-[self.daysToKeep intValue]];
    
    NSDate *twoWeeksAgo = [[NSCalendar currentCalendar] dateByAddingComponents:localComponents toDate:[NSDate date] options:0];
    
#if debugLog
    NSLog(@"Two weeks ago: %@", [self.dateFormatter stringFromDate:twoWeeksAgo]);
#endif
    
    for (NSArray *backupDetails in self.backupList ) {
        NSDate *fileDate = [backupDetails objectAtIndex:VTABackupManagerBackupListIndexDate];
        if ( [fileDate compare:twoWeeksAgo] == NSOrderedAscending ) {
#if debugLog
            NSLog(@"Deleting file at: %@", [backupDetails objectAtIndex:VTABackupManagerBackupListIndexPath]);
#endif
            NSError *error;
            [[NSFileManager defaultManager] removeItemAtPath:[[[self backupDirectory] URLByAppendingPathComponent:[backupDetails objectAtIndex:VTABackupManagerBackupListIndexPath]] path] error:&error];
            if ( error ) {
#if debugLog
                NSLog(@"%@", [error localizedDescription]);
#endif
            }
        }
    }
}

#pragma mark - Restore

-(void)restoreFromURL:(NSURL *)URL withCompletitionHandler:(void (^)(BOOL success, NSError *))completion {
//    NSData *fileData = [[NSMutableData alloc] initWithContentsOfFile:[URL path]];
//    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:fileData];
//    NSDictionary *myDictionary = [unarchiver decodeObjectForKey:VTAEncoderKey];
    
}


#pragma mark - Archiving the Managed Object

-(NSArray *)dataFromArrayOfManagedObjects:(NSArray *)objects Recursive:(BOOL)recursive {
    NSMutableArray *processedObjects = [[NSMutableArray alloc] init];
    if ( [objects count] > 0 ) {
        for (NSManagedObject *object in objects ) {
            [processedObjects addObject:[self dataStructureFromManagedObject:object recursive:recursive]];
        }
    }
    return processedObjects;
}

- (NSDictionary*)dataStructureFromManagedObject:(NSManagedObject*)managedObject recursive:(BOOL)recursive
{
    NSDictionary *attributesByName = [[managedObject entity] attributesByName];
    NSDictionary *relationshipsByName = [[managedObject entity] relationshipsByName];
    NSMutableDictionary *valuesDictionary = [[managedObject dictionaryWithValuesForKeys:[attributesByName allKeys]] mutableCopy];
    [valuesDictionary setObject:[[managedObject entity] name] forKey:@"ManagedObjectName"];
    
    if ( recursive ) {
        for (NSString *relationshipName in [relationshipsByName allKeys]) {
            NSRelationshipDescription *description = [[[managedObject entity] relationshipsByName] objectForKey:relationshipName];
            if (![description isToMany]) {
                NSManagedObject *relationshipObject = [managedObject valueForKey:relationshipName];
                // If the relationship is non-nil
                if ( relationshipObject ) {
                    [valuesDictionary setObject:[self dataStructureFromManagedObject:relationshipObject recursive:NO] forKey:relationshipName];
                }
                continue;
            }
            NSSet *relationshipObjects = [managedObject valueForKey:relationshipName];
            NSMutableArray *relationshipArray = [[NSMutableArray alloc] init];
            for (NSManagedObject *relationshipObject in relationshipObjects) {
                [relationshipArray addObject:[self dataStructureFromManagedObject:relationshipObject recursive:NO]];
            }
            [valuesDictionary setObject:relationshipArray forKey:relationshipName];
        }
    }
    return valuesDictionary;
}





@end
