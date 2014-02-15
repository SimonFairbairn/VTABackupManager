//
//  VTADropboxManager.m
//  trail wallet
//
//  Created by Simon Fairbairn on 26/06/2013.
//  Copyright (c) 2013 Voyage Travel Apps. All rights reserved.
//

#import <Dropbox/Dropbox.h>

#import "VTADropboxManager.h"
#import "VTABackupManager.h"
#import "DropboxCredentials.h"

#define VTADropboxManagerDebugLog 1

@interface VTADropboxManager ()

@property (nonatomic, strong) DBAccountManager *manager;
@property (nonatomic, strong) DBFilesystem *system;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSArray *backupList;

@property (nonatomic, strong) NSMutableArray *toDropbox; // List of
@property (nonatomic, strong) NSMutableArray *fromDropbox; // List of DBFiles to copy

@property (nonatomic) NSUInteger filesLeft;

@property (nonatomic, readwrite, getter = isDropboxEnabled) BOOL dropboxEnabled;

@end

@implementation VTADropboxManager


#pragma mark - Properties

-(DBAccountManager *)manager {
    if ( !_manager ) {
        _manager = [DBAccountManager sharedManager];
    }
    
    return _manager;
}

-(NSMutableArray *) toDropbox {
    
    if ( !_toDropbox ) {
        _toDropbox = [[NSMutableArray alloc] init];
    }
    
    return _toDropbox;
}

-(NSMutableArray *) fromDropbox {
    
    if ( !_fromDropbox ) {
        _fromDropbox = [[NSMutableArray alloc] init];
    }
    
    return _fromDropbox;
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

-(Reachability *)hostReachability {
    if ( !_hostReachability ) {
        NSString *remoteHostName = @"www.apple.com";
        _hostReachability = [Reachability reachabilityWithHostName:remoteHostName];
    }
    return _hostReachability;
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
        DBAccount *account = [self.manager linkedAccount];
        if ( account ) {
            _dropboxEnabled = YES;
        }
        
        if ( account && ![DBFilesystem sharedFilesystem]) {
            DBFilesystem *system = [[DBFilesystem alloc] initWithAccount:account];
            [DBFilesystem setSharedFilesystem:system];
        }
        [self.hostReachability startNotifier];
        
    }
    return self;
}

#pragma mark - Methods

