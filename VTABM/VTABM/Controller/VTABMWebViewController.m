//
//  VTABMWebViewController.m
//  VTABM
//
//  Created by Simon Fairbairn on 08/10/2013.
//  Copyright (c) 2013 Simon Fairbairn. All rights reserved.
//

#import "VTABMWebViewController.h"

@interface VTABMWebViewController ()



@end

@implementation VTABMWebViewController

-(UIWebView *)webView {
    return (UIWebView *)[self view];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

-(void)loadView {
    _webView = [[UIWebView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    _webView.scalesPageToFit = YES;
    [self setView:_webView];
}

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

@end
