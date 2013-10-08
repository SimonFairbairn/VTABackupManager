//
//  VTABMConnection.h
//  VTABM
//
//  Created by Simon Fairbairn on 08/10/2013.
//  Copyright (c) 2013 Simon Fairbairn. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VTABMConnection : NSObject <NSURLConnectionDataDelegate, NSURLConnectionDelegate>

@property (nonatomic, copy) NSURLRequest *request;
@property (nonatomic, copy) void (^completitionBlock)(id obj, NSString *filename, NSError *err);

-(id)initWithRequest:(NSURLRequest *)request;

-(void)start;

@end
