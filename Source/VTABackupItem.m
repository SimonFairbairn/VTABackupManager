//
//  VTABackupItem.m
//  VTABM
//
//  Created by Simon Fairbairn on 29/11/2013.
//  Copyright (c) 2013 Simon Fairbairn. All rights reserved.
//

#import "VTABackupItem.h"

#define VTABackupItemDeviceUUIDPrefKey @"VTABackupItemDeviceUUIDPrefKey"

static NSDateFormatter *dateFormatter;
static NSString *deviceUUID;

@interface VTABackupItem ()

@property (nonatomic, strong) NSString *fileDeviceUUID;

@end

@implementation VTABackupItem

#pragma mark - Initialisation

-(instancetype)initWithURL:(NSURL *)url name:(NSString *)name {
    if ( self = [super init] ) {
        if ( !dateFormatter ) {
            dateFormatter = [[NSDateFormatter alloc] init];
            dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
            dateFormatter.timeZone = [NSTimeZone localTimeZone];
            dateFormatter.dateFormat = @"yyyy-MM-dd";
        }

        _fileURL = url;
        
        NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:[url path] error:nil];
        _creationDate = dictionary[NSFileCreationDate];
        
        
        _filePath = [name lastPathComponent];
        _fileName = [_filePath stringByDeletingPathExtension];
        
        NSArray *arrayOfItems = [_fileName componentsSeparatedByString:@"--"];
        
        if ([arrayOfItems count] > 0) {
            _dateString = [[arrayOfItems objectAtIndex:0] stringByReplacingOccurrencesOfString:@"backup-" withString:@""];
            _dateStringAsDate = [dateFormatter dateFromString:_dateString];
        }
        
        if ( !_creationDate ) {
            _creationDate = [_dateStringAsDate dateByAddingTimeInterval:10];
        }
        
        if ([arrayOfItems count] > 1) {
            _deviceName = [arrayOfItems objectAtIndex:1];
        }
        
        if ([arrayOfItems count] > 2 ) {
            
            NSString *lastComponent = [arrayOfItems objectAtIndex:2];
            
            _fileDeviceUUID = [[lastComponent componentsSeparatedByString:@" "] firstObject];
            _fileUUID = _fileDeviceUUID;
            if ( [_fileDeviceUUID isEqualToString:[VTABackupItem deviceUUID]] ) {
                _currentDevice = YES;
            }
        }
    }
    
    return self;
}

-(id)initWithFile:(NSURL *)file {
    
    if ( self = [super init] ) {
        if ( !dateFormatter ) {
            dateFormatter = [[NSDateFormatter alloc] init];
            dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
            dateFormatter.timeZone = [NSTimeZone localTimeZone];
            dateFormatter.dateFormat = @"yyyy-MM-dd";
        }

        
        _fileURL = file;
        if ( !_fileURL ) return nil;
        
        NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:[file path] error:nil];
        _creationDate = dictionary[NSFileCreationDate];
        _filePath = [[file path] lastPathComponent];
        _fileName = [[[file path] lastPathComponent] stringByDeletingPathExtension];
        
        NSArray *arrayOfItems = [_fileName componentsSeparatedByString:@"--"];

        if ([arrayOfItems count] > 0) {
            _dateString = [[arrayOfItems objectAtIndex:0] stringByReplacingOccurrencesOfString:@"backup-" withString:@""];
            _dateStringAsDate = [dateFormatter dateFromString:_dateString];
        }
        
        if ([arrayOfItems count] > 1) {
            _deviceName = [arrayOfItems objectAtIndex:1];
        }
        
        if ([arrayOfItems count] > 2 ) {

            _fileDeviceUUID = [arrayOfItems objectAtIndex:2];
            
            if ( [_fileDeviceUUID isEqualToString:[VTABackupItem deviceUUID]] ) {
                _currentDevice = YES;
            }
        }
    }
    
    return self;
}

-(id)init {
    return [self initWithFile:nil];
}

+(NSString *)newFileNameWithExtension:(NSString *)extension {
    
    if ( !dateFormatter ) {
        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        dateFormatter.timeZone = [NSTimeZone localTimeZone];
        dateFormatter.dateFormat = @"yyyy-MM-dd";
    }
    
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    calendar.timeZone = [NSTimeZone localTimeZone];
    NSDateComponents *localComponents = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute )  fromDate:[NSDate date]];
    localComponents.calendar = calendar;
    
    NSString *dateString = [NSString stringWithFormat:@"%@--%@--%@.%@", [dateFormatter stringFromDate:[localComponents date]], [[UIDevice currentDevice] model], [VTABackupItem deviceUUID], extension];
    
    return dateString;
}

+(NSString *)deviceUUID {

    if ( !deviceUUID ) {
        
        deviceUUID = [[NSUserDefaults standardUserDefaults] stringForKey:VTABackupItemDeviceUUIDPrefKey];
        
        if ( !deviceUUID ) {
            NSString *newUUID = [[NSUUID UUID] UUIDString];
            deviceUUID = newUUID;
            [[NSUserDefaults standardUserDefaults] setObject:newUUID forKey:VTABackupItemDeviceUUIDPrefKey];
        }
    }
    
    return deviceUUID;
}

-(NSString *)description {
    
    return [[super description] stringByAppendingFormat:@"%@", self.filePath];
}


@end
