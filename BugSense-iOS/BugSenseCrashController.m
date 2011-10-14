/*
 BugSenseCrashController.m
 BugSense-iOS
 
 Copyright (c) 2011 BugSense.com
 
 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following
 conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.
 
 Author:
 Nick Toumpelis (Ocean Road Software)
 
 */

#import "BugSenseCrashController.h"

#include <ifaddrs.h>
#include <arpa/inet.h>

#import "CrashReporter.h"
#import "JSONKit.h"
#import "Reachability.h"
#import "AFHTTPRequestOperation.h"
#import "NSMutableURLRequest+AFNetworking.h"

#import <CoreLocation/CoreLocation.h>

#include <dlfcn.h>


#define BUGSENSE_REPORTING_SERVICE_URL @"http://www.bugsense.com/api/errors"
#define BUGSENSE_HEADER                @"X-BugSense-Api-Key"




@interface BugSenseCrashController (Private)

void post_crash_callback(siginfo_t *info, ucontext_t *uap, void *context);
- (void) processCrashReportImmediately;
- (NSString *) ipAddress;
- (id) initWithAPIKey:(NSString *)bugSenseAPIKey 
       userDictionary:(NSDictionary *)userDictionary 
      sendImmediately:(BOOL)immediately;
- (void) initiateReportingProcess;
- (void) processCrashReport;
- (NSData *) JSONDataFromCrashReport:(PLCrashReport *)report;
- (BOOL) postJSONData:(NSData *)jsonData;
- (void) observeValueForKeyPath:(NSString *)keyPath 
                       ofObject:(id)object 
                         change:(NSDictionary *)change 
                        context:(void *)context;

@end


@implementation BugSenseCrashController

static BugSenseCrashController *sharedCrashController = nil;

#pragma mark - Crash callback function
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void post_crash_callback(siginfo_t *info, ucontext_t *uap, void *context) {
    // This is not async-safe!!! Beware!!!
    if ([[PLCrashReporter sharedReporter] hasPendingCrashReport]) {
        [sharedCrashController performSelectorOnMainThread:@selector(processCrashReportImmediately) 
                                                withObject:nil 
                                             waitUntilDone:YES];
    }
}


