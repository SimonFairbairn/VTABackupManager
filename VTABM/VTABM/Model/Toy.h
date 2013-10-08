//
//  Toy.h
//  VTABM
//
//  Created by Simon Fairbairn on 07/10/2013.
//  Copyright (c) 2013 Simon Fairbairn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Cat;

@interface Toy : NSManagedObject

@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSSet *cats;
@end

@interface Toy (CoreDataGeneratedAccessors)

- (void)addCatsObject:(Cat *)value;
- (void)removeCatsObject:(Cat *)value;
- (void)addCats:(NSSet *)values;
- (void)removeCats:(NSSet *)values;

@end
