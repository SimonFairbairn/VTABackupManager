//
//  VTABMStore.m
//  VTABM
//
//  Created by Simon Fairbairn on 07/10/2013.
//  Copyright (c) 2013 Simon Fairbairn. All rights reserved.
//

@import CoreData;

#import "VTABMStore.h"
#import "Cat.h"

@interface VTABMStore ()

@property (nonatomic, strong) NSManagedObjectContext *backgroundContext;
@property (nonatomic, strong) NSManagedObjectModel *model;
@property (nonatomic, strong) NSPersistentStoreCoordinator *coordinator;

@property (nonatomic, strong) NSMutableArray *allCatsMutable;

@end

@implementation VTABMStore

#pragma mark - Properties

-(NSArray *)allCatsMutable {
    if ( !_allCatsMutable ) {
        NSLog(@"Fetching cats");
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Cat"];
        
        NSError *error;
        _allCatsMutable = [[self.context executeFetchRequest:request error:&error] mutableCopy];
        if ( error ) {
            [NSException raise:@"Couldn't fetch cats" format:@"Reason: %@", [error localizedDescription]];
        }
    }
    return _allCatsMutable;
}

-(NSManagedObjectModel *)model {
    if ( !_model ) {
        NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"vtabm" withExtension:@"momd"];
        _model = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    }
    return _model;
}

-(NSPersistentStoreCoordinator *)coordinator {
    if ( !_coordinator ) {
        
        _coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.model];
        
        NSError *error;
        
        if ( ![_coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[self storePath] options:nil error:&error]) {
            [NSException raise:@"Open Failed" format:@"Reason: %@", [error localizedDescription]];
        }
        
    }
    return _coordinator;
}

-(NSManagedObjectContext *)context {
    if ( !_context ) {
        _context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        _context.persistentStoreCoordinator = self.coordinator;
    }
    return _context;
}

-(NSManagedObjectContext *)backgroundContext {
    if ( !_backgroundContext ) {
        _backgroundContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        _backgroundContext.persistentStoreCoordinator = self.coordinator;
    }
    return _backgroundContext;
}

#pragma mark - Initialisation

+(VTABMStore *)sharedStore  {
    static VTABMStore *sharedStore = nil;
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
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mergeContexts:) name:NSManagedObjectContextDidSaveNotification object:nil];
    }
    return self;
}

#pragma mark - Methods

-(void)mergeContexts:(NSNotification *)note {
    
    // Invalidate allCats property
//    self.allCats = nil;
    
    // Post notification
    
//    [self performSelectorOnMainThread:@selector(sendNote) withObject:nil waitUntilDone:YES];
    
    // Which context are we looking at?
    NSManagedObjectContext *ctx = [note object];
    
    // Merge with t'other
    if ( ctx == self.context ) {
        [self.backgroundContext mergeChangesFromContextDidSaveNotification:note];
    } else {
        if ( ![NSThread isMainThread] ) {
            [self performSelectorOnMainThread:@selector(mergeContexts:) withObject:note waitUntilDone:YES];
        } else {
            [self.context mergeChangesFromContextDidSaveNotification:note];            
        }
        
    }
}

-(void)sendNote {
    [[NSNotificationCenter defaultCenter] postNotificationName:VTABMStoreStoreDidChangeNotifcation object:nil];
}

-(void)deleteCat:(Cat *)cat {
    [self.context deleteObject:cat];
}

-(void)randomCat {
    
    [self.backgroundContext performBlock:^{
        NSArray *toys = [self allToysOnMainThread:NO];
        NSArray *cats = @[
                          @[@"Catracula", @"Vladimir Agafonkin", @"http://www.flickr.com/photos/mourner/4728315351/", @"http://farm2.staticflickr.com/1353/4728315351_78921bb724_b.jpg"],
                          @[@"Lucky", @"woodleywonderworks", @"http://www.flickr.com/photos/wwworks/3780423837/", @"http://farm3.staticflickr.com/2031/3780423837_1018fc86f5_b.jpg"],
                          @[@"Petunia and Mimosa", @"Wikimedia", @"http://wikimedia.org", @"http://upload.wikimedia.org/wikipedia/commons/d/dc/Cats_Petunia_and_Mimosa_2004.jpg"],
                          @[@"Dr. Evil", @"Tomi Tapio K", @"http://www.flickr.com/photos/tomitapio/4305303148/", @"http://farm5.staticflickr.com/4013/4305303148_be395dab7a_o.jpg"]];
        
        Cat *aCat = [NSEntityDescription insertNewObjectForEntityForName:@"Cat" inManagedObjectContext:self.backgroundContext];
        
        NSUInteger idx = arc4random_uniform((int)[cats count]);
        NSUInteger toyIdx = arc4random_uniform((int)[toys count]);
        NSArray *catDetails = [cats objectAtIndex:idx];
        
        aCat.name = catDetails[0];
        aCat.attribution = catDetails[1];
        aCat.attributionURL = catDetails[2];
        aCat.imageURL = catDetails[3];
        aCat.created = [NSDate date];
        aCat.toy = [toys objectAtIndex:toyIdx];
        
        NSError *saveError;
        [self.backgroundContext save:&saveError];
        if ( saveError ) {
            [NSException raise:@"Couldn't Save Toys" format:@"Reason: %@", [saveError localizedDescription]];
        }

    }];
    
}

