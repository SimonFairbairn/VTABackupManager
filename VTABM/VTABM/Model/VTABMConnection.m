//
//  VTABMConnection.m
//  VTABM
//
//  Created by Simon Fairbairn on 08/10/2013.
//  Copyright (c) 2013 Simon Fairbairn. All rights reserved.
//

#import "VTABMConnection.h"

static NSMutableArray *sharedConnectionList = nil;

@interface VTABMConnection ()

@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableData *data;

@end

@implementation VTABMConnection

#pragma mark - Initialisation 

-(id)init {
    return [self initWithRequest:nil];
}

-(id)initWithRequest:(NSURLRequest *)request {
    self = [super init];
    if ( self ) {
        _request = request;
    }
    
    return self;
    
}

-(void)start {
    self.data = [[NSMutableData alloc] init];
    self.connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self startImmediately:YES];
    
    if ( !sharedConnectionList ) sharedConnectionList = [[NSMutableArray alloc] init];
    
    [sharedConnectionList addObject:self];
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.data appendData:data];
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection {
    UIImage *image = [UIImage imageWithData:self.data];
    NSString *filename = [self.request.URL lastPathComponent];
    
    if ( self.completitionBlock ) self.completitionBlock(image, filename, nil);
    
    [sharedConnectionList removeObject:self];
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    if ( self.completitionBlock ) self.completitionBlock(nil, nil, error);
    [sharedConnectionList removeObject:self];
}

@end
