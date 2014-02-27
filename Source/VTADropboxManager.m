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

NSString *VTABackupManagerDropboxAccountDidChangeNotification = @"VTABackupManagerDropboxAccountDidChangeNotification";
NSString *VTABackupManagerDropboxSyncStatusDidChangeNotification = @"VTABackupManagerDropboxSyncStatusDidChangeNotification";
NSString *VTABackupManagerDropboxListDidChangeNotification = @"VTABackupManagerDropboxListDidChangeNotification";

@interface VTADropboxManager ()

@property (nonatomic, strong) DBFilesystem *system;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSMutableArray *dropboxBackups;

@property (nonatomic, strong) NSMutableArray *fileList;

@property (nonatomic, strong) NSMutableDictionary *fileTable;

/**
 *  Are we reachable?
 */
@property (nonatomic, strong) Reachability *hostReachability;

@end

@implementation VTADropboxManager {
    BOOL _restoreInProgress;
}

#pragma mark - Properties

-(DBAccountManager *)dropboxManager {
    if ( ![DBAccountManager sharedManager] ) {
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

-(void)setSyncing:(BOOL)syncing {
    _syncing = syncing;
    [[NSNotificationCenter defaultCenter] postNotificationName:VTABackupManagerDropboxSyncStatusDidChangeNotification object:nil];
}

-(void)setUseCellular:(BOOL)useCellular {
    _useCellular = useCellular;
    [self reachabilityChanged:nil];
}

-(NSMutableArray *)dropboxBackups {
    if (!_dropboxBackups ) {
        _dropboxBackups = [[NSMutableArray alloc] init];
    }
    return _dropboxBackups;
}

-(NSArray *)fileList {
    if ( !_fileList ) {
        _fileList = [[NSMutableArray alloc] init];
    }
    return _fileList;
}

-(NSMutableDictionary *)fileTable {
    if ( !_fileTable ) {
        _fileTable = [[NSMutableDictionary alloc] init];
    }
    return _fileTable;
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
            
            weakSelf.dropboxEnabled = account.linked;
            
            if ( account.linked ) {
                weakSelf.syncing = YES;
                [weakSelf setupFilesystem];
            } else {
                weakSelf.syncing = NO;
                [weakSelf.hostReachability stopNotifier];
                weakSelf.fileTable = nil;
                [super reloadBackups];
                [DBFilesystem setSharedFilesystem:nil];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:VTABackupManagerDropboxAccountDidChangeNotification object:nil];
        }];
    }
    return self;
}

#pragma mark - Methods

-(NSArray *)allBackups {
    if ( self.dropboxEnabled ) {
        return self.dropboxBackups;
    } else {
        return [super allBackups];
    }
}

-(void)setupFilesystem {
    
    // Start reachability
    _hostReachability = [Reachability reachabilityForInternetConnection];
    [self reachabilityChanged:nil];
    [_hostReachability startNotifier];
    
    // Set us up to be informed when the network status changes
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:_hostReachability];
    
    
    if ( [self.dropboxManager linkedAccount] && ![DBFilesystem sharedFilesystem]) {
        DBFilesystem *system = [[DBFilesystem alloc] initWithAccount:[self.dropboxManager linkedAccount]];
        [DBFilesystem setSharedFilesystem:system];
        
        if ( system.completedFirstSync ) {
            [self setupFiles];
            [system addObserver:self forPathAndChildren:[DBPath root] block:^{
                [self updateFiles];
            }];
        } else {
            __weak DBFilesystem *weakSystem = system;
            [system addObserver:self block:^{
                if ( weakSystem.completedFirstSync ) {

                    [weakSystem removeObserver:self];
                    [self setupFiles];
                    
                    [weakSystem addObserver:self forPathAndChildren:[DBPath root] block:^{
                        [self updateFiles];
                    }];
                    
                }
            }];
        }
    }
}

-(void)checkSyncStatus {

    BOOL localSyncing = NO;
    for (NSString *key in self.fileTable) {
        DBFile *file = [self.fileTable objectForKey:key];
        
        if ( !file.status.cached || file.newerStatus ) {
            localSyncing = YES;
        }
    }
    if ( !localSyncing ) {
        self.syncing = NO;
    }
}

