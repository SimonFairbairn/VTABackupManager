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

@end

@implementation VTABMBackupViewController

#pragma mark - Properties

-(VTABackupManager *)backupManager {
    if ( !_backupManager ) {
        NSEntityDescription *cat = [NSEntityDescription entityForName:@"Cat" inManagedObjectContext:[VTABMStore sharedStore].context];
        _backupManager = [[VTABackupManager alloc] initWithManagedObjectContext:[VTABMStore sharedStore].context entityToBackup:cat];
    }
    return _backupManager;
}

#pragma mark - Initialisation

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Actions

-(IBAction)startBackup:(UIButton *)sender {
    
    self.tableView.userInteractionEnabled = NO;
    [self.activityIndicator startAnimating];
    
    [self.backupManager backupWithCompletionHandler:^(BOOL success, NSError *error) {
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

    NSArray *array = [self.backupManager.backupList objectAtIndex:indexPath.row];
    
    cell.textLabel.text = [array objectAtIndex:VTABackupManagerBackupListIndexPath];
    
    return cell;
}

#pragma mark - UITableViewDelegate

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.activityIndicator startAnimating];
    NSArray *backup = [self.backupManager.backupList objectAtIndex:indexPath.row];
    [self.backupManager restoreFromURL:[backup objectAtIndex:VTABackupManagerBackupListIndexURL] withCompletitionHandler:^(BOOL success, NSError *error) {
        
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
