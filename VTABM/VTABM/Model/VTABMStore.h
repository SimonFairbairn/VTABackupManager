//
//  VTABMStore.h
//  VTABM
//
//  Created by Simon Fairbairn on 07/10/2013.
//  Copyright (c) 2013 Simon Fairbairn. All rights reserved.
//

#import <Foundation/Foundation.h>

#define VTABMStoreStoreDidChangeNotifcation @"VTABMStoreStoreDidChangeNotifcation" 

@class Cat;

@interface VTABMStore : NSObject

// REMEMBER TO ALWAYS MERGE YOUR CHANGES ON THE MAIN THREAD
@property (nonatomic, strong) NSManagedObjectContext *context;

@property (nonatomic) BOOL testContext;


+(VTABMStore *)sharedStore;

-(void)randomCat;

-(void)deleteCat:(Cat *)cat;

-(NSArray *)allToysOnMainThread:(BOOL)thread;

-(void)thousandCats;

-(void)deleteStore;

-(NSArray *)allCats;

@end