-(void)setupFiles {
    
    self.syncing = YES;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^() {
        
        DBError *filesystemError;
        self.fileList = [[[DBFilesystem sharedFilesystem] listFolder:[DBPath root] error:&filesystemError] mutableCopy];
        
        self.dropboxBackups = [[NSMutableArray alloc] init];
        
        
        for (DBFileInfo *info in self.fileList) {
            VTABackupItem *item = [[VTABackupItem alloc] initWithURL:nil name:[[info.path stringValue] lastPathComponent]];
            [self.dropboxBackups addObject:item];
            
            [self trackDBFile:info fromItem:item];
        }
        
        /**
         *  Move any existing local backups to Dropbox
         */
        for ( VTABackupItem *item in [super allBackups] ) {
            [self sendItemToDropbox:item];
        }
        
        NSSortDescriptor *dateStringSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"dateString" ascending:NO selector:@selector(localizedCaseInsensitiveCompare:)];
        NSMutableArray *dropboxBackups = [[self.dropboxBackups sortedArrayUsingDescriptors:@[dateStringSortDescriptor]] mutableCopy];
        if ( [dropboxBackups count] > [self.backupsToKeep integerValue]) {
            for (NSInteger idx = [self.backupsToKeep integerValue]; idx < [dropboxBackups count]; idx++) {
                [self deleteBackupItem:[dropboxBackups objectAtIndex:idx]];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^() {
            [self checkSyncStatus];
            if ( filesystemError ) {
                [NSException raise:DBErrorDomain format:@"File system error: %@", [filesystemError localizedDescription]];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:VTABackupManagerDropboxListDidChangeNotification object:filesystemError];
        });
    });
}

-(void)trackDBFile:(DBFileInfo *)info fromItem:(VTABackupItem *)item  {
    DBError *openError;
    
    DBFile *file = [self.fileTable objectForKey:item.filePath];
    
    if ( !file || !file.open ) {
        file = [[DBFilesystem sharedFilesystem] openFile:info.path error:&openError];
    }

    if (!file) return;
    
    [self.fileTable setObject:file forKey:item.filePath];
    
    __weak DBFile *weakFile = file;
    [file addObserver:self block:^{
        
#if VTADropboxManagerDebugLog
//        NSLog(@"-----------------");
//        NSLog(@"File: %@", weakFile.info.path);
//        NSLog(@"Status: %@", weakFile.status);
//        NSLog(@"Cached: %i", weakFile.status.cached);
//        NSLog(@"Newer status: %@", weakFile.newerStatus);
//        NSLog(@"Cached: %i", weakFile.newerStatus.cached);
//        NSLog(@"-----------------");
#endif
        
        if ( weakFile.newerStatus ) {
            [weakFile update:nil];
        }
        if ( weakFile.status.cached && !weakFile.newerStatus ) {
            dispatch_async(dispatch_get_main_queue(), ^() {
                [self checkSyncStatus];
            });
        }
    }];
}

-(void)updateFiles {
    
    self.syncing = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^() {
        DBError *filesystemError;
        NSMutableArray *immContents = [[[DBFilesystem sharedFilesystem] listFolder:[DBPath root] error:&filesystemError] mutableCopy];
        
        NSMutableArray *addList = [immContents mutableCopy];
        NSMutableArray *deleteList = [self.fileList mutableCopy];
        
        [addList removeObjectsInArray:self.fileList];
        [deleteList removeObjectsInArray:immContents];
        
        NSMutableArray *localBackupList = [self.dropboxBackups mutableCopy];
        
        for ( DBFileInfo *addInfo in addList ) {
            VTABackupItem *item = [[VTABackupItem alloc] initWithURL:nil name:[[addInfo.path stringValue] lastPathComponent]];
            [self.dropboxBackups addObject:item];
            
            [self trackDBFile:addInfo fromItem:item];
        }
        [localBackupList enumerateObjectsUsingBlock:^(VTABackupItem *item, NSUInteger idx, BOOL *stop) {
            for ( DBFileInfo *deleteInfo in deleteList) {
                if ( [item.filePath isEqualToString:[[deleteInfo.path stringValue] lastPathComponent]]) {
                    [self.dropboxBackups removeObject:item];
                }
            }
        }];
        
        NSLog(@"------------------");
        NSLog(@"%@", self.fileList);
        NSLog(@"%@", self.fileTable);
        NSLog(@"%@", self.dropboxBackups);
        
        
        self.fileList = immContents;
        
        dispatch_async(dispatch_get_main_queue(), ^() {
            [self checkSyncStatus];
            if ( filesystemError ) {
                [NSException raise:DBErrorDomain format:@"File system error: %@", [filesystemError localizedDescription]];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:VTABackupManagerDropboxListDidChangeNotification object:filesystemError];
        });
    });
}