-(void)sync {
    
    if ( !self.dropboxEnabled ) {
#if VTADropboxManagerDebugLog
        NSLog(@"No linked account: Returning");
#endif
    }
    
    if ( self.syncing ) {
#if VTADropboxManagerDebugLog
        NSLog(@"Already syncing");
#endif
    }
    
    self.syncing = YES;
    
    if ( ![DBFilesystem sharedFilesystem] ) {
#if VTADropboxManagerDebugLog
        NSLog(@"File system not initialised. Returning.");
#endif
    }
    
    // If the account hasn't synced yet, then we need to call ourself again when it has.
    if ( ![DBFilesystem sharedFilesystem].completedFirstSync ) {
        [[DBFilesystem sharedFilesystem] addObserver:self block:^{

#if VTADropboxManagerDebugLog
            NSLog(@"File system not synced yet. Adding block to retry");
#endif
            
            self.syncing = NO;
            [self sync];
            [[DBFilesystem sharedFilesystem] removeObserver:self];
        }];
        return;
    }
    
#if VTADropboxManagerDebugLog
    NSLog(@"First sync complete. Beginning file sync process");
#endif
    
    NSString *remoteHostName = @"www.apple.com";
	Reachability *hostReachability = [Reachability reachabilityWithHostName:remoteHostName];
	[hostReachability startNotifier];
    
    if ( ( [[NSUserDefaults standardUserDefaults] boolForKey:TrailWalletBackupShouldUseCellularDataPrefKey] && [hostReachability currentReachabilityStatus] == ReachableViaWWAN ) || [hostReachability currentReachabilityStatus] == ReachableViaWiFi ) {
        
    }
    
    
    
    [[NSNotificationCenter defaultCenter] postNotificationName:VTADropboxManagerWillStartSyncNotification object:self];
    
    dispatch_queue_t request_queue = dispatch_queue_create("dropbox_list_thread", NULL);
    dispatch_async(request_queue, ^{

        // Step 1: Get the Dropbox file list and delete any that have been marked locally as deleted
        [self removeDeletedFiles];
        
        // Step 2: Sort the Dropbox files by their date and delete the oldest ones that belong to this device
        DBError *error;

        NSArray *dropboxFileList = [[DBFilesystem sharedFilesystem] listFolder:[DBPath root] error:&error];

        if ( error ) {
#if VTADropboxManagerDebugLog
            NSLog(@"Error: %@", [error localizedDescription]);
#endif
        }
        
#if VTADropboxManagerDebugLog
        NSLog(@"List of Dropbox Files: %@", dropboxFileList);
#endif
        
        NSString *deviceUUID = [VTABackupItem deviceUUID];
        
        NSIndexSet *indexSet = [dropboxFileList indexesOfObjectsPassingTest:^BOOL(DBFileInfo *info, NSUInteger idx, BOOL *stop) {

            if ( [[info.path stringValue] rangeOfString:deviceUUID].location != NSNotFound || [[info.path stringValue] rangeOfString:@"backup-"].location != NSNotFound ) {
                return NO;
            }
            return YES;
        }];
        
        NSMutableArray *arrayOfSortedFiles = [dropboxFileList mutableCopy];
        [arrayOfSortedFiles removeObjectsAtIndexes:indexSet];
        
        NSArray *sortedArray = [arrayOfSortedFiles sortedArrayUsingComparator:^NSComparisonResult(DBFileInfo *obj1, DBFileInfo *obj2) {
            NSRange stringRange;
            stringRange.location = 1;
            stringRange.length = 10;
            NSString *dateString1 = [[[obj1.path stringValue] stringByReplacingOccurrencesOfString:@"backup-" withString:@""] substringWithRange:stringRange];
            NSString *dateString2 = [[[obj2.path stringValue] stringByReplacingOccurrencesOfString:@"backup-" withString:@""] substringWithRange:stringRange];
            return [dateString2 compare:dateString1 options:NSCaseInsensitiveSearch];
        }];
        
#if VTADropboxManagerDebugLog
        NSLog(@"Array of sorted files: %@", [sortedArray valueForKeyPath:@"path"]);
#endif
        arrayOfSortedFiles = [sortedArray mutableCopy];
        
        NSArray *filesToDelete;
        if ( (int)[arrayOfSortedFiles count] > [[VTABackupManager sharedManager].backupsToKeep intValue] ) {
            NSRange arrayrange;
            arrayrange.location = 0;
            arrayrange.length = [[VTABackupManager sharedManager].backupsToKeep intValue];
            [arrayOfSortedFiles removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:arrayrange]];
            filesToDelete = [arrayOfSortedFiles copy];
#if VTADropboxManagerDebugLog
            NSLog(@"Array of files to delete: %@", filesToDelete);
#endif
        }
        
        for ( DBFileInfo *info in filesToDelete ) {
#if VTADropboxManagerDebugLog
            NSLog(@"Deleting Dropbox file at path: %@", info.path);
#endif
            DBError *deleteError;
            [[DBFilesystem sharedFilesystem] deletePath:info.path error:&deleteError];
            if ( deleteError ) {
                
#if VTADropboxManagerDebugLog
                NSLog(@"Error deleting: %@", [deleteError localizedDescription]);
#endif

            }
        }
        
        // Step 3: Copy any to the local file system that don't already exist there.
        dropboxFileList = [[DBFilesystem sharedFilesystem] listFolder:[DBPath root] error:&error];
        NSArray *localFileList = [VTABackupManager sharedManager].backupList;


        
#if VTADropboxManagerDebugLog
        NSLog(@"Local file list: %@", localFileList);
#endif
        NSMutableArray *notPresentOnDropbox = [localFileList mutableCopy];
        NSMutableArray *notPresentLocally = [dropboxFileList mutableCopy];
        
        for ( DBFileInfo *info in dropboxFileList ) {
            NSString *path = [[info.path stringValue] stringByReplacingOccurrencesOfString:@"/" withString:@""];
            
            for ( VTABackupItem *item in localFileList ) {
                if ( [path isEqualToString:item.filePath] ) {
                    [notPresentOnDropbox removeObject:item];
                    [notPresentLocally removeObject:info];
                    break;
                }
            }
        }
        
#if VTADropboxManagerDebugLog
        NSLog(@"Not present on Dropbox: %@", notPresentOnDropbox);
        for ( DBFileInfo *info in notPresentLocally ) {
            NSLog(@"Not present Locally: %@", info.path);
        }
#endif
        
        self.filesLeft = [notPresentOnDropbox count] + [notPresentLocally count];
        
        for (VTABackupItem *fileDetails in notPresentOnDropbox) {
            
            DBPath *path = [[DBPath alloc] initWithString:fileDetails.filePath];
            DBError *error;
            DBFile *newFile = [[DBFilesystem sharedFilesystem] createFile:path error:&error];
            
            if ( error ) {
#if VTADropboxManagerDebugLog
                NSLog(@"Error creating Dropbox file: %@", [error localizedDescription]);
#endif
            } else {
                DBError *error;
                NSData *data = [NSData dataWithContentsOfURL:fileDetails.fileURL];
                [newFile writeData:data error:&error];
                
                if ( error ) {
#if VTADropboxManagerDebugLog
                    NSLog(@"Error writing file to Dropbox: %@", [error localizedDescription]);
#endif
                } else {
#if VTADropboxManagerDebugLog
                    NSLog(@"File with path %@ written successfully", fileDetails.filePath);
#endif
                }
            }
        }
        
        for (DBFileInfo *fileInfo in notPresentLocally ) {
            
            DBError *error;
            DBFile *file = [[DBFilesystem sharedFilesystem] openFile:fileInfo.path error:&error];
            
            if ( error ) {
#if VTADropboxManagerDebugLog
                NSLog(@"Error with file: %@: %@", fileInfo.path, [error localizedDescription]);
#endif
                continue;
            } else {
#if VTADropboxManagerDebugLog
                NSLog(@"Beginning download");
#endif
                
                DBError *error;
                NSFileHandle *handle = [file readHandle:&error];
                
                if ( error ) {
#if VTADropboxManagerDebugLog
                    NSLog(@"Error with file: %@: %@", fileInfo.path, [error localizedDescription]);
#endif
                    continue;
                } else {
                    NSString *path = [[[VTABackupManager sharedManager].backupDirectory URLByAppendingPathComponent:[[fileInfo.path stringValue] stringByReplacingOccurrencesOfString:@"/" withString:@""]] path];
#if VTADropboxManagerDebugLog
                    NSLog(@"Moving file from Dropbox: %@", path);
#endif
                    
                    if ( ![[NSFileManager defaultManager] createFileAtPath:path contents:[handle availableData] attributes:nil] ) {
#if VTADropboxManagerDebugLog
                        NSLog(@"Error writing file at path: %@", path);
#endif
                    }
                }
            }
        }
        

        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"Syncing complete. Posting notification on main queue");
            self.syncing = NO;
            [[VTABackupManager sharedManager] reloadDirectory];
            [[NSNotificationCenter defaultCenter] postNotificationName:VTADropboxManagerDidFinishSyncNotification object:self];

        });
    });
}

