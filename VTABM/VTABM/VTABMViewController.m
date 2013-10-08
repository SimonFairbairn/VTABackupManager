//
//  VTABMViewController.m
//  VTABM
//
//  Created by Simon Fairbairn on 07/10/2013.
//  Copyright (c) 2013 Simon Fairbairn. All rights reserved.
//

#import "VTABMViewController.h"

#import "VTABMStore.h"
#import "VTABMImageStore.h"
#import "VTABMRequestStore.h"
#import "Cat+createThumbnail.h"
#import "Toy.h"

#import "VTABMDetailViewController.h"

@interface VTABMViewController ()
@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;

@end

@implementation VTABMViewController

@synthesize controller = _controller;

#pragma mark - Properties

-(NSFetchedResultsController *)controller {
    if ( !_controller ) {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Cat"];
        request.sortDescriptors = @[[[NSSortDescriptor alloc] initWithKey:@"created" ascending:YES]];
        _controller = [[NSFetchedResultsController alloc] initWithFetchRequest:request managedObjectContext:[[VTABMStore sharedStore] context] sectionNameKeyPath:nil cacheName:nil];
        _controller.delegate = self;
        [_controller performFetch:nil];

    }
    return _controller;
}

- (void)viewDidLoad {
    [super viewDidLoad];

	// Do any additional setup after loading the view, typically from a nib.

    self.toolbarItems = @[self.editButtonItem];
    
}

-(void)viewWillAppear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTable:) name:VTABMStoreStoreDidChangeNotifcation object:nil];
    self.navigationController.toolbarHidden = NO;
}

-(void)viewWillLayoutSubviews {
    
}

-(void)viewWillDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.navigationController.toolbarHidden = YES;
}

-(void)updateTable:(NSNotification *)note {
//    [self.tableView reloadData];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Actions 

-(IBAction)addCat:(id)sender {
    [[VTABMStore sharedStore] randomCat];
}

#pragma mark - Segue

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    Cat *cat = [self.controller objectAtIndexPath:[self.tableView indexPathForSelectedRow]];
    UIViewController *vc = [segue destinationViewController];
    if ( [vc respondsToSelector:@selector(setCat:)]) {
        [vc performSelector:@selector(setCat:) withObject:cat];
    }
}

#pragma mark - UITableViewDataSource

-(void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)ip {
    Cat *cat = [self.controller objectAtIndexPath:ip];
    
    cell.textLabel.text = cat.name;
    cell.detailTextLabel.text = cat.toy.name;
    
    if ( cat.thumbnail ) {
        cell.imageView.image = [UIImage imageWithData:cat.thumbnail];
    } else {
        
        cell.imageView.image = nil;
        
        NSString *filename = [cat.imageURL lastPathComponent];
        
        // If we have a key, check for an image
        UIImage *catImage =  [[VTABMImageStore sharedStore] imageForKey:filename];
        
        
        if ( catImage ) {
            [cat setThumbnailDataFromImage:catImage];
            cell.imageView.image = [UIImage imageWithData:cat.thumbnail];
        } else {
            
            
            [[VTABMRequestStore sharedStore] fetchImageWithURL:cat.imageURL completion:^(UIImage *image, NSString *filename, NSError *error) {
                if ( error ) {
                    UIAlertView *view = [[UIAlertView alloc] initWithTitle:@"Couldn't fetch images" message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
                    [view show];
                } else {
                    [[VTABMImageStore sharedStore] setImage:image forKey:filename];
                    NSLog(@"%@", filename);
                    cat.imageKey = filename;
                    [cat setThumbnailDataFromImage:image];
                    
                    [[[VTABMStore sharedStore] context] save:nil];
                }
            }];
        }
    }
}



-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"catCell"];
    
    [self configureCell:cell atIndexPath:indexPath];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [[VTABMStore sharedStore] deleteCat:[self.controller objectAtIndexPath:indexPath]];
    }
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}


@end