-(void)thousandCats {
    [self.backgroundContext performBlock:^{
        NSLog(@"Starting import");
        
        NSArray *toys = [self allToysOnMainThread:NO];
        NSArray *cats = @[
                          @[@"Catracula", @"Vladimir Agafonkin", @"http://www.flickr.com/photos/mourner/4728315351/", @"http://farm2.staticflickr.com/1353/4728315351_78921bb724_b.jpg"],
                          @[@"Lucky", @"woodleywonderworks", @"http://www.flickr.com/photos/wwworks/3780423837/", @"http://farm3.staticflickr.com/2031/3780423837_1018fc86f5_b.jpg"],
                          @[@"Petunia and Mimosa", @"Wikimedia", @"http://wikimedia.org", @"http://upload.wikimedia.org/wikipedia/commons/d/dc/Cats_Petunia_and_Mimosa_2004.jpg"],
                          @[@"Dr. Evil", @"Tomi Tapio K", @"http://www.flickr.com/photos/tomitapio/4305303148/", @"http://farm5.staticflickr.com/4013/4305303148_be395dab7a_o.jpg"]];
        
        
        for (int i = 0; i < 15000; i++) {
            Cat *aCat = [NSEntityDescription insertNewObjectForEntityForName:@"Cat" inManagedObjectContext:self.backgroundContext];
            
            NSInteger idx = arc4random_uniform((int)[cats count]);
            NSInteger toyIdx = arc4random_uniform((int)[toys count]);
            NSArray *catDetails = [cats objectAtIndex:idx];
            
            aCat.name = catDetails[0];
            aCat.attribution = catDetails[1];
            aCat.attributionURL = catDetails[2];
            aCat.imageURL = catDetails[3];
            aCat.created = [NSDate date];
            aCat.toy = [toys objectAtIndex:toyIdx];
            
            if ( i % 500 == 0 ) {
                NSError *saveError;
                [self.backgroundContext save:&saveError];
                if ( saveError ) {
                    [NSException raise:@"Couldn't Save Toys" format:@"Reason: %@", [saveError localizedDescription]];
                }
                
            }
        }
    }];
}

-(NSArray *)allToysOnMainThread:(BOOL)thread {

    NSManagedObjectContext *context = (thread ) ? self.context : self.backgroundContext;
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Toy"];
    NSError *error;
    NSArray *array = [context executeFetchRequest:request error:&error];
    if ( error ) {
        [NSException raise:@"Error fetching Toys" format:@"Reason: %@", [error localizedDescription]];
    }
    if ( [array count] == 0 ) {
        NSArray *toys = @[@"Ball", @"Scratching post", @"Laser pointer"];
        
        NSMutableArray *allToys = [NSMutableArray array];
        for ( NSString *name in toys ) {
            NSEntityDescription *aToy = [NSEntityDescription insertNewObjectForEntityForName:@"Toy" inManagedObjectContext:context];
            aToy.name = name;
            
            NSError *saveError;
            [context save:&saveError];
            if ( saveError ) {
                [NSException raise:@"Couldn't Save Toys" format:@"Reason: %@", [saveError localizedDescription]];
            }
            
            [allToys addObject:aToy];
        }
        array = [NSArray arrayWithArray:allToys];
    }
    
    return array;
}

-(NSURL *)storePath {
    NSURL *docs = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    
    docs = [docs URLByAppendingPathComponent:@"cat.store"];
    
    return docs;
}

-(void)deleteStore {
    self.context = nil;
    self.backgroundContext = nil;
    self.model = nil;
    self.coordinator = nil;
    [[NSFileManager defaultManager] removeItemAtURL:[self storePath] error:nil];
}


@end
