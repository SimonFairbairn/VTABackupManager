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

-(id)initWithFile:(NSURL *)file {
    
    if ( self = [super init] ) {
        
        if ( !dateFormatter ) {
            dateFormatter = [[NSDateFormatter alloc] init];
            dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
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
            
            NSLog(@"File UUID: %@", _fileDeviceUUID);
            NSLog(@"Device UUID: %@", [VTABackupItem deviceUUID]);
            
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
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    calendar.timeZone = [NSTimeZone localTimeZone];
    NSDateComponents *localComponents = [calendar components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit )  fromDate:[NSDate date]];
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
    return self.filePath;
}

@end
