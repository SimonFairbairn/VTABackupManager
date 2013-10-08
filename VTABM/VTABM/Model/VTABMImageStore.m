//
//  VTABMImageStore.m
//  VTABM
//
//  Created by Simon Fairbairn on 08/10/2013.
//  Copyright (c) 2013 Simon Fairbairn. All rights reserved.
//

#import "VTABMImageStore.h"

@interface VTABMImageStore ()

@property (nonatomic, strong) NSMutableDictionary *images;

@end

@implementation VTABMImageStore

#pragma mark - Properties

-(NSMutableDictionary *)images {
    if ( !_images ) {
        _images = [NSMutableDictionary dictionary];
    }
    return _images;
}

#pragma mark - Initialisation

+(VTABMImageStore *)sharedStore  {
    static VTABMImageStore *sharedStore = nil;
    if ( !sharedStore ) {
        sharedStore = [[super allocWithZone:nil] init];
    }
    return sharedStore;
}

+(id)allocWithZone:(struct _NSZone *)zone {
    return [self sharedStore];
}

-(id)init {
    self = [super init];
    if ( self ) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clearCache:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    return self;
}

#pragma mark - Methods

-(void)setImage:(UIImage *)image forKey:(NSString *)key {
    [self.images setObject:image forKey:key];
    
    NSURL *imagePath = [self imageURLForKey:key];
    
    NSData *data = UIImageJPEGRepresentation(image, 0.7);
    [data writeToURL:imagePath atomically:YES];
    
}

-(UIImage *)imageForKey:(NSString *)key {
    if ( !key ) return nil;
    
    UIImage *image = [self.images objectForKey:key];
    
    if ( !image ) {
        image = [UIImage imageWithContentsOfFile:[[self imageURLForKey:key] path]];
        
        if ( image ) {
            [self.images setObject:image forKey:key];
        } 
    }
    
    return image;
}

-(void)deleteImageForKey:(NSString *)key {
    if ( !key ) return;
    [self.images removeObjectForKey:key];
    
    [[NSFileManager defaultManager] removeItemAtURL:[self imageURLForKey:key] error:nil];
}

-(NSURL *)imageURLForKey:(NSString *)key {
    NSURL *documentsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    return [documentsURL URLByAppendingPathComponent:key];
}

-(void)clearCache:(NSNotification *)note {
    [self.images removeAllObjects];
}

@end
