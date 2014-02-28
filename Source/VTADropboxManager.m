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
    BOOL _loadingFiles;
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
        
        [system addObserver:self block:^() { [self reload]; }];
        [system addObserver:self forPathAndChildren:[DBPath root] block:^() { [self loadFiles]; }];
        [self loadFiles];
    }
}

-(void)reload {
    
#ifdef DEBUG
#if VTADropboxManagerDebugLog
    NSLog(@"%s called", __PRETTY_FUNCTION__);
#endif
#endif
    
    if ( [DBFilesystem sharedFilesystem].status & DBFileStateDownloading ) {
        
#ifdef DEBUG
#if VTADropboxManagerDebugLog
        NSLog(@"Downloading");
#endif
#endif
        
        self.syncing = YES;
    } else if ( [DBFilesystem sharedFilesystem].status & DBFileStateUploading ) {

#ifdef DEBUG
#if VTADropboxManagerDebugLog
        NSLog(@"Uploading");
#endif
#endif
        
        self.syncing = YES;
    } else {
        self.syncing = NO;
    }
    
    if ( self.dropboxEnabled && !self.dropboxAvailable ) {
        self.syncing = NO;
    }

}

-(void)loadFiles {
    
#ifdef DEBUG
#if VTADropboxManagerDebugLog
    NSLog(@"Load files called");
#endif
#endif
    
    if (_loadingFiles) {
        
#ifdef DEBUG
#if VTADropboxManagerDebugLog
        NSLog(@"Loading files already loading");
#endif
#endif
        
        return;
    }
    _loadingFiles = YES;
    self.syncing = YES;
    
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^() {
        
#ifdef DEBUG
#if VTADropboxManagerDebugLog
        NSLog(@"in background block");
#endif
#endif
        
        [super reloadBackups];
        /**
         *  Move any existing local backups to Dropbox
         */
        for ( VTABackupItem *item in [super allBackups] ) {
            [self sendItemToDropbox:item];
        }
        
#ifdef DEBUG
#if VTADropboxManagerDebugLog
        NSLog(@"Finished sending items");
#endif
#endif
        
        NSArray *immContents = [[DBFilesystem sharedFilesystem] listFolder:[DBPath root] error:nil];
        NSMutableArray *tempArray = [[NSMutableArray alloc] init];
        for (DBFileInfo *info in immContents) {
            VTABackupItem *item = [[VTABackupItem alloc] initWithURL:nil name:[[info.path stringValue] lastPathComponent]];
            [tempArray addObject:item];
        }
        
        NSSortDescriptor *dateStringSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"dateString" ascending:NO selector:@selector(localizedCaseInsensitiveCompare:)];
        NSMutableArray *dropboxBackups = [[tempArray sortedArrayUsingDescriptors:@[dateStringSortDescriptor]] mutableCopy];
        if ( (NSInteger)[dropboxBackups count] > [self.backupsToKeep integerValue]) {
            for (NSUInteger idx = [self.backupsToKeep integerValue]; idx < [dropboxBackups count]; idx++) {
                [self deleteBackupItem:[dropboxBackups objectAtIndex:idx]];
            }
        }
        

        
        dispatch_async(dispatch_get_main_queue(), ^() {
            
#ifdef DEBUG
#if VTADropboxManagerDebugLog
            NSLog(@"%@", tempArray);
#endif
#endif

            self.dropboxBackups = [[NSMutableArray alloc] initWithArray:tempArray];
            _loadingFiles = NO;
            self.syncing = NO;
            [self reload];
            [[NSNotificationCenter defaultCenter] postNotificationName:VTABackupManagerDropboxListDidChangeNotification object:nil];
        });
    });
}

-(BOOL)deleteBackupItem:(VTABackupItem *)aItem {
    if ( self.dropboxEnabled ) {
        
        DBError *fileInfoError;
        DBFileInfo *item = [[DBFilesystem sharedFilesystem] fileInfoForPath:[[DBPath root] childPath:aItem.filePath]  error:&fileInfoError];
        if ( fileInfoError ) {
            [NSException raise:NSInvalidArgumentException format:@"%@", [fileInfoError localizedDescription]];
        }
        
        DBError *deleteError;
        if ( [[DBFilesystem sharedFilesystem] deletePath:item.path error:&deleteError] ) {
            return YES;
        } else {
            return NO;
        }
    } else {
        return [super deleteBackupItem:aItem];
    }
}

