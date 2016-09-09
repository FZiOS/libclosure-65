/*
 * Copyright (c) 2010 Apple Inc. All rights reserved.
 *
 * @APPLE_LLVM_LICENSE_HEADER@
 */

// TEST_CFLAGS -framework Foundation

#import <Foundation/Foundation.h>
#import <Block.h>
#import <objc/objc-auto.h>
#import "test.h"

int recovered = 0;

@interface TestObject : NSObject {
}
@end
@implementation TestObject
- (void)finalize {
    ++recovered;
    [super finalize];
}
- (void)dealloc {
    ++recovered;
    [super dealloc];
}
@end

void testRoutine() {
    __block id to = [[TestObject alloc] init];
    __block int i = 10;
    __block int j = 11;
    __block int k = 12;
    __block id to2 = [[TestObject alloc] init];
    void (^b)(void) = [^{
        [to self];
        ++i;
        k = i + ++j;
        [to2 self];
    } copy];
    for (int i = 0; i < 10; ++i)
        [b retain];
    for (int i = 0; i < 10; ++i)
        [b release];
    for (int i = 0; i < 10; ++i)
        (void)Block_copy(b);            // leak
    for (int i = 0; i < 10; ++i)
        Block_release(b);
    [b release];
    [to release];
    // block_byref_release needed under non-GC to get rid of testobject
}
    
void testGC() {
    if (!objc_collectingEnabled()) return;
    recovered = 0;
    for (int i = 0; i < 200; ++i)
        [[TestObject alloc] init];
    objc_collect(OBJC_EXHAUSTIVE_COLLECTION | OBJC_WAIT_UNTIL_DONE);

    if (recovered != 200) {
        fail("only recovered %d of 200\n", recovered);
    }
}
    

int main() {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    testGC();

    recovered = 0;
    for (int i = 0; i < 200; ++i)   // do enough to trigger TLC if GC is on
        testRoutine();
    objc_collect(OBJC_EXHAUSTIVE_COLLECTION | OBJC_WAIT_UNTIL_DONE);
    [pool drain];

    if (recovered == 0) {
        fail("didn't recover byref block variable");
    }

    succeed(__FILE__);
}
