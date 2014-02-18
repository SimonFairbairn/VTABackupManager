//
//  VTABMDetailViewController.m
//  VTABM
//
//  Created by Simon Fairbairn on 08/10/2013.
//  Copyright (c) 2013 Simon Fairbairn. All rights reserved.
//

#import "VTABMDetailViewController.h"
#import "VTABMWebViewController.h"

#import "VTABMImageStore.h"
#import "Cat.h"
#import "Toy.h"

@interface VTABMDetailViewController ()

@property (nonatomic, weak) IBOutlet UIImageView *catImage;
@property (nonatomic, weak) IBOutlet UILabel *catName;
@property (nonatomic, weak) IBOutlet UILabel *catToy;
@property (nonatomic, weak) IBOutlet UIButton *attribution;

@end

@implementation VTABMDetailViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.catName.text = self.cat.name;
    self.catToy.text = self.cat.toy.name;
    [self.attribution setTitle:self.cat.attribution forState:UIControlStateNormal];
    
    self.catImage.image = [[VTABMImageStore sharedStore] imageForKey:[self.cat.imageURL lastPathComponent]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(imageUpdated:) name:NSManagedObjectContextDidSaveNotification object:self.cat.managedObjectContext];
}


-(IBAction)loadAttribution:(id)sender {
    
    VTABMWebViewController *wvc = [[VTABMWebViewController alloc] init];
    NSURL *url = [NSURL URLWithString:self.cat.attributionURL];
    
    [wvc.webView loadRequest:[NSURLRequest requestWithURL:url]];
    
    [self.navigationController pushViewController:wvc animated:YES];
}

-(void)imageUpdated:(NSNotification *)note {
    self.catImage.image = [[VTABMImageStore sharedStore] imageForKey:[self.cat.imageURL lastPathComponent]];
}

@end