-(void)sendItemToDropbox:(VTABackupItem *)item {
    
    if ( !item ) {
        return;
    }
    
    self.syncing = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^() {
        
        DBError *fileError;
        DBError *writeError;
        DBError *openError;
        
        DBFile *file = [self.fileTable objectForKey:item.filePath];
        
        if ( !file || !file.open ) {
            file = [[DBFilesystem sharedFilesystem] openFile:[[DBPath root] childPath:item.filePath] error:&openError];
        }
        
        if ( !file ) {
            file = [[DBFilesystem sharedFilesystem] createFile:[[DBPath root] childPath:item.filePath]  error:&fileError];
        }
        
        if ( fileError ) {
            [NSException raise:DBErrorDomain format:@"Dropbox file error: %@", [fileError localizedDescription]];
        }
        
        if ( ![file writeContentsOfFile:[item.fileURL path] shouldSteal:YES error:&writeError] ) {
            [NSException raise:DBErrorDomain format:@"Couldn't write file: %@", [writeError localizedDescription]];
        } else {
//            [self.fileTable setObject:file forKey:item.filePath];
        }
    });
}

-(void)moveLocalFilesToDropbox {
    for ( VTABackupItem *localItem in [super allBackups] ) {
        [self sendItemToDropbox:localItem];
    }
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
        return YES;
    }
    return NO;
}

#pragma mark - new implementations

-(void)backupEntityWithName:(NSString *)name
                  inContext:(NSManagedObjectContext *)context
          completionHandler:(void (^)(BOOL, NSError *, VTABackupItem *newItem, BOOL didOverwrite))completion
             forceOverwrite:(BOOL)overwrite {
    [super backupEntityWithName:name inContext:context completionHandler:^(BOOL success, NSError *error, VTABackupItem *newItem, BOOL didOverwrite) {
        
        
        if ( self.dropboxEnabled ) {
            if ( !didOverwrite ) {
                [self sendItemToDropbox:newItem];
            }
        }
        
        completion(success, error, newItem, didOverwrite);
        if ( didOverwrite ) {
            [self moveLocalFilesToDropbox];
        }
    }  forceOverwrite:overwrite];
}


-(void)restoreItem:(VTABackupItem *)item intoContext:(NSManagedObjectContext *)context withCompletitionHandler:(void (^)(BOOL, NSError *))completion {
    
    if ( _restoreInProgress ) return;
    _restoreInProgress = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^() {

        VTABackupItem *localItem  = item;
        NSURL *localURL = item.fileURL;
        if ( self.dropboxEnabled ) {
            
            DBFile *file = [self.fileTable objectForKey:item.filePath];
            
            if ( !file || !file.open ) {
                file = [[DBFilesystem sharedFilesystem] openFile:[[DBPath root] childPath:item.filePath]  error:nil];
            }
            
            NSData *data = [file readData:nil];
            
            localURL = [[[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] objectAtIndex:0] URLByAppendingPathComponent:item.filePath];
            
            // Time to archive the results
            if ( ![data writeToFile:[localURL path]  atomically:YES] ) {
                NSLog(@"ERROR: Couldn’t write file");
            }
            localItem = [[VTABackupItem alloc] initWithURL:localURL name:item.fileName];
        }
        
  
        [super restoreItem:localItem intoContext:context withCompletitionHandler:^(BOOL success, NSError *error) {
            [[NSFileManager defaultManager] removeItemAtURL:localURL error:nil];
            _restoreInProgress = NO;
            completion(success, error);
        }];
    });
}

-(void)reachabilityChanged:(NSNotification *)note {
    
    if ( self.hostReachability.currentReachabilityStatus == 0 || (self.hostReachability.currentReachabilityStatus == 2 && !self.shouldUseCellular) ) {
        self.dropboxAvailable = NO;
        self.syncing = NO;
    } else {
        self.dropboxAvailable = YES;
    }
}

-(BOOL)deleteBackupItem:(VTABackupItem *)aItem {
    if ( self.dropboxEnabled ) {
        
        DBFile *file = [self.fileTable objectForKey:aItem.filePath];
        [file removeObserver:self];
        [file close];
        [self.fileTable removeObjectForKey:aItem.filePath];
        
        DBError *fileInfoError;
        DBFileInfo *item =        [[DBFilesystem sharedFilesystem] fileInfoForPath:[[DBPath root] childPath:aItem.filePath]  error:&fileInfoError];
        if ( fileInfoError ) {
            [NSException raise:NSInvalidArgumentException format:@"%@", [fileInfoError localizedDescription]];
        }
        
        DBError *deleteError;
        [[DBFilesystem sharedFilesystem] deletePath:item.path error:&deleteError];
        if ( deleteError ) {
            [NSException raise:NSInvalidArgumentException format:@"%@", [fileInfoError localizedDescription]];
        }
        return YES;
    } else {
        return [super deleteBackupItem:aItem];
    }
}

@end

