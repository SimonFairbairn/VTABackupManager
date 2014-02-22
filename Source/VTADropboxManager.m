//
//  VTADropboxManager.m
//  trail wallet
//
//  Created by Simon Fairbairn on 26/06/2013.
//  Copyright (c) 2013 Voyage Travel Apps. All rights reserved.
//

#import "VTADropboxManager.h"
#import "VTABackupManager.h"
#import "DropboxCredentials.h"
#import "Reachability.h"

#define VTADropboxManagerDebugLog 1

@interface VTADropboxManager ()

@property (nonatomic, strong) DBFilesystem *system;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSArray *backupList;

@property (nonatomic) NSUInteger filesLeft;

@property (nonatomic, readwrite, getter = isDropboxEnabled) BOOL dropboxEnabled;

/**
 *  Are we reachable?
 */
@property (nonatomic, strong) Reachability *hostReachability;


@end

@implementation VTADropboxManager


#pragma mark - Properties

-(DBAccountManager *)dropboxManager {
    if ( ![DBAccountManager sharedManager] ) {
#if VTADropboxManagerDebugLog
        NSLog(@"Setting up Manager");
#endif
        DBAccountManager *manager = [[DBAccountManager alloc] initWithAppKey:VTABMDropboxKey secret:VTABMDropboxSecret];
        [DBAccountManager setSharedManager:manager];
    }
    return [DBAccountManager sharedManager];
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

#pragma mark - Initialisation

+ (instancetype)sharedManager {
    static dispatch_once_t predicate;
    static VTADropboxManager *instance = nil;
    dispatch_once(&predicate, ^{instance = [[self alloc] init];});
    return instance;
}

-(id)init {
    
    if ( self = [super init] ) {
        DBAccount *account = [self.dropboxManager linkedAccount];
        if ( account ) {
            _dropboxEnabled = YES;
            _syncing = YES;
            [self setupFilesystem];
        }

        __weak VTADropboxManager *weakSelf = self;
        
        [self.dropboxManager addObserver:self block: ^(DBAccount *account) {
            
            // reload backpup list
            
            weakSelf.dropboxEnabled = account.linked;
#if VTADropboxManagerDebugLog
            NSLog(@"Account is enabled: %i", weakSelf.dropboxEnabled);
            NSLog(@"Posting account changed notification");

#endif
            weakSelf.backupList = nil;
            weakSelf.syncing = account.linked;
            [[NSNotificationCenter defaultCenter] postNotificationName:VTABackupManagerDropboxAccountDidChange object:nil];
            
            if ( account.linked ) {
                [weakSelf setupFilesystem];
            } else {
                [weakSelf.hostReachability stopNotifier];
            }
        }];

        
    }
    return self;
}

#pragma mark - Methods

-(void)setupFilesystem {
    _hostReachability = [Reachability reachabilityForInternetConnection];
    [self reachabilityChanged:nil];
    [_hostReachability startNotifier];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:_hostReachability];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backupCompleted:) name:VTABackupManagerBackupDidCompleteNotification object:nil];
    
    
    if ( [self.dropboxManager linkedAccount] && ![DBFilesystem sharedFilesystem]) {
        DBFilesystem *system = [[DBFilesystem alloc] initWithAccount:[self.dropboxManager linkedAccount]];
        [DBFilesystem setSharedFilesystem:system];
        
#if VTADropboxManagerDebugLog
        NSLog(@"Enabling file system");
        NSLog(@"Posting file system will change notification");
#endif
        [[NSNotificationCenter defaultCenter] postNotificationName:VTABackupManagerFileListWillChangeNotification object:nil];
        
        [self fetchFiles];
        
        [system addObserver:self forPathAndChildren:[DBPath root] block:^{
            _syncing = YES;
#if VTADropboxManagerDebugLog
            NSLog(@"Files in the root path or one of its children changed.");
            NSLog(@"Syncing: %i", _syncing);
            NSLog(@"Posting file system will change notification");
#endif
            [[NSNotificationCenter defaultCenter] postNotificationName:VTABackupManagerFileListWillChangeNotification object:self];
            [self fetchFiles];

        }];
    }
}

-(void)fetchFiles {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^() {
        DBError *filesystemError;
        NSArray *immContents = [[DBFilesystem sharedFilesystem] listFolder:[DBPath root] error:&filesystemError];
        
#if VTADropboxManagerDebugLog
        //                NSLog(@"Found files: %@", immContents);
#endif
        
//        self.backupList = [NSMutableArray arrayWithArray:immContents];
        //                        [mContents sortUsingFunction:sortFileInfos context:NULL];
        
        NSMutableArray *downloadedFiles = [[NSMutableArray alloc] init];
        
        _syncing = NO;
        
        for (DBFileInfo *item in immContents) {
            DBError *fileReadError;
            DBFile *file = [[DBFilesystem sharedFilesystem] openFile:item.path error:&fileReadError];
            if ( fileReadError ) {
                NSLog(@"File Read Error: %@", [fileReadError localizedDescription]);
            } else {
                NSLog(@"Cached: %i", file.status.cached);
                NSLog(@"Status: %@", file.status);
                NSLog(@"Newer Status: %@", file.newerStatus);
                
                if ( file.status.cached && !file.newerStatus ) {
                    [file close];
                    [downloadedFiles addObject:item];
                } else {
                    DBError *updateError;
                    [file update:&updateError];
                    if ( updateError ) {
                        NSLog(@"Update error: %@", [updateError localizedDescription]);
                    }
                    [file addObserver:self block:^{
                        [self reloadFiles];
                    }];
                    
                    _syncing = YES;
                }
                
            }
        }
        self.backupList = [NSArray arrayWithArray:downloadedFiles];
        
        dispatch_async(dispatch_get_main_queue(), ^() {
            if ( filesystemError ) {
#if VTADropboxManagerDebugLog
                NSLog(@"Error: %@", [filesystemError localizedDescription]);
#endif
            }
            NSLog(@"Posting file system changed notification");
            [[NSNotificationCenter defaultCenter] postNotificationName:VTABackupManagerFileListDidChangeNotification object:filesystemError];
        });
    });
}

