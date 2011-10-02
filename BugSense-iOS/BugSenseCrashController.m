//
//  BugSenseCrashController.m
//  BugSense-iOS
//
//  Created by Nίκος Τουμπέλης on 23/9/11.
//  Copyright 2011 . All rights reserved.
//

#import "BugSenseCrashController.h"

#include <ifaddrs.h>
#include <arpa/inet.h>

#import "CrashReporter.h"
#import "JSONKit.h"
#import "Reachability.h"
#import "AFHTTPRequestOperation.h"

#import <CoreLocation/CoreLocation.h>

#define BUGSENSE_REPORTING_SERVICE_URL @"http://www.bugsense.com/api/errors"
#define BUGSENSE_HEADER                @"X-BugSense-Api-Key"

@interface BugSenseCrashController (Private)

- (id) init;
- (id) initWithAPIKey:(NSString *)bugSenseAPIKey;
- (id) initWithAPIKey:(NSString *)bugSenseAPIKey userDictionary:(NSDictionary *)userDictionary;
- (void) initiateReportingProcess;
- (void) processCrashReport;
- (NSString *) deviceIPAddress;
- (NSData *) JSONDataFromCrashReport:(PLCrashReport *)report;
- (BOOL) postJSONData:(NSData *)jsonData;

@end


@implementation BugSenseCrashController

static BugSenseCrashController *sharedCrashController = nil;

@synthesize userDictionary = _userDictionary;

