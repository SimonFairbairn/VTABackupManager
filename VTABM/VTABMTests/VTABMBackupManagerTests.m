//
//  VTABMBackupManagerTests.m
//  VTABM
//
//  Created by Simon Fairbairn on 23/02/2014.
//  Copyright (c) 2014 Simon Fairbairn. All rights reserved.
//

#import "VTABMBackupManagerTests.h"
#import "VTABackupManager.h"
#import "VTABMStore.h"

@implementation VTABMBackupManagerTests

+(void)setUp {
    [VTABMStore sharedStore].testContext = YES;
    [[VTABMStore sharedStore] randomCat];

}

-(void)setUp {
    [super setUp];

}

-(void)tearDown {
    [super tearDown];
}

-(void)testBackupList {
    
//    XCTAssert([[[VTABMStore sharedStore] allCats] count] == 1, @"(%i) The number of cats in the database should equal 1.", [[[VTABMStore sharedStore] allCats] count]);
    
    XCTAssertNotNil([VTABackupManager sharedManager].backupList, @"The backupList property on a VTABackupManager or any of its subclasses should not be nil");
}


@end
