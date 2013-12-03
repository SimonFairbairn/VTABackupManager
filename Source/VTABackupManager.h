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

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "VTABackupItem.h"

// Notifications
#define VTABackupManagerWillProcessBackupsNotification @"VTABackupManagerWillProcessBackupsNotification"
#define VTABackupManagerDidProcessBackupsNotification @"VTABackupManagerDidProcessBackupsNotification"

#define VTABackupManagerWillProcessRestoreNotification @"VTABackupManagerWillProcessRestoreNotification"
#define VTABackupManagerDidProcessRestoreNotification @"VTABackupManagerDidProcessRestoreNotification"

@interface VTABackupManager : NSObject

/**
 *  How many total backups to keep.
 */
@property (nonatomic, strong) NSNumber *backupsToKeep;

/**
 *  Directory to backup to, defaults to <Documents directory>/backups/
 */
@property (nonatomic, strong) NSURL *backupDirectory;

/**
 *  The format of the backup name is `<device>--<UUID>.<backupExtenstion>`
 *  The default extension is 'vtabackup'
 *  The year, month and day strings are all based on the gregorian calendar
 */
@property (nonatomic, strong) NSString *backupExtension;

/**
 *  An array of VTABackupItems representing the backups
 */
@property (nonatomic, readonly) NSArray *backupList;

/**
 *  Indicates whether the backup manager is running or not
 */
@property (nonatomic, readonly, getter = isRunning) BOOL running;


/**
 *  Gets the shared instance
 *
 *  @return A shared instance of VTABackupManager
 */
+(instancetype)sharedManager;

/**
 *  Run a backup with your own completition handler
 *  Backups run on a separate, parallel context with a private queue (so off the main thread)
 *  Completion blocks always run on the main thread.
 *
 *  The method will pass a BOOL indicating whether or not the process was successful and
 *  an error object indicating the error if there was one.
 *
 *  @param name       The name of the entity to back up
 *  @param context    An instance of NSManagedObjectContext
 *  @param completion A handler that runs on completition
 *  @param overwrite  Whether to force an overwrite of a file with the same name
 */
-(void)backupEntityWithName:(NSString *)name
                  inContext:(NSManagedObjectContext *)context
          completionHandler:(void (^)(BOOL success, NSError *error))completion
             forceOverwrite:(BOOL)overwrite;

/**
 *  Backs up the given entity. If you don't want it to be recursive, use this method and set the recursive flag to NO
 *
 *  @param name       The name of the entity to back up
 *  @param context    An instance of NSManagedObjectContext
 *  @param completion A handler that runs on completition
 *  @param overwrite  Whether to force an overwrite of a file with the same name
 *  @param recursive  Whether to recursively back up entity relationships
 */
-(void)backupEntityWithName:(NSString *)name
                  inContext:(NSManagedObjectContext *)context
          completionHandler:(void (^)(BOOL success, NSError *error))completion
             forceOverwrite:(BOOL)overwrite
                  recursive:(BOOL)recursive;

/**
 *  Delete the backup at the given URL, YES if successful NO otherwise
 *
 *  @param URL The URL of the backup to delete
 *
 *  @return YES if successfully deleted, NO otherwise
 */
-(BOOL)deleteBackupAtURL:(NSURL *)URL;

// Takes a backup path and attempts to restore the Core Data stack from it.
// Will empty the database before hand, so use with caution
//
// The method will pass a BOOL indicating whether or not the process was successful and
// an error object indicating the error if there was one.
-(void)restoreFromURL:(NSURL *)URL
          intoContext:(NSManagedObjectContext *)context
withCompletitionHandler:(void (^)(BOOL success, NSError *error))completion;


/**
 *  Forces the reload of the backupList array.
 */
-(void)reloadDirectory;


@end
