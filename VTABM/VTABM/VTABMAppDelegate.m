//
//  VTABMAppDelegate.m
//  VTABM
//
//  Created by Simon Fairbairn on 07/10/2013.
//  Copyright (c) 2013 Simon Fairbairn. All rights reserved.
//
@import CoreData;

#import "VTABMAppDelegate.h"
#import "VTABMStore.h"
#import "VTADropboxManager.h"

@implementation VTABMAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"defaultBackup" withExtension:@"vtabackup"];
    
    NSURL *newUrl = [[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] objectAtIndex:0] URLByAppendingPathComponent:@"backups" isDirectory:YES];

    NSURL *testBackup1 = [newUrl URLByAppendingPathComponent:@"2014-01-18--iPad--7AC1978D-21B9-4C5F-A56C-50A305512E30.vtabackup"];
    NSURL *testBackup2 = [newUrl URLByAppendingPathComponent:@"2014-01-16--iPad--7AC1978D-21B9-4C5F-A56C-50A305512E30.vtabackup"];
    NSURL *testBackup3 = [newUrl URLByAppendingPathComponent:@"2014-01-12--iPad--7AC1978D-21B9-4C5F-A56C-50A305512E30.vtabackup"];
    
    [[NSFileManager defaultManager] copyItemAtURL:url toURL:testBackup1 error:nil];
    [[NSFileManager defaultManager] copyItemAtURL:url toURL:testBackup2 error:nil];
    [[NSFileManager defaultManager] copyItemAtURL:url toURL:testBackup3 error:nil];
    
    [VTADropboxManager sharedManager].backupsToKeep  = @(5);
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    
    
    
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    
    NSError *saveError;
    [[[VTABMStore sharedStore] context] save:&saveError];
    if ( saveError ) {
        [NSException raise:@"Couldn't Save Toys" format:@"Reason: %@", [saveError localizedDescription]];
    }
}

-(BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    [[VTADropboxManager sharedManager].dropboxManager handleOpenURL:url];
    return NO;
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
