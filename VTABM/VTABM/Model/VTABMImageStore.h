//
//  VTABMImageStore.h
//  VTABM
//
//  Created by Simon Fairbairn on 08/10/2013.
//  Copyright (c) 2013 Simon Fairbairn. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VTABMImageStore : NSObject

+(VTABMImageStore *)sharedStore;

-(void)setImage:(UIImage *)image forKey:(NSString *)key;
-(UIImage *)imageForKey:(NSString *)key;
-(void)deleteImageForKey:(NSString *)key;
-(NSURL *)imageURLForKey:(NSString *)key;

@end