-(void)reloadFiles {
    DBError *filesystemError;
    NSArray *immContents = [[DBFilesystem sharedFilesystem] listFolder:[DBPath root] error:&filesystemError];
    NSLog(@"%@", immContents);
    
    
        dispatch_async(dispatch_get_main_queue(), ^() {
            [[NSNotificationCenter defaultCenter] postNotificationName:VTABackupManagerFileListDidChangeNotification object:nil];
            [self fetchFiles];
        });
}

-(void)updateStatus {
    
    DBAccount *account = [self.dropboxManager linkedAccount];
    if ( account ) {
        self.dropboxEnabled = YES;
    } else {
        self.dropboxEnabled = NO;
    }
}

-(BOOL)handleOpenURL:(NSURL *)url {
    DBAccount *account = [[DBAccountManager sharedManager] handleOpenURL:url];
    if (account) {
        NSLog(@"App linked successfully!");
        return YES;
    }
    return NO;
}

-(void)moveToDropbox:(NSNotificationCenter *)note {
    // Something on the local file system has changed, so we need to go through the backup array and move any new ones to Dropbox
}


#pragma mark - new implementations

-(void)backupEntityWithName:(NSString *)name
                  inContext:(NSManagedObjectContext *)context
          completionHandler:(void (^)(BOOL, NSError *))completion
             forceOverwrite:(BOOL)overwrite {
    self.syncing = self.dropboxEnabled;
    [[NSNotificationCenter defaultCenter] postNotificationName:VTABackupManagerFileListWillChangeNotification object:nil];
    [super backupEntityWithName:name inContext:context completionHandler:completion forceOverwrite:overwrite];
}

-(void)backupCompleted:(NSNotificationCenter *)note {
    
    
    if ( !self.dropboxEnabled ) {
        _syncing = NO;
        return;
    }
    
    NSArray *localBackups = self.backupList;
    
    NSLog(@"Local backups: %@", localBackups);
    
    for (VTABackupItem *item in localBackups ) {
        
        for ( DBFileInfo *info in self.backupList ) {
            if ( [[info.path stringValue] isEqualToString:[[[DBPath root] childPath:item.filePath] stringValue]] ) {
                DBError *deleteError;
                [[DBFilesystem sharedFilesystem] deletePath:[[DBPath root] childPath:item.filePath] error:&deleteError];
                if ( deleteError ) {
                    NSLog(@"Delete error: %@", [deleteError localizedDescription]);
                }
            }
            
//            if ( ![[info.path stringValue] isEqualToString:[[[DBPath root] childPath:item.filePath] stringValue]]) {
                DBError *fileError;
                DBFile *file = [[DBFilesystem sharedFilesystem] createFile:[[DBPath root] childPath:item.filePath]  error:&fileError];
                if ( fileError ) {
                    NSLog(@"File error: %@", [fileError localizedDescription]);
                    NSLog(@"File error: %@", [fileError localizedFailureReason]);
                    NSLog(@"File error: %@", [fileError localizedRecoverySuggestion]);
                    [self fetchFiles];
                } else {
                    DBError *writeError;
                    [file writeContentsOfFile:[item.fileURL path] shouldSteal:YES error:&writeError];
                    if ( writeError) {
                        NSLog(@"%@", [writeError localizedDescription]);
                    }
                }
//            }
        }
    }    
}

-(void)restoreFromURL:(NSURL *)URL
          intoContext:(NSManagedObjectContext *)context
withCompletitionHandler:(void (^)(BOOL, NSError *))completion {
    
}

-(void)reachabilityChanged:(NSNotification *)note {

    if ( self.hostReachability.currentReachabilityStatus == 0 || (self.hostReachability.currentReachabilityStatus == 2 && !self.shouldUseCellular) ) {
        _dropboxAvailable = NO;
        _syncing = NO;
    } else {
        _dropboxAvailable = YES;
        
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:VTABackupManagerDropboxNetworkDidChange object:nil];
}

-(BOOL)deleteBackupItem:(id)aItem {
    if ( self.dropboxEnabled ) {
        if ( [aItem isKindOfClass:[VTABackupItem class]] ) {
            return [super deleteBackupItem:aItem];
        }
        if ( [aItem isKindOfClass:[DBFileInfo class]] ) {
            DBFileInfo *item = (DBFileInfo *)aItem;
            DBError *deleteError;
            [[DBFilesystem sharedFilesystem] deletePath:item.path error:&deleteError];
            if ( deleteError ) {
                NSLog(@"%@", [deleteError localizedDescription]);
            }
            return YES;
        }
    } else {
        _syncing = NO;
        return [super deleteBackupItem:aItem];
    }
    

    return NO;
}

@end

