//
//  VTABMRequestStore.h
//  VTABM
//
//  Created by Simon Fairbairn on 08/10/2013.
//  Copyright (c) 2013 Simon Fairbairn. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VTABMRequestStore : NSObject

+(VTABMRequestStore *)sharedStore;

-(void)fetchImageWithURL:(NSString *)url completion:(void (^)(UIImage *image, NSString *filename, NSError *error))block;

@end
