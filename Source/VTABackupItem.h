//
//  VTABackupItem.h
//  VTABM
//
//  Created by Simon Fairbairn on 29/11/2013.
//  Copyright (c) 2013 Simon Fairbairn. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VTABackupItem : NSObject

/**
 *  The files date of creation
 */
@property (nonatomic, readonly) NSDate *creationDate;

/**
 *  The name of the file without the extension
 */
@property (nonatomic, readonly) NSString *fileName;

/**
 *  The name of the file with the extension
 */
@property (nonatomic, readonly) NSString *filePath;

/**
 *  The URL of the file on the filesystem
 */
@property (nonatomic, readonly) NSURL *fileURL;

/**
 *  The device it was originally created on
 */
@property (nonatomic, readonly) NSString *deviceName;

/**
 *  A date string localized to the country where the backup was initiated. 
 */
@property (nonatomic, strong) NSString *dateString;

/**
 *  A date string localized to the country where the backup was initiated.
 */
@property (nonatomic, strong) NSDate *dateStringAsDate;

/**
 *  The UUID of the file (useful for finding out whether it's from the current device or not)
 */
@property (nonatomic, readonly) NSString *fileUUID;

/**
 *  A property that lets us know whether or not this item came from the current device
 */
@property (nonatomic, getter = isCurrentDevice, readonly) BOOL currentDevice;

-(id)initWithFile:(NSURL *)file;

+(NSString *)newFileNameWithExtension:(NSString *)extension;

+(NSString *)deviceUUID;

@end
