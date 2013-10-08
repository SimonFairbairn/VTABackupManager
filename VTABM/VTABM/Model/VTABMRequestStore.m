//
//  VTABMRequestStore.m
//  VTABM
//
//  Created by Simon Fairbairn on 08/10/2013.
//  Copyright (c) 2013 Simon Fairbairn. All rights reserved.
//

#import "VTABMRequestStore.h"
#import "VTABMConnection.h"

@implementation VTABMRequestStore

#pragma mark - Initialisation

+(VTABMRequestStore *)sharedStore  {
    static VTABMRequestStore *sharedStore = nil;
    if ( !sharedStore ) {
        sharedStore = [[super allocWithZone:nil] init];
    }
    return sharedStore;
}

+(id)allocWithZone:(struct _NSZone *)zone {
    return [self sharedStore];
}

#pragma mark - Methods

-(void)fetchImageWithURL:(NSString *)urlString completion:(void (^)(UIImage *image, NSString *filename, NSError *error))block {
    
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSURLRequest *req = [NSURLRequest requestWithURL:url];
    
    VTABMConnection *connection = [[VTABMConnection alloc] initWithRequest:req];
    
    connection.completitionBlock = block;
    [connection start];
}

@end
