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


// Indexes for the information given in the backupList array
// 
enum VTABackupManagerBackupListIndex {
    VTABackupManagerBackupListIndexPath = 0,
    VTABackupManagerBackupListIndexDate = 1,
    VTABackupManagerBackupListIndexURL = 2
};

// Notifications
#define VTABackupManagerWillProcessBackupsNotification @"VTABackupManagerWillProcessBackupsNotification"
#define VTABackupManagerDidProcessBackupsNotification @"VTABackupManagerDidProcessBackupsNotification"

#define VTABackupManagerWillProcessRestoreNotification @"VTABackupManagerWillProcessRestoreNotification"
#define VTABackupManagerDidProcessRestoreNotification @"VTABackupManagerDidProcessRestoreNotification"


@interface VTABackupManager : NSObject

// The context to back up
@property (nonatomic, strong) NSManagedObjectContext *context;

// The entity name to back up. This method is recursive and will
// save all the relationship data
@property (nonatomic, strong) NSEntityDescription *entity;

// How many days of backups should be kept? 0 is unlimited.
@property (nonatomic, strong) NSNumber *daysToKeep;

// directory to backup to, defaults to <Documents directory>/backups/
@property (nonatomic, strong) NSURL *backupDirectory;

// The format of the backup name is `<backupPrefix>-<year>-<month>-<day>.vtabackup`
// The default backupPrefix is simply "backup"
// The year, month and day strings are all based on the gregorian calendar
@property (nonatomic, strong) NSString *backupPrefix;

// An array of URLs pointing to the backups
@property (nonatomic, readonly) NSArray *backupList;


// Designated initialiser
-(VTABackupManager *)initWithManagedObjectContext:(NSManagedObjectContext *)context entityToBackup:(NSEntityDescription *)entity;

// Run a backup with your own completition handler
// Backups run on a separate, parallel context with a private queue (so off the main thread)
// Completion blocks always run on the main thread.
//
// The method will pass a BOOL indicating whether or not the process was successful and
// an error object indicating the error if there was one.
-(void)backupWithCompletionHandler:(void (^)(BOOL success, NSError *error))completion forceOverwrite:(BOOL)overwrite;

// If you don't want it to be recursive, use this method and set the recursive flag to NO
-(void)backupWithCompletionHandler:(void (^)(BOOL success, NSError *error))completion forceOverwrite:(BOOL)overwrite recursive:(BOOL)recursive;

// Takes a backup path and attempts to restore the Core Data stack from it.
// Will empty the database before hand, so use with caution
//
// The method will pass a BOOL indicating whether or not the process was successful and
// an error object indicating the error if there was one.
-(void)restoreFromURL:(NSURL *)URL withCompletitionHandler:(void (^)(BOOL success, NSError *error))completion;


@end
