//
//  BugSenseCrashController.m
//  BugSense-iOS
//
//  Created by Nίκος Τουμπέλης on 23/9/11.
//  Copyright 2011 . All rights reserved.
//

#import "BugSenseCrashController.h"

@interface BugSenseCrashController (Private)

- (id) init;
- (id) initWithAPIKey:(NSString *)bugSenseAPIKey;

@end


@implementation BugSenseCrashController

static BugSenseCrashController *sharedCrashController = nil;

/** 
 @deprecated 
 */
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
+ (BugSenseCrashController *) sharedInstance {
    @synchronized(self) {
		if (sharedCrashController == nil) {
			[[self alloc] init]; 
		}
	}
    return sharedCrashController;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
+ (BugSenseCrashController *) sharedInstanceWithBugSenseAPIKey:(NSString *)bugSenseAPIKey {
    @synchronized(self) {
		if (sharedCrashController == nil) {
			[[self alloc] initWithAPIKey:bugSenseAPIKey];
		}
	}
    return sharedCrashController;
}

/** 
 @deprecated 
 */
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
+ (BugSenseCrashController *) sharedInstanceWithBugSenseAPIKey:(NSString *)bugSenseAPIKey 
                                                 andDomainName:(NSString *)domainName {
    @synchronized(self) {
		if (sharedCrashController == nil) {
			[[self alloc] initWithAPIKey:bugSenseAPIKey andDomainName:domainName];
		}
	}
    return sharedCrashController;
    
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
+ (id) allocWithZone:(NSZone *)zone {
	@synchronized(self) {
		if (sharedCrashController == nil) {
			sharedCrashController = [super allocWithZone:zone];
			return sharedCrashController;   // assignment and return on first allocation
		}
	}
	return nil;  // on subsequent allocation attempts return nil
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (id) copyWithZone:(NSZone *)zone {
	return self;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (id) retain {
	return self;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSUInteger) retainCount {
	return NSUIntegerMax;  // denotes an object that cannot be released
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (oneway void) release {
	//do nothing
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (id) autorelease {
	return self;
}


// to support deprecated singleton constructor
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (id) init {
    if ((self = [super init])) {
        
    }
    return self;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (id) initWithAPIKey:(NSString *)bugSenseAPIKey {
    if ((self = [super init])) {
        
    }
    return self;
}

/** 
 @deprecated 
 */
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (id) initWithAPIKey:(NSString *)bugSenseAPIKey andDomainName:(NSString *)domainName {
    if ((self = [super init])) {
        
    }
    return self;
}

@end
