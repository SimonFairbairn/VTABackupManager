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

@property (nonatomic) NSUInteger filesLeft;



/**
 *  Are we reachable?
 */
@property (nonatomic, strong) Reachability *hostReachability;

@end

@implementation VTADropboxManager {

}

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

#if VTADropboxManagerDebugLog
            NSLog(@"Account is enabled: %i", weakSelf.dropboxEnabled);
            NSLog(@"Posting account changed notification");
#endif
            [[NSNotificationCenter defaultCenter] postNotificationName:VTABackupManagerDropboxAccountDidChangeNotification object:nil];
            
            if ( account.linked ) {
                weakSelf.syncing = YES;
                [weakSelf setupFilesystem];
            } else {
                weakSelf.syncing = NO;
                [weakSelf.hostReachability stopNotifier];
                [DBFilesystem setSharedFilesystem:nil];
            }
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
        
#if VTADropboxManagerDebugLog
        NSLog(@"Enabling file system");
#endif
        
        if ( system.completedFirstSync ) {
            NSLog(@"First sync already completed. Fetching files.");

            [self setupFiles];
            
            [system addObserver:self forPathAndChildren:[DBPath root] block:^{

#if VTADropboxManagerDebugLog
                NSLog(@"Completed first sync observer: in the root path or one of its children changed.");
#endif

                [self updateFiles];
                
            }];
        } else {
            __weak DBFilesystem *weakSystem = system;
            [system addObserver:self block:^{
                if ( weakSystem.completedFirstSync ) {
                    NSLog(@"Completed first sync. Fetching files.");
                    [weakSystem removeObserver:self];

                    [self setupFiles];
                    
                    [weakSystem addObserver:self forPathAndChildren:[DBPath root] block:^{
#if VTADropboxManagerDebugLog
                        NSLog(@"System not ready observer: path or one of its children changed.");
#endif

                        [self updateFiles];
                        
                    }];
                    
                }
            }];
        }

    }
}

-(void)setupFiles {

    self.syncing = YES;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^() {
    
        DBError *filesystemError;
        self.fileList = [[[DBFilesystem sharedFilesystem] listFolder:[DBPath root] error:&filesystemError] mutableCopy];
        
#if VTADropboxManagerDebugLog
        NSLog(@"Initial files: %@", self.fileList);
#endif
      
        self.dropboxBackups = [[NSMutableArray alloc] init];
        
        for (DBFileInfo *info in self.fileList) {
            VTABackupItem *item = [[VTABackupItem alloc] initWithURL:nil name:[[info.path stringValue] lastPathComponent]];
            [self.dropboxBackups addObject:item];
        }
        
        for ( VTABackupItem *item in [super allBackups] ) {
            [self sendItemToDropbox:item];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^() {
            if ( filesystemError ) {
#if VTADropboxManagerDebugLog
                NSLog(@"Error: %@", [filesystemError localizedDescription]);
#endif
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:VTABackupManagerDropboxListDidChangeNotification object:filesystemError];
        });
    });
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
        }
        [localBackupList enumerateObjectsUsingBlock:^(VTABackupItem *item, NSUInteger idx, BOOL *stop) {
            for ( DBFileInfo *deleteInfo in deleteList) {
                if ( [item.filePath isEqualToString:[[deleteInfo.path stringValue] lastPathComponent]]) {
                    [self.dropboxBackups removeObject:item];
                }
            }
        }];
        
        dispatch_async(dispatch_get_main_queue(), ^() {
            if ( filesystemError ) {
#if VTADropboxManagerDebugLog
                NSLog(@"Error: %@", [filesystemError localizedDescription]);
                NSLog(@"Posting file system changed notification");
#endif
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:VTABackupManagerDropboxListDidChangeNotification object:filesystemError];
        });
    });
}


-(void)sendItemToDropbox:(VTABackupItem *)item {

#if VTADropboxManagerDebugLog
    NSLog(@"Sending item to Dropbox: %@", item);
#endif
    
    if ( !item ) {
        return;
    }
    
    self.syncing = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^() {
       
        DBError *fileError;
        DBError *writeError;
        DBError *openError;
        
        DBFile *file = [[DBFilesystem sharedFilesystem] openFile:[[DBPath root] childPath:item.filePath] error:&openError];
        
        if ( !file ) {
            file = [[DBFilesystem sharedFilesystem] createFile:[[DBPath root] childPath:item.filePath]  error:&fileError];
        }
        
        if ( fileError ) {
            NSLog(@"%@", [fileError localizedDescription]);
        }
        
        [file writeContentsOfFile:[item.fileURL path] shouldSteal:YES error:&writeError];
        
        if ( writeError) {
            NSLog(@"%@", [writeError localizedDescription]);
            [NSException raise:DBErrorDomain format:@"Couldn't write file: %@", [writeError localizedDescription]];
        }
        
        __weak DBFile *weakFile = file;
        [file addObserver:self block:^{
            NSLog(@"%@", weakFile.status);
            NSLog(@"Progress: %f", weakFile.status.progress);
            NSLog(@"Newer %@", weakFile.newerStatus);
            NSLog(@"Newer Progress: %f", weakFile.newerStatus.progress);
        }];
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
        NSLog(@"App linked successfully!");
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
        
        if ( didOverwrite ) {
            [self moveLocalFilesToDropbox];
        } else {
            [self sendItemToDropbox:newItem];
        }
        

        completion(success, error, newItem, didOverwrite);
    }  forceOverwrite:overwrite];
}


-(void)restoreItem:(VTABackupItem *)item intoContext:(NSManagedObjectContext *)context withCompletitionHandler:(void (^)(BOOL, NSError *))completion {

    DBFile *file = [[DBFilesystem sharedFilesystem] openFile:[[DBPath root] childPath:item.filePath]  error:nil];
    NSData *data = [file readData:nil];
    
    NSURL *localURL = [[[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] objectAtIndex:0] URLByAppendingPathComponent:item.filePath];
    
    // Time to archive the results
    if ( ![data writeToFile:[localURL path]  atomically:YES] ) {
        NSLog(@"ERROR: Couldn’t write file");
    }
    VTABackupItem *localItem = [[VTABackupItem alloc] initWithURL:localURL name:item.fileName];
    
    [super restoreItem:localItem intoContext:context withCompletitionHandler:^(BOOL success, NSError *error) {
        [[NSFileManager defaultManager] removeItemAtURL:localURL error:nil];
        completion(success, error);
    }];
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
        
        DBError *fileInfoError;
        DBFileInfo *item =        [[DBFilesystem sharedFilesystem] fileInfoForPath:[[DBPath root] childPath:aItem.filePath]  error:&fileInfoError];
        if ( fileInfoError ) {
            [NSException raise:NSInvalidArgumentException format:@"%@", [fileInfoError localizedDescription]];
        }
        DBError *deleteError;
        [[DBFilesystem sharedFilesystem] deletePath:item.path error:&deleteError];
        if ( deleteError ) {
            [NSException raise:NSInvalidArgumentException format:@"%@", [fileInfoError localizedDescription]];
            NSLog(@"%@", [deleteError localizedDescription]);
        }
        return YES;
    } else {
        return [super deleteBackupItem:aItem];
    }
}

@end

