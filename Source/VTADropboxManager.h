//
//  VTADropboxManager.h
//  trail wallet
//
//  Created by Simon Fairbairn on 26/06/2013.
//  Copyright (c) 2013 Voyage Travel Apps. All rights reserved.
//

#import <Dropbox/Dropbox.h>

#import "VTABackupManager.h"

extern NSString *VTABackupManagerDropboxAccountDidChangeNotification;
extern NSString *VTABackupManagerDropboxSyncStatusDidChangeNotification;
extern NSString *VTABackupManagerDropboxListDidChangeNotification;

#define VTABackupManagerDropboxAccountDidChange @"VTABackupManagerDropboxAccountDidChange"

#define VTABackupManagerDropboxAccountChangeKey @"VTABackupManagerDropboxAccountChangeKey"

/**
 *  Manages syncing between Dropbox and the VTABackupManager.
 *  Syncing is based on the date of the file creation
 */
@interface VTADropboxManager : VTABackupManager

/**
 *  A convenient shortcut to the DBAccountManager
 */
@property (nonatomic, strong) DBAccountManager *dropboxManager;

/**
 *  Set if the class is in the process of sycning
 */
@property (nonatomic, getter = isSyncing) BOOL syncing;

/**
 *  A property indicating whether or not cellular data should be used for syncing
 */
@property (nonatomic, getter = shouldUseCellular) BOOL useCellular;

/**
 *  A property indicating whether or not Dropbox is available
 */
@property (nonatomic, getter = isDropboxAvailable) BOOL dropboxAvailable;

@property (nonatomic) BOOL completedFirstSync;

@property (nonatomic) BOOL dropboxEnabled;

-(BOOL)canRestoreItem:(VTABackupItem *)item;

@end