-(void)removeDeletedFiles {

    DBError *error;
    NSArray *dropboxFileList = [[DBFilesystem sharedFilesystem] listFolder:[DBPath root] error:&error];
    
    NSURL *backupDirectory = [[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] objectAtIndex:0] URLByAppendingPathComponent:@"backups" isDirectory:YES];
    NSArray *backups = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:backupDirectory includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"path CONTAINS[cd] 'toDelete'"];
    backups = [backups filteredArrayUsingPredicate:predicate];
    
#if VTADropboxManagerDebugLog
    NSLog(@"Files To Delete on Dropbox: %@", backups);
#endif
    
    
    for ( DBFileInfo *file in dropboxFileList ) {
        NSString *fileString = [[[file.path stringValue] stringByReplacingOccurrencesOfString:@"/" withString:@""] stringByAppendingString:@".toDelete"];
        [backups enumerateObjectsUsingBlock:^(NSURL *obj, NSUInteger idx, BOOL *stop) {
            
#if VTADropboxManagerDebugLog
            NSLog(@"DBfile: %@", file.path);
            NSLog(@"Local file: %@", [obj lastPathComponent]);
#endif
            
            if ( [fileString isEqualToString:[obj lastPathComponent]] ) {
                DBError *deleteError;
                
#if VTADropboxManagerDebugLog
                NSLog(@"Deleting file at path: %@", file.path);
                NSLog(@"Deleting local file at URL: %@", obj);
#endif
                [[DBFilesystem sharedFilesystem] deletePath:file.path error:&deleteError];
                if ( deleteError ) {
                    NSLog(@"%@", [deleteError localizedDescription]);
                } else {
                    [[VTABackupManager sharedManager] deleteBackupAtURL:obj];
                }
            }
        }];
    }
    
}

-(void)deleteBackupAtURL:(NSURL *)url {
    if ( self.isDropboxEnabled ) {
        [[NSFileManager defaultManager] moveItemAtURL:url toURL:[url URLByAppendingPathExtension:@"toDelete"] error:nil];
        [[VTABackupManager sharedManager] reloadDirectory];
    } else {
        [[VTABackupManager sharedManager] deleteBackupAtURL:url];
    }
}

-(void)updateStatus {

    DBAccount *account = [self.manager linkedAccount];
    if ( account ) {
        self.dropboxEnabled = YES;
    } else {
        self.dropboxEnabled = NO;
    }
}

@end

