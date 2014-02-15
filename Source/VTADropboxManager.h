//
//  VTADropboxManager.h
//  trail wallet
//
//  Created by Simon Fairbairn on 26/06/2013.
//  Copyright (c) 2013 Voyage Travel Apps. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Reachability.h"

#define VTADropboxManagerWillStartSyncNotification @"VTADropboxManagerWillStartSyncNotification"
#define VTADropboxManagerDidFinishSyncNotification @"VTADropboxManagerDidFinishSyncNotification"

/**
 *  Manages syncing between Dropbox and the VTABackupManager.
 *  Syncing is based on the date of the file creation
 */
@interface VTADropboxManager : NSObject

/**
 *  Is Dropbox hooked up for this user?
 */
@property (nonatomic, readonly, getter = isDropboxEnabled) BOOL dropboxEnabled;


/**
 *  Are we reachable?
 */
@property (nonatomic, strong) Reachability *hostReachability;

/**
 *  Set if the class is in the process of sycning
 */
@property (nonatomic, getter = isSyncing) BOOL syncing;

/**
 *  A property indicating whether or not cellular data should be used for syncing
 */
@property (nonatomic, getter = shouldUseCellular) BOOL useCellular;

/**
 *  Accessor for the singleton
 *
 *  @return An instance of a VTADropboxManager
 */
+(instancetype)sharedManager;

/**
 *  Start the sync process
 */
-(void)sync;

/**
 *  Forwarding method
 *
 *  @param url The URL of the local file
 */
-(void)deleteBackupAtURL:(NSURL *)url;

-(void)updateStatus;

@end
