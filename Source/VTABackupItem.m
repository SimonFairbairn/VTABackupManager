//
//  VTABackupItem.m
//  VTABM
//
//  Created by Simon Fairbairn on 29/11/2013.
//  Copyright (c) 2013 Simon Fairbairn. All rights reserved.
//

#import "VTABackupItem.h"

@implementation VTABackupItem

#pragma mark - Initialisation

-(id)initWithFile:(NSURL *)file {

    if ( self = [super init] ) {

        _fileURL = file;
        if ( !_fileURL ) return nil;
        
        NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:[file path] error:nil];
        _creationDate = dictionary[NSFileCreationDate];
        _fileName = [[[file path] lastPathComponent] stringByDeletingPathExtension];
        
        NSArray *arrayOfItems = [_fileName componentsSeparatedByString:@"--"];
        
        if ([arrayOfItems count] > 0) {
            _deviceName = [arrayOfItems objectAtIndex:0];
        }
        if ([arrayOfItems count] > 1) {
            _fileUUID = [arrayOfItems objectAtIndex:1];
        }

    }
    
    return self;
}

-(id)init {
    return [self initWithFile:nil];
}

+(NSString *)newFileNameWithExtension:(NSString *)extension {
    return [NSString stringWithFormat:@"%@--%@.%@",[[UIDevice currentDevice] model], [[NSUUID UUID] UUIDString], extension];
}

@end
