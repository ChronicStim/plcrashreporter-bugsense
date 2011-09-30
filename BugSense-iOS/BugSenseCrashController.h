//
//  BugSenseCrashController.h
//  BugSense-iOS
//
//  Created by Nίκος Τουμπέλης on 23/9/11.
//  Copyright 2011 . All rights reserved.
//

#import "JSONKit.h"
#import <CoreLocation/CoreLocation.h>
#import "Reachability.h"
#import "AFHTTPRequestOperation.h"
#include <ifaddrs.h>
#include <arpa/inet.h>

@interface BugSenseCrashController : NSObject {
    NSString *_APIKey;
    NSDictionary *_userDictionary;
}

/** 
 @deprecated 
 */
+ (BugSenseCrashController *) sharedInstance;

+ (BugSenseCrashController *) sharedInstanceWithBugSenseAPIKey:(NSString *)bugSenseAPIKey;

+ (BugSenseCrashController *) sharedInstanceWithBugSenseAPIKey:(NSString *)bugSenseAPIKey 
                                                userDictionary:(NSDictionary *)userDictionary;

/** 
 @deprecated 
 */
+ (BugSenseCrashController *) sharedInstanceWithBugSenseAPIKey:(NSString *)bugSenseAPIKey 
                                                 andDomainName:(NSString *)domainName;
/** 
 @deprecated 
 */
- (id) initWithAPIKey:(NSString *)bugSenseAPIKey andDomainName:(NSString *)domainName;

@property (nonatomic, retain) NSDictionary *userDictionary;

@end
