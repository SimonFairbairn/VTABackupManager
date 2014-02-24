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

#pragma mark - View Lifecycle

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.dropboxSwitch.on = [VTADropboxManager sharedManager].dropboxEnabled;
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Actions

-(IBAction)startBackup:(UIButton *)sender {
    
    self.tableView.userInteractionEnabled = NO;
    [self.activityIndicator startAnimating];
    
    [[VTADropboxManager sharedManager] backupEntityWithName:@"Cat" inContext:[[VTABMStore sharedStore] context] completionHandler:^(BOOL success, NSError *error, VTABackupItem *item, BOOL didOverwrite) {
        NSString *message;
        NSString *title;
        if ( !error ) {
            if ( !didOverwrite ) {
                NSInteger index = [[VTABackupManager sharedManager].backupList indexOfObject:item];                
                if ( index < [[VTABackupManager sharedManager].backupList count] ) {
                    [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
                }
            }
            title = @"Backup Complete";
        } else {
            title = @"Error";
            message = [error localizedDescription];
        }
        [[[UIAlertView alloc] initWithTitle:title  message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
        self.tableView.userInteractionEnabled = YES;
        [self.activityIndicator stopAnimating];
    } forceOverwrite:YES];
}

-(IBAction)deleteStore:(UIButton *)sender {
    [[VTABMStore sharedStore] deleteStore];
}

- (IBAction)enableDropbox:(UISwitch *)sender {
    if ( sender.on ) {
        [[VTADropboxManager sharedManager].dropboxManager linkFromController:self];
    } else {
        [[[VTADropboxManager sharedManager].dropboxManager linkedAccount] unlink];
    }
}

#pragma mark - UITableViewDataSource 

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[VTADropboxManager sharedManager].backupList count];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"backupCell"];
    VTABackupItem *item = [[VTADropboxManager sharedManager].backupList objectAtIndex:indexPath.row];
    cell.textLabel.text = [self.dateFormatter stringFromDate:item.dateStringAsDate];
    cell.detailTextLabel.text = item.deviceName;
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        VTABackupItem *item = [[VTADropboxManager sharedManager].backupList objectAtIndex:indexPath.row];
        [[VTADropboxManager sharedManager] deleteBackupItem:item];
        [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.activityIndicator startAnimating];
    VTABackupItem *backup = [[VTADropboxManager sharedManager].backupList objectAtIndex:indexPath.row];
    [[VTADropboxManager sharedManager] restoreItem:backup
                           intoContext:[[VTABMStore sharedStore] context]
               withCompletitionHandler:^(BOOL success, NSError *error) {
        if ( error ) {
            
        } else {
            UIAlertView *view = [[UIAlertView alloc] initWithTitle:@"Restore Complete" message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
            [view show];
            [self.activityIndicator stopAnimating];
            
        }

    }];
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
