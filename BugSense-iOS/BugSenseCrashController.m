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
- (void) initiateReportingProcess;
- (void) processCrashReport;
- (NSString *) JSONStringFromCrashReport:(PLCrashReport *)report;

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
        [self initiateReportingProcess];
    }
    return self;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (id) initWithAPIKey:(NSString *)bugSenseAPIKey {
    if ((self = [super init])) {
        _APIKey = [bugSenseAPIKey retain];
        [self initiateReportingProcess];
    }
    return self;
}

/** 
 @deprecated 
 */
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (id) initWithAPIKey:(NSString *)bugSenseAPIKey andDomainName:(NSString *)domainName {
    if ((self = [super init])) {
        _APIKey = [bugSenseAPIKey retain];
        [self initiateReportingProcess];
    }
    return self;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Three stages of the process a) make JSON b) send JSON c) smile


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (void) initiateReportingProcess {
    PLCrashReporter *crashReporter = [PLCrashReporter sharedReporter];
    NSError *error;
    
    if ([crashReporter hasPendingCrashReport]) {
        [self processCrashReport];
    }
    
    if (![crashReporter enableCrashReporterAndReturnError:&error]) {
        NSLog(@"BugSense --> Warning: Could not enable crash reporterd due to: %@", error);
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (void) processCrashReport {
    PLCrashReporter *crashReporter = [PLCrashReporter sharedReporter];
    NSData *crashData;
    NSError *error;

    // Try loading the crash report
    crashData = [crashReporter loadPendingCrashReportDataAndReturnError:&error];
    if (!crashData) {
        NSLog(@"BugSense --> Could not load crash report data due to: %@", error);
        [crashReporter purgePendingCrashReport];
        return;
    }
    
    // We could send the report from here, but we'll just print out
    // some debugging info instead
    PLCrashReport *report = [[PLCrashReport alloc] initWithData:crashData error:&error];
    if (!report) {
        NSLog(@"BugSense --> Could not parse crash report due to: %@", error);
        [crashReporter purgePendingCrashReport];
        return;
    }
    
    // Generic status report on console
    NSLog(@"BugSense --> Crashed on %@", report.systemInfo.timestamp);
    NSLog(@"BugSense --> Crashed with signal %@ (code %@, address=0x%" PRIx64 ")", report.signalInfo.name, 
          report.signalInfo.code, report.signalInfo.address);
    
    NSString *jsonString = [self JSONStringFromCrashReport:report];
    
    if (!jsonString) {
        // something happened -- error handling
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString *) JSONStringFromCrashReport:(PLCrashReport *)report {
    if (!report) {
        return nil;
    }
    return nil;
}

@end
