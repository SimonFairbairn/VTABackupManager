//
//  VTABMBackupViewController.m
//  VTABM
//
//  Created by Simon Fairbairn on 08/10/2013.
//  Copyright (c) 2013 Simon Fairbairn. All rights reserved.
//

#import "VTABMBackupViewController.h"
#import "VTABackupManager.h"
#import "VTABMStore.h"

@interface VTABMBackupViewController ()

@property (nonatomic, weak ) IBOutlet UITableView *tableView;
@property (nonatomic, strong) VTABackupManager *backupManager;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

@property (nonatomic, strong) NSDateFormatter *dateFormatter;

@end

@implementation VTABMBackupViewController

#pragma mark - Properties

-(VTABackupManager *)backupManager {

    if ( !_backupManager ) {
        _backupManager = [[VTABackupManager alloc] init];
    }
    
    return _backupManager;
}

-(NSDateFormatter *)dateFormatter {
    
    if ( !_dateFormatter ) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.dateStyle = NSDateFormatterMediumStyle;
        _dateFormatter.timeStyle = NSDateFormatterShortStyle;
    }
    return _dateFormatter;
}

#pragma mark - Actions

-(IBAction)startBackup:(UIButton *)sender {
    
    self.tableView.userInteractionEnabled = NO;
    [self.activityIndicator startAnimating];
    
    [self.backupManager backupEntityWithName:@"Cat" inContext:[[VTABMStore sharedStore] context] completionHandler:^(BOOL success, NSError *error) {
        if ( !error ) {
            UIAlertView *view = [[UIAlertView alloc] initWithTitle:@"Backup Complete" message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
            [view show];
            self.tableView.userInteractionEnabled = YES;
            [self.activityIndicator stopAnimating];
        }
        [self.tableView reloadData];
    } forceOverwrite:YES];
}

-(IBAction)deleteStore:(UIButton *)sender {
    [[VTABMStore sharedStore] deleteStore];
}

#pragma mark - UITableViewDataSource 

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.backupManager.backupList count];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"backupCell"];
    VTABackupItem *item = [self.backupManager.backupList objectAtIndex:indexPath.row];
    
    cell.textLabel.text = [self.dateFormatter stringFromDate:item.creationDate];
    cell.detailTextLabel.text = item.deviceName;
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        VTABackupItem *item = [self.backupManager.backupList objectAtIndex:indexPath.row];
        [self.backupManager deleteBackupAtURL:item.fileURL];
        [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}


-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [self.activityIndicator startAnimating];
    VTABackupItem *backup = [self.backupManager.backupList objectAtIndex:indexPath.row];
    
    [self.backupManager restoreFromURL:backup.fileURL
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
