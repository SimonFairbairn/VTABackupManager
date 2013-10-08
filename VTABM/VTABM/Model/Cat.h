//
//  Cat.h
//  VTABM
//
//  Created by Simon Fairbairn on 08/10/2013.
//  Copyright (c) 2013 Simon Fairbairn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Toy;

@interface Cat : NSManagedObject

@property (nonatomic, retain) NSString * attribution;
@property (nonatomic, retain) NSString * attributionURL;
@property (nonatomic, retain) NSDate * created;
@property (nonatomic, retain) NSString * imageURL;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSNumber * order;
@property (nonatomic, retain) NSData * thumbnail;
@property (nonatomic, retain) NSString * imageKey;
@property (nonatomic, retain) Toy *toy;

@end