-(void)sendItemToDropbox:(VTABackupItem *)item {
    
    if ( !item || !self.dropboxEnabled ) {
        return;
    }
    
    if ( [[NSFileManager defaultManager] fileExistsAtPath:[item.fileURL path] isDirectory:NO] ) {
        
#ifdef DEBUG
#if VTADropboxManagerDebugLog
        NSLog(@"File exists");
#endif
#endif
        
    }
        
        DBError *fileError;
        DBError *writeError;
        DBError *openError;
        
        DBFile *file = [[DBFilesystem sharedFilesystem] openFile:[[DBPath root] childPath:item.filePath] error:&openError];
        
        if ( !file ) {
            file = [[DBFilesystem sharedFilesystem] createFile:[[DBPath root] childPath:item.filePath]  error:&fileError];
        }
        
        if ( fileError ) {
            [NSException raise:DBErrorDomain format:@"Dropbox file error: %@", [fileError localizedDescription]];
        }
        
        if ( ![file writeContentsOfFile:[item.fileURL path] shouldSteal:YES error:&writeError] ) {
            [NSException raise:DBErrorDomain format:@"Couldn't write file: %@", [writeError localizedDescription]];
        }
    [file close];
}

#pragma mark - new implementations

-(void)backupEntityWithName:(NSString *)name
                  inContext:(NSManagedObjectContext *)context
          completionHandler:(void (^)(BOOL, NSError *, VTABackupItem *newItem, BOOL didOverwrite))completion
             forceOverwrite:(BOOL)overwrite {
    [super backupEntityWithName:name inContext:context completionHandler:^(BOOL success, NSError *error, VTABackupItem *newItem, BOOL didOverwrite) {
        
        
        if ( self.dropboxEnabled ) {
            [self sendItemToDropbox:newItem];
        }
        completion(success, error, newItem, didOverwrite);

    }  forceOverwrite:overwrite];
}


-(BOOL)canRestoreItem:(VTABackupItem *)item {
    DBFile *file = [[DBFilesystem sharedFilesystem] openFile:[[DBPath root] childPath:item.filePath]  error:nil];

    if ( !file ) return NO;
    
    BOOL canRestore = YES;
    
    if ( self.dropboxEnabled ) {
        if ( !self.dropboxAvailable && !file.status.cached ) {
            canRestore = NO;
        }
    }
    
    [file close];
    return canRestore;
}


-(void)restoreItem:(VTABackupItem *)item intoContext:(NSManagedObjectContext *)context withCompletitionHandler:(void (^)(BOOL, NSError *))completion {
    
    if ( _restoreInProgress ) {
        NSDictionary *errorDictionary = @{NSLocalizedDescriptionKey : @"A Restore is already in progress."};
        NSError *error = [NSError errorWithDomain:VTABackupManagerErrorDomain code:0 userInfo:errorDictionary];
        completion(NO, error);
        return;
    }
    _restoreInProgress = YES;
    self.syncing = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^() {
        
        VTABackupItem *localItem  = item;
        NSURL *localURL = item.fileURL;
        if ( self.dropboxEnabled ) {
            
            DBFile *file = [self.fileTable objectForKey:item.filePath];
            
            if ( !file || !file.open ) {
                file = [[DBFilesystem sharedFilesystem] openFile:[[DBPath root] childPath:item.filePath]  error:nil];
            }
            
#ifdef DEBUG
#if VTADropboxManagerDebugLog
            NSLog(@"Cached: %i", file.status.cached);
#endif
#endif
            
            if ( !self.dropboxAvailable && !file.status.cached  ) {
                NSDictionary *errorDictionary = @{NSLocalizedDescriptionKey : @"File not available offline. Please connect to the Internet and try again."};
                NSError *error = [NSError errorWithDomain:VTABackupManagerErrorDomain code:0 userInfo:errorDictionary];
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.syncing = NO;
                    _restoreInProgress = NO;
                    completion(NO, error);
                });
                return;
            }
            
            
            NSData *data = [file readData:nil];
            
            localURL = [[[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] objectAtIndex:0] URLByAppendingPathComponent:item.filePath];
            
            // Time to archive the results
            if ( ![data writeToFile:[localURL path]  atomically:YES] ) {
                
#ifdef DEBUG
#if VTADropboxManagerDebugLog
                NSLog(@"ERROR: Couldn’t write file");
#endif
#endif
                
            }
            
            localItem = [[VTABackupItem alloc] initWithURL:localURL name:item.fileName];
        }
        
        
        [super restoreItem:localItem intoContext:context withCompletitionHandler:^(BOOL success, NSError *error) {

            if ( self.dropboxEnabled ) {
                [[NSFileManager defaultManager] removeItemAtURL:localURL error:nil];
            }
            
            _restoreInProgress = NO;
            self.syncing = NO;
            completion(success, error);
        }];
    });
}

-(void)reachabilityChanged:(NSNotification *)note {
    
    if ( self.hostReachability.currentReachabilityStatus == 0 ) {
        self.dropboxAvailable = NO;
        self.syncing = NO;
    } else {
        self.dropboxAvailable = YES;
    }
}

-(BOOL)handleOpenURL:(NSURL *)url {
    DBAccount *account = [[DBAccountManager sharedManager] handleOpenURL:url];
    if (account) {
        return YES;
    }
    return NO;
}


@end

