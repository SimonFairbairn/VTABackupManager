//
//  VTABMFetchedResultsTableViewController.h
//  VTABM
//
//  Created by Simon Fairbairn on 07/10/2013.
//  Copyright (c) 2013 Simon Fairbairn. All rights reserved.
//

@import CoreData;

#import <UIKit/UIKit.h>

@interface VTABMFetchedResultsTableViewController : UITableViewController <NSFetchedResultsControllerDelegate>

@property (nonatomic, strong) NSFetchedResultsController *controller;

@end
