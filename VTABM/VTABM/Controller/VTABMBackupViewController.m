//
//  VTABMBackupViewController.m
//  VTABM
//
//  Created by Simon Fairbairn on 08/10/2013.
//  Copyright (c) 2013 Simon Fairbairn. All rights reserved.
//

#import <Dropbox/Dropbox.h>

#import "VTABMBackupViewController.h"
#import "VTABackupManager.h"
#import "VTABMStore.h"
#import "VTADropboxManager.h"

@interface VTABMBackupViewController () <UIAlertViewDelegate>

@property (nonatomic, strong) NSMutableArray *backupList;

@property (nonatomic, weak ) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

@property (nonatomic, strong) NSDateFormatter *dateFormatter;

@property (weak, nonatomic) IBOutlet UISwitch *dropboxSwitch;

@end

@implementation VTABMBackupViewController

#pragma mark - Properties

-(NSDateFormatter *)dateFormatter {
    if ( !_dateFormatter ) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.dateStyle = NSDateFormatterMediumStyle;
        _dateFormatter.timeStyle = NSDateFormatterNoStyle;
    }
    return _dateFormatter;
}

/**
 *  1. Lazily instantiated property that fetches all of the backups from the manager
 */
-(NSMutableArray *)backupList {
    if ( !_backupList ) {
        _backupList = [self sortBackups:[[VTADropboxManager sharedManager] allBackups]];
    }
    return _backupList;
}

#pragma mark - Methods

/**
 *  2. Optionally sort the backups (in this case by dateString).
 */
-(NSMutableArray *)sortBackups:(NSArray *)backups {
    NSSortDescriptor *dateStringSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"dateString" ascending:NO selector:@selector(localizedCaseInsensitiveCompare:)];
    return [[backups sortedArrayUsingDescriptors:@[dateStringSortDescriptor]] mutableCopy];
}

#pragma mark - View Lifecycle

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    /**
     *  3. Find out if Dropbox is enabled or not
     */
    self.dropboxSwitch.on = [VTADropboxManager sharedManager].dropboxEnabled;

    /**
     *  4. Subscribe to the relevant notifications
     */
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backupStateDidChange:) name:VTABackupManagerBackupStateDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dropboxAccountDidChange:) name:VTABackupManagerDropboxAccountDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dropboxAccountDidChange:) name:VTABackupManagerDropboxListDidChangeNotification object:nil];

    
    /**
     *  KVO on syncing
     */
    [[VTADropboxManager sharedManager] addObserver:self forKeyPath:@"syncing" options:0 context:nil];
    [[VTADropboxManager sharedManager] addObserver:self forKeyPath:@"dropboxAvailable" options:0 context:nil];
    
    // Get the activity indicator spinning.
    [self backupStateDidChange:nil];
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self checkNetwork];
}

-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Actions

-(IBAction)startBackup:(UIButton *)sender {
    
    self.tableView.userInteractionEnabled = NO;

    
    /**
     * 5.   To run a backup, call this method with a completion handler. The method will return a new backup item, together with
     *      a flag letting you know whether or not a file with the same name was overwritten. You can then update your local
     *      backup list reference and update the tableview.
     */
    [[VTADropboxManager sharedManager] backupEntityWithName:@"Cat"
                                                  inContext:[[VTABMStore sharedStore] context]
                                          completionHandler:^(BOOL success, NSError *error, VTABackupItem *item, BOOL didOverwrite) {
        NSString *message;
        NSString *title;
                                              
        if ( !error ) {
            if ( !didOverwrite ) {
                [self.backupList addObject:item];
                self.backupList = [self sortBackups:[self.backupList copy]];
                NSInteger index = [self.backupList indexOfObject:item];
                [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
            title = @"Backup Complete";
        } else {
            title = @"Error";
            message = [error localizedDescription];
        }
        [[[UIAlertView alloc] initWithTitle:title  message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
        self.tableView.userInteractionEnabled = YES;
    }
                                             forceOverwrite:YES];
}

-(IBAction)deleteStore:(UIButton *)sender {
    [[VTABMStore sharedStore] deleteStore];
}

- (IBAction)enableDropbox:(UISwitch *)sender {
    if ( sender.on ) {
        [[VTADropboxManager sharedManager].dropboxManager linkFromController:self];
    } else {
        [[[VTADropboxManager sharedManager].dropboxManager linkedAccount] unlink];
        [self.activityIndicator stopAnimating];
    }
}

#pragma mark - Notifications

/**
 *  Sent if the backup manager is performing a backup
 */
-(void)backupStateDidChange:(NSNotification *)note {
    if ( [VTADropboxManager sharedManager].isRunning || [VTADropboxManager sharedManager].isSyncing ) {
        [self.activityIndicator startAnimating];
    } else {
        [self.activityIndicator stopAnimating];
    }
}

/**
 *  Sent if the Dropbox account status changes
 */
-(void)dropboxAccountDidChange:(NSNotification *)note {
    self.backupList = [self sortBackups:[[VTADropboxManager sharedManager] allBackups]];
    [self.tableView reloadData];
}

#pragma mark - KVO

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    [self backupStateDidChange:nil];
    if ( [keyPath isEqualToString:@"dropboxAvailable"] ) {
        [self checkNetwork];
    }
}

-(void)checkNetwork {
    if ( [VTADropboxManager sharedManager].dropboxEnabled ) {
        if ( ![VTADropboxManager sharedManager].dropboxAvailable ) {
            [[[UIAlertView alloc] initWithTitle:@"Dropbox Unavailable" message:@"Syncing will resume when you next connect to a network" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
        }
    }
}

#pragma mark - UITableViewDataSource 


/**
 *  3. Use our own local array of backups to manage the table view. 
 */
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.backupList count];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"backupCell"];
    VTABackupItem *item = [self.backupList objectAtIndex:indexPath.row];
    cell.textLabel.text = [self.dateFormatter stringFromDate:item.dateStringAsDate];
    cell.detailTextLabel.text = item.deviceName;
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        VTABackupItem *item = [self.backupList objectAtIndex:indexPath.row];
        [self.backupList removeObject:item];
        [[VTADropboxManager sharedManager] deleteBackupItem:item];
        [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    VTABackupItem *backup = [self.backupList objectAtIndex:indexPath.row];
    [[VTADropboxManager sharedManager] restoreItem:backup
                           intoContext:[[VTABMStore sharedStore] context]
               withCompletitionHandler:^(BOOL success, NSError *error) {
        if ( error ) {
            
        } else {
            UIAlertView *view = [[UIAlertView alloc] initWithTitle:@"Restore Complete" message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
            [view show];
        }
    }];
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
