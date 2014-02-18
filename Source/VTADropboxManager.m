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

#define VTADropboxManagerDebugLog 1

@interface VTADropboxManager ()

@property (nonatomic, strong) DBFilesystem *system;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSArray *backupList;

@property (nonatomic, strong) NSMutableArray *toDropbox; // List of
@property (nonatomic, strong) NSMutableArray *fromDropbox; // List of DBFiles to copy

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
        NSLog(@"Setting up Manager");
        DBAccountManager *manager = [[DBAccountManager alloc] initWithAppKey:VTABMDropboxKey secret:VTABMDropboxSecret];
        [DBAccountManager setSharedManager:manager];
    }
    return [DBAccountManager sharedManager];
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
        DBAccount *account = [self.dropboxManager linkedAccount];
        if ( account ) {
            _dropboxEnabled = YES;
        }
        
        if ( account && ![DBFilesystem sharedFilesystem]) {
            DBFilesystem *system = [[DBFilesystem alloc] initWithAccount:account];
            [DBFilesystem setSharedFilesystem:system];
            [system addObserver:self block:^{
                NSLog(@"Dropbox file system changed");
            }];
        }
        [self.hostReachability startNotifier];
        
    }
    return self;
}

#pragma mark - Methods

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
          completionHandler:(void (^)(BOOL, NSError *))completion
             forceOverwrite:(BOOL)overwrite {
    [super backupEntityWithName:name inContext:context completionHandler:completion forceOverwrite:overwrite];
}

-(void)restoreFromURL:(NSURL *)URL
          intoContext:(NSManagedObjectContext *)context
withCompletitionHandler:(void (^)(BOOL, NSError *))completion {
    
}

@end