#pragma mark - Crash callback method
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (void) processCrashReportImmediately {
    [self processCrashReport];
    
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
	CFArrayRef allModes = CFRunLoopCopyAllModes(runLoop);
	
	while (!_operationCompleted) {
		for (NSString *mode in (NSArray *)allModes) {
			CFRunLoopRunInMode((CFStringRef)mode, 0.001, false);
		}
	}
	
	CFRelease(allModes);
    
	NSSetUncaughtExceptionHandler(NULL);
	signal(SIGABRT, SIG_DFL);
	signal(SIGILL, SIG_DFL);
	signal(SIGSEGV, SIG_DFL);
	signal(SIGFPE, SIG_DFL);
	signal(SIGBUS, SIG_DFL);
	signal(SIGPIPE, SIG_DFL);
    
    NSLog(@"BugSense --> Immediate dispatch completed!");
    
    abort();
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString *) ipAddress {
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


#pragma mark - Singleton constructors
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
+ (BugSenseCrashController *) sharedInstanceWithBugSenseAPIKey:(NSString *)bugSenseAPIKey {
    if (!sharedCrashController) {
        sharedCrashController = [[BugSenseCrashController alloc] initWithAPIKey:bugSenseAPIKey
                                                                 userDictionary:nil
                                                                sendImmediately:NO];
    }

    [sharedCrashController initiateReportingProcess];
    
    return sharedCrashController;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
+ (BugSenseCrashController *) sharedInstanceWithBugSenseAPIKey:(NSString *)bugSenseAPIKey 
                                                userDictionary:(NSDictionary *)userDictionary {
    if (!sharedCrashController) {
        sharedCrashController = [[BugSenseCrashController alloc] initWithAPIKey:bugSenseAPIKey
                                                                 userDictionary:userDictionary
                                                                sendImmediately:NO];
	}
    
    [sharedCrashController initiateReportingProcess];

    return sharedCrashController;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
+ (BugSenseCrashController *) sharedInstanceWithBugSenseAPIKey:(NSString *)bugSenseAPIKey 
                                                userDictionary:(NSDictionary *)userDictionary
                                               sendImmediately:(BOOL)immediately {
    if (!sharedCrashController) {
        sharedCrashController = [[BugSenseCrashController alloc] initWithAPIKey:bugSenseAPIKey
                                                                 userDictionary:userDictionary
                                                                sendImmediately:immediately];
    }
    
    [sharedCrashController initiateReportingProcess];
    
    return sharedCrashController;
}


#pragma mark - Initializer
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (id) initWithAPIKey:(NSString *)bugSenseAPIKey 
       userDictionary:(NSDictionary *)userDictionary 
      sendImmediately:(BOOL)immediately {
    if ((self = [super init])) {
        _operationCompleted = NO;
        
        if (bugSenseAPIKey) {
            _APIKey = [bugSenseAPIKey retain];
        }
        
        if (userDictionary && userDictionary.count > 0) {
            _userDictionary = [userDictionary retain];
        } else {
            _userDictionary = nil;
        }
        
        _immediately = immediately;
    }
    return self;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (void) initiateReportingProcess {
    PLCrashReporter *crashReporter = [PLCrashReporter sharedReporter];
    NSError *error = nil;
    
    if (_immediately) {
        PLCrashReporterCallbacks cb = {
            .version = 0,
            .context = (void *) 0xABABABAB,
            .handleSignal = post_crash_callback
        };
        [crashReporter setCrashCallbacks:&cb];
    } else {
        if ([crashReporter hasPendingCrashReport]) {
            [self processCrashReport];
        }
    }
    
    if (![crashReporter enableCrashReporterAndReturnError:&error]) {
        NSLog(@"BugSense --> Error: Could not enable crash reporterd due to: %@", error);
    } else {
        if (error != nil) {
            NSLog(@"BugSense --> Warning: %@", error);
        }
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (void) processCrashReport {
    NSLog(@"BugSense --> Processing crash report...");
    
    PLCrashReporter *crashReporter = [PLCrashReporter sharedReporter];
    NSError *error = nil;
    
    // Try loading the crash report
    NSData *crashData = [crashReporter loadPendingCrashReportDataAndReturnError:&error];
    if (!crashData) {
        NSLog(@"BugSense --> Error: Could not load crash report data due to: %@", error);
        [crashReporter purgePendingCrashReport];
        return;
    } else {
        if (error != nil) {
            NSLog(@"BugSense --> Warning: %@", error);
        }
    }
    
    // We could send the report from here, but we'll just print out
    // some debugging info instead
    PLCrashReport *report = [[PLCrashReport alloc] initWithData:crashData error:&error];
    if (!report) {
        NSLog(@"BugSense --> Error: Could not parse crash report due to: %@", error);
        [crashReporter purgePendingCrashReport];
        return;
    } else {
        if (error != nil) {
            NSLog(@"BugSense --> Warning: %@", error);
        }
    }
    
    // Generic status report on console
    NSLog(@"BugSense --> Crashed on %@", report.systemInfo.timestamp);
    NSLog(@"BugSense --> Crashed with signal %@ (code %@, address=0x%" PRIx64 ")", 
          report.signalInfo.name, report.signalInfo.code, report.signalInfo.address);
    
    // Preparing the JSON string
    NSData *jsonData = [self JSONDataFromCrashReport:report];
    [report release];
    if (!jsonData) {
        NSLog(@"BugSense --> Could not prepare JSON crash report string.");
        return;
    }
    
    // Send the JSON string to the BugSense servers
    [self postJSONData:jsonData];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSData *) JSONDataFromCrashReport:(PLCrashReport *)report {
    if (!report) {
        return nil;
    }
    
    @try {
        NSLog(@"BugSense --> Generating JSON data from crash report...");
    
        // --application_environment
        NSMutableDictionary *application_environment = [[[NSMutableDictionary alloc] init] autorelease];
    
        // ----appname
        NSArray *identifierComponents = [report.applicationInfo.applicationIdentifier componentsSeparatedByString:@"."];
        if (identifierComponents && identifierComponents.count > 0) {
            [application_environment setObject:[identifierComponents lastObject] forKey:@"appname"];
        }
    
        // ----appver
        CFBundleRef bundle = CFBundleGetBundleWithIdentifier((CFStringRef)report.applicationInfo.applicationIdentifier);
        CFDictionaryRef bundleInfoDict = CFBundleGetInfoDictionary(bundle);
        CFStringRef buildNumber;
    
        // If we succeeded, look for our property.
        if (bundleInfoDict != NULL) {
            buildNumber = CFDictionaryGetValue(bundleInfoDict, CFSTR("CFBundleShortVersionString"));
            if (buildNumber) {
                [application_environment setObject:(NSString *)buildNumber forKey:@"appver"];
            }
        }
    
        // ----internal_version
        [application_environment setObject:report.applicationInfo.applicationVersion forKey:@"internal_version"];
    
        // ----gps_on
        [application_environment setObject:[NSNumber numberWithBool:[CLLocationManager locationServicesEnabled]] 
                                    forKey:@"gps_on"];
    
        if (bundleInfoDict != NULL) {
            NSMutableString *languages = [[[NSMutableString alloc] init] autorelease];
            CFStringRef baseLanguage = CFDictionaryGetValue(bundleInfoDict, kCFBundleDevelopmentRegionKey);
            if (baseLanguage) {
                [languages appendString:(NSString *)baseLanguage];
            }
            
            CFStringRef allLanguages = CFDictionaryGetValue(bundleInfoDict, kCFBundleLocalizationsKey);
            if (allLanguages) {
                [languages appendString:(NSString *)allLanguages];
            }
            if (languages) {
                [application_environment setObject:(NSString *)languages forKey:@"languages"];
            }
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
        [formatter setDateFormat:@"YYYY-MM-dd HH:mm:ss zzzzz"];
        [application_environment setObject:[formatter stringFromDate:report.systemInfo.timestamp] 
                                    forKey:@"timestamp"];
        [formatter release];
    
    
        // --exception
        NSMutableDictionary *exception = [[[NSMutableDictionary alloc] init] autorelease];
    
        // ----backtrace, where
        PLCrashReportThreadInfo *crashedThreadInfo = nil;
        for (PLCrashReportThreadInfo *threadInfo in report.threads) {
            if (threadInfo.crashed) {
                crashedThreadInfo = threadInfo;
                break;
            }
        }
        
        if (!crashedThreadInfo) {
            if (report.threads.count > 0) {
                crashedThreadInfo = [report.threads objectAtIndex:0];
            }
        }
    
        NSInteger pos = -1;
    
        NSMutableArray *backtrace = [[[NSMutableArray alloc] init] autorelease];
        for (NSUInteger frameIndex = 0; frameIndex < [crashedThreadInfo.stackFrames count]; frameIndex++) {
            PLCrashReportStackFrameInfo *frameInfo = [crashedThreadInfo.stackFrames objectAtIndex:frameIndex];
            PLCrashReportBinaryImageInfo *imageInfo;
        
            uint64_t baseAddress = 0x0;
            uint64_t pcOffset = 0x0;
            const char *imageName = "\?\?\?";
                
            imageInfo = [report imageForAddress:frameInfo.instructionPointer];
            if (imageInfo != nil) {
                imageName = [[imageInfo.imageName lastPathComponent] UTF8String];
                baseAddress = imageInfo.imageBaseAddress;
                pcOffset = frameInfo.instructionPointer - imageInfo.imageBaseAddress;
            }
        
            Dl_info theInfo;
            NSString *stackframe = nil;
            NSString *commandName = nil;
            if ((dladdr((void *)(uintptr_t)frameInfo.instructionPointer, &theInfo) != 0) && theInfo.dli_sname != NULL) {
                commandName = [NSString stringWithCString:theInfo.dli_sname encoding:NSUTF8StringEncoding];
                stackframe = [NSString stringWithFormat:@"%-4ld%-36s0x%08" PRIx64 " %@ + %" PRId64 "",
                    (long)frameIndex, imageName, frameInfo.instructionPointer, commandName, pcOffset];
            } else {
                stackframe = [NSString stringWithFormat:@"%-4ld%-36s0x%08" PRIx64 " 0x%" PRIx64 " + %" PRId64 "", 
                    (long)frameIndex, imageName, frameInfo.instructionPointer, baseAddress, pcOffset];
            }
            [backtrace addObject:stackframe];
        
            if (report.hasExceptionInfo) {
                if ([commandName hasPrefix:@"+[NSException raise:"]) {
                    pos = frameIndex+1;
                } else {
                    if (pos != -1 && pos == frameIndex) {
                        [exception setObject:stackframe forKey:@"where"];
                    }
                }
            } else {
                if (report.signalInfo.address == frameInfo.instructionPointer) {
                    [exception setObject:stackframe forKey:@"where"];
                }
            }
        }
    
        if (![exception objectForKey:@"where"] && backtrace && backtrace.count > 0) {
             [exception setObject:[backtrace objectAtIndex:0] forKey:@"where"];
        }
    
        if (backtrace.count > 0) {
            [exception setObject:backtrace forKey:@"backtrace"];
        } else {
            [exception setObject:@"No backtrace available [?]" forKey:@"backtrace"];
        }
    
        // ----klass, message
        if (report.hasExceptionInfo) {
            [exception setObject:report.exceptionInfo.exceptionName forKey:@"klass"];
            [exception setObject:report.exceptionInfo.exceptionReason forKey:@"message"];
        } else {
            [exception setObject:@"SIGNAL" forKey:@"klass"];
            [exception setObject:report.signalInfo.name forKey:@"message"];
        }
    
        // --request
        NSMutableDictionary *request = [[[NSMutableDictionary alloc] init] autorelease];
    
        // ----remote_ip
        [request setObject:[self ipAddress] forKey:@"remote_ip"];
        if (_userDictionary) {
            [request addEntriesFromDictionary:_userDictionary];
        }
    
        // root
        NSMutableDictionary *rootDictionary = [[[NSMutableDictionary alloc] init] autorelease];
        [rootDictionary setObject:application_environment forKey:@"application_environment"];
        [rootDictionary setObject:exception forKey:@"exception"];
        [rootDictionary setObject:request forKey:@"request"];
        
        NSString *jsonString = 
            [[rootDictionary JSONString] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        return [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    } @catch (NSException *exception) {
        NSLog(@"BugSense --> Something unusual happened during the generation of JSON data");
        return nil;
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL) postJSONData:(NSData *)jsonData {
    if (!jsonData) {
        NSLog(@"BugSense --> No JSON data was given to post.");
        return NO;
    } else {
        NSURL *bugsenseURL = [NSURL URLWithString:BUGSENSE_REPORTING_SERVICE_URL];
        NSMutableURLRequest *bugsenseRequest = [[[NSMutableURLRequest alloc] initWithURL:bugsenseURL 
            cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:15.0f] autorelease];
        [bugsenseRequest setHTTPMethod:@"POST"];
        [bugsenseRequest setValue:_APIKey forHTTPHeaderField:BUGSENSE_HEADER];
        [bugsenseRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        
        NSMutableData *postData = [NSMutableData data];
        [postData appendData:[@"data=" dataUsingEncoding:NSUTF8StringEncoding]];
        [postData appendData:jsonData];
        [bugsenseRequest setHTTPBody:postData];
        
        // This version employs blocks so this is only working under iOS 4.0+.
        /*AFHTTPRequestOperation *operation = 
            [AFHTTPRequestOperation operationWithRequest:bugsenseRequest 
                completion:^(NSURLRequest *request, NSHTTPURLResponse *response, NSData *data, NSError *error) {
                    NSLog(@"BugSense --> Server responded with: \nstatus code:%i\nheader fields: %@", 
                        response.statusCode, response.allHeaderFields);
                    if (error) {
                        NSLog(@"BugSense --> Error: %@", error);
                    } else {
                        BOOL statusCodeAcceptable = [[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)] 
                                                     containsIndex:[response statusCode]];
                        if (statusCodeAcceptable) {
                            PLCrashReporter *crashReporter = [PLCrashReporter sharedReporter];
                            [crashReporter purgePendingCrashReport];
                        }
                    }
            }];*/
        
        AFHTTPRequestOperation *operation = [AFHTTPRequestOperation operationWithRequest:bugsenseRequest observer:self];
        
        /// add operation to queue
        [[NSOperationQueue mainQueue] addOperation:operation];

        NSLog(@"BugSense --> Posting JSON data...");
        
        return YES;
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (void) observeValueForKeyPath:(NSString *)keyPath 
                       ofObject:(id)object 
                         change:(NSDictionary *)change 
                        context:(void *)context {
    if ([keyPath isEqualToString:@"isFinished"] && [object isKindOfClass:[AFHTTPRequestOperation class]]) {
        AFHTTPRequestOperation *operation = object;
        NSLog(@"BugSense --> Server responded with status code: %i", operation.response.statusCode);
        if (operation.error) {
            NSLog(@"BugSense --> Error: %@", operation.error);
        } else {
            BOOL statusCodeAcceptable = [[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)] 
                                         containsIndex:[operation.response statusCode]];
            if (statusCodeAcceptable) {
                PLCrashReporter *crashReporter = [PLCrashReporter sharedReporter];
                [crashReporter purgePendingCrashReport];
            }
        }
        
        _operationCompleted = YES;
    }
}

@end