/** 
 @deprecated 
 */
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
+ (BugSenseCrashController *) sharedInstance {
    if (!sharedCrashController) {
        sharedCrashController = [[BugSenseCrashController alloc] init];
    }
    
    return sharedCrashController;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
+ (BugSenseCrashController *) sharedInstanceWithBugSenseAPIKey:(NSString *)bugSenseAPIKey {
    if (!sharedCrashController) {
        sharedCrashController = [[BugSenseCrashController alloc] initWithAPIKey:bugSenseAPIKey];
        [sharedCrashController initiateReportingProcess];
    }
    
    return sharedCrashController;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
+ (BugSenseCrashController *) sharedInstanceWithBugSenseAPIKey:(NSString *)bugSenseAPIKey 
                                                userDictionary:(NSDictionary *)userDictionary {
    if (!sharedCrashController) {
        sharedCrashController = [[BugSenseCrashController alloc] initWithAPIKey:bugSenseAPIKey 
                                                                 userDictionary:userDictionary];
        [sharedCrashController initiateReportingProcess];
	}
    return sharedCrashController;
}


/** 
 @deprecated 
 */
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
+ (BugSenseCrashController *) sharedInstanceWithBugSenseAPIKey:(NSString *)bugSenseAPIKey 
                                                 andDomainName:(NSString *)domainName {
    if (!sharedCrashController) {
        sharedCrashController = [[BugSenseCrashController alloc] initWithAPIKey:bugSenseAPIKey 
                                                                  andDomainName:domainName];
        [sharedCrashController initiateReportingProcess];
    }
    return sharedCrashController;
    
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
        _APIKey = [bugSenseAPIKey retain];
    }
    return self;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (id) initWithAPIKey:(NSString *)bugSenseAPIKey userDictionary:(NSDictionary *)userDictionary {
    if ((self = [super init])) {
        _APIKey = [bugSenseAPIKey retain];
        _userDictionary = [userDictionary retain];
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
    }
    return self;
}


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
    
    // Preparing the JSON string
    NSData *jsonData = [self JSONDataFromCrashReport:report];
    if (!jsonData) {
        NSLog(@"BugSense --> Could not prepare JSON crash report string.");
        return;
    }
    
    // Send the JSON string to the BugSense servers
    [self postJSONData:jsonData];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString *) deviceIPAddress {
    NSString *address = @"Error.";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    
    success = getifaddrs(&interfaces);
    if (success == 0) {
        temp_addr = interfaces;
        while (temp_addr != NULL) {
            if (temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if ([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    address = [NSString 
                        stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    // Free memory
    freeifaddrs(interfaces);
    
    return address;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSData *) JSONDataFromCrashReport:(PLCrashReport *)report {
    if (!report) {
        return nil;
    }
    
    // --application_environment
    NSMutableDictionary *application_environment = [[NSMutableDictionary alloc] init];
    
    // ----appname
    // [application_environment setObject:report.applicationInfo.applicationIdentifier forKey:@"appname"];
    NSArray *identifierComponents = [report.applicationInfo.applicationIdentifier componentsSeparatedByString:@"."];
    [application_environment setObject:[identifierComponents lastObject] forKey:@"appname"];
    // ----appver
    [application_environment setObject:report.applicationInfo.applicationVersion forKey:@"appver"];
    // ----internal_version
    //CFDictionaryRef bundleInfoDict = CFBundleGetInfoDictionary(CFBundleGetMainBundle());
    CFBundleRef bundle = CFBundleGetBundleWithIdentifier((CFStringRef)report.applicationInfo.applicationIdentifier);
    CFDictionaryRef bundleInfoDict = CFBundleGetInfoDictionary(bundle);
    CFStringRef buildNumber;
    
    // If we succeeded, look for our property.
    if (bundleInfoDict != NULL) {
        buildNumber = CFDictionaryGetValue(bundleInfoDict, CFSTR("CFBundleVersion"));
        [application_environment setObject:(NSString *)buildNumber forKey:@"internal_version"];
    }
    
    // ----gps_on
    [application_environment setObject:[NSNumber numberWithBool:[CLLocationManager locationServicesEnabled]] 
                                forKey:@"gps_on"];
    
    // ----languages
    /*NSMutableString *languages = [[[NSMutableString alloc] init] autorelease];
    for (NSUInteger pos = 0; pos < [[NSLocale availableLocaleIdentifiers] count]; pos++) {
        [languages appendString:[[NSLocale availableLocaleIdentifiers] objectAtIndex:pos]];
        if (pos < [[NSLocale availableLocaleIdentifiers] count]-1) {
            [languages appendString:@", "];
        }
    }*/
    CFStringRef languages;
    if (bundleInfoDict != NULL) {
        languages = CFDictionaryGetValue(bundleInfoDict, kCFBundleLocalizationsKey);
        [application_environment setObject:(NSString *)languages forKey:@"languages"];
    }
    
    // ----locale
    [application_environment setObject:[[NSLocale currentLocale] localeIdentifier] forKey:@"locale"];
    
    // ----mobile_net_on, wifi_on
    Reachability *reach = [Reachability reachabilityForInternetConnection];
    NetworkStatus status = [reach currentReachabilityStatus];
    switch (status) {
        case NotReachable:
            [application_environment setObject:[NSNumber numberWithBool:NO] forKey:@"mobile_net_on"];
            [application_environment setObject:[NSNumber numberWithBool:NO] forKey:@"wifi_on"];
            break;
        case ReachableViaWiFi:
            [application_environment setObject:[NSNumber numberWithBool:NO] forKey:@"mobile_net_on"];
            [application_environment setObject:[NSNumber numberWithBool:YES] forKey:@"wifi_on"];
            break;
        case ReachableViaWWAN:
            [application_environment setObject:[NSNumber numberWithBool:YES] forKey:@"mobile_net_on"];
            [application_environment setObject:[NSNumber numberWithBool:NO] forKey:@"wifi_on"];
            break;
    }
    
    // ----osver
    [application_environment setObject:report.systemInfo.operatingSystemVersion forKey:@"osver"];
    // ----phone
    [application_environment setObject:[UIDevice currentDevice].model forKey:@"phone"];
    
    // ----timestamp
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"YYYY-MM-dd HH:mm:ss zzz"];
    [application_environment setObject:[formatter stringFromDate:report.systemInfo.timestamp] 
                                forKey:@"timestamp"];
    [formatter release];
    
    
    NSLog(@"Basic stuff");
    
    // --exception
    NSMutableDictionary *exception = [[NSMutableDictionary alloc] init];
    
    // ----backtrace, where
    PLCrashReportThreadInfo *crashedThreadInfo = nil;
    for (PLCrashReportThreadInfo *threadInfo in report.threads) {
        if (threadInfo.crashed) {
            crashedThreadInfo = threadInfo;
            break;
        }
    }
    NSMutableArray *backtrace = [[NSMutableArray alloc] init];
    for (NSUInteger frame_idx = 0; frame_idx < [crashedThreadInfo.stackFrames count]; frame_idx++) {
        PLCrashReportStackFrameInfo *frameInfo = [crashedThreadInfo.stackFrames objectAtIndex:frame_idx];
        PLCrashReportBinaryImageInfo *imageInfo;
            
        /* Base image address containing instrumention pointer, offset of the IP from that base
         * address, and the associated image name */
        uint64_t baseAddress = 0x0;
        uint64_t pcOffset = 0x0;
        const char *imageName = "\?\?\?";
            
        imageInfo = [report imageForAddress:frameInfo.instructionPointer];
        if (imageInfo != nil) {
            imageName = [[imageInfo.imageName lastPathComponent] UTF8String];
            baseAddress = imageInfo.imageBaseAddress;
            pcOffset = frameInfo.instructionPointer - imageInfo.imageBaseAddress;
        }
        
        NSString *stackframe = [NSString stringWithFormat:@"%-4ld%-36s0x%08" PRIx64 " 0x%" PRIx64 " + %" PRId64 "", 
            (long)frame_idx, imageName, frameInfo.instructionPointer, baseAddress, pcOffset];
        [backtrace addObject:stackframe];
        
        if (frameInfo.instructionPointer == report.signalInfo.address) {
            [exception setObject:stackframe forKey:@"where"];
        }
    }
    
    [exception setObject:backtrace forKey:@"backtrace"];
    
    // ----klass, message
    if (report.hasExceptionInfo) {
        [exception setObject:report.exceptionInfo.exceptionName forKey:@"klass"];
        [exception setObject:report.exceptionInfo.exceptionReason forKey:@"message"];
    } else {
        [exception setObject:@"SIGNAL" forKey:@"klass"];
        [exception setObject:report.signalInfo.name forKey:@"message"];
    }
    
    // --request
    NSMutableDictionary *request = [[NSMutableDictionary alloc] init];
    // ----remote_ip
    [request setObject:[self deviceIPAddress] forKey:@"remote_ip"];
    
    
    // root
    NSMutableDictionary *rootDictionary = [[NSMutableDictionary alloc] init];
    [rootDictionary setObject:application_environment forKey:@"application_environment"];
    [rootDictionary setObject:exception forKey:@"exception"];
    [rootDictionary setObject:request forKey:@"request"];
    [rootDictionary setObject:_userDictionary forKey:@"custom_data"];
    
    return [rootDictionary JSONData];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL) postJSONData:(NSData *)jsonData {
    if (!jsonData) {
        return NO;
    } else {
        NSURL *bugsenseURL = [NSURL URLWithString:BUGSENSE_REPORTING_SERVICE_URL];
        NSMutableURLRequest *bugsenseRequest = [[NSMutableURLRequest alloc] initWithURL:bugsenseURL 
                                                                            cachePolicy:NSURLRequestReloadIgnoringLocalCacheData 
                                                                        timeoutInterval:15.0f];
        [bugsenseRequest setHTTPMethod:@"POST"];
        [bugsenseRequest setHTTPBody:jsonData];
        [bugsenseRequest setValue:_APIKey forHTTPHeaderField:BUGSENSE_HEADER];
        
        AFHTTPRequestOperation *operation = 
            [AFHTTPRequestOperation operationWithRequest:bugsenseRequest 
                completion:^(NSURLRequest *request, NSHTTPURLResponse *response, NSData *data, NSError *error) {
                    NSLog(@"BugSense --> Server responded with: \nstatus code:%i\nheader fields: %@", 
                        response.statusCode, response.allHeaderFields);
                    if (error) {
                        NSLog(@"BugSense --> Error: %@", error);
                    }
            }];
        
        /// add operation to queue
        [[NSOperationQueue mainQueue] addOperation:operation];
        
        return YES;
    }
}

@end
