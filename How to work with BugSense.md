# How to work with BugSense


## Compatibility 

BugSense for iOS works with iOS 3.0+, armv6+armv7, with both device and simulator support.


## Setting up your project for BugSense

This is very easy to do: install the BugSense library, configure your project (change a few settings), write a line or two of code. Each step is explained in more detail below.


### Installing the BugSense library for iOS

* Download the `BugSense-iOS.framework.zip` file, and unzip it. 
* In Xcode, select the target that you want to use and, in the "Build Phases" tab expand the "Link Binary With Libraries" section. Press the "+" button, and then press "Add Other...". In the dialog box that appears, go to the framework's location and select it. 
* The framework will appear at the top of the "Link Binary With Libraries" section and will also be added to your project files (left-hand pane). 


### Configuring your project

* Since BugSense depends on `SystemConfiguration.framework` and `CoreLocation.framework`, you have to add these as well to your project. 
* Then, in your target properties:

  * in "Other Linker Flags" put -ObjC -all_load
  * in "Strip Debug Symbols" select No for Debug and Release

* Make sure that "Generate Debug Symbols" is set to Yes.


## Basic BugSense use

Add the following lines in the implementation file for your app delegate (something like `AppDelegate.m`), ideally at the top of `application:didFinishLaunchingWithOptions:`:

	#import <BugSense-iOS/BugSenseCrashController.h>

	- (BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {   
    	BugSenseCrashController *crashController = [BugSenseCrashController sharedInstanceWithBugSenseAPIKey:@"<Your BugSense API Key>"];
                                                   
    	//...
	}

The first argument is the **BugSense API key** (`NSString`). You're good to go. 

*Note*: the standard mode of operation for BugSense in iOS is post-mortem. This means that the crash report is typically formed and dispatched upon restarting the crashed app. However, there is now an option to send the report immediately (explained below).


### Enabling immediate dispatch (a.k.a. pre-mortem mode)

BugSense now allows you to send reports as soon as the crash happens:

	#import <BugSense-iOS/BugSenseCrashController.h>

	- (BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {   
    	BugSenseCrashController *crashController = [BugSenseCrashController sharedInstanceWithBugSenseAPIKey:@"<Your BugSense API Key>"
																																			       	   userDictionary:nil
																																			       	   sendImmediately:YES];
                                                   
    	//...
	}

The first argument is the **BugSense API key** (`NSString`). The second argument is an `NSDictionary` with custom data; nil in this example. The third argument is a switch (`BOOL`) that enables the immediate dispatch of the crash report.

*Note*: This is risky and may result in corrupted data, deadlocks and program termination. This is due to the reporting code (which is not async-safe) running inside the signal handler. For more information, please read [this](http://plcrashreporter.googlecode.com/svn/tags/plcrashreporter-1.1-beta1/Documentation/API/async_safety.html).

### Sending custom data

BugSense now allows you to send custom data along with the crash report. All you need to do is create an `NSDictionary` with the data that you want to send:

	#import <BugSense-iOS/BugSenseCrashController.h>

	- (BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {   
		NSDictionary *aNiceLittleDictionary = [NSDictionary dictionaryWithObjectsAndKeys:@"myObject", @"myKey", nil];
    	BugSenseCrashController *crashController = [BugSenseCrashController sharedInstanceWithBugSenseAPIKey:@"<Your BugSense API Key>"
																																			       	   userDictionary:aNiceLittleDictionary];
                                                   
    	//...
	}

The first argument is the **BugSense API key** (`NSString`). The second argument is an `NSDictionary` with custom data. Calling this method again, will not let you redefine the data for this instance of the crash controller. You need to release the controller prior to that.

*Note*: There are some implications regarding the use of custom data. You can use an `NSMutableDictionary`, keep a reference to it and update the data as you go along. However, in post-mortem mode, BugSense will forget all of these and use only the custom data that you provide at launch. In pre-mortem mode, BugSense will send any updated data that you use:

Post-mortem example:

	#import <BugSense-iOS/BugSenseCrashController.h>

	- (BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {   
		// Setting up mutable dictionary
		NSMutableDictionary *myMutableDictionary = [[NSMutableDictionary alloc] initWithCapacity:10];
		// Adding a pair of object/key
		[myMutableDictionary setObject:@"myObject" forKey:@"myKey"];

		// Post-mortem mode
    	BugSenseCrashController *crashController = [BugSenseCrashController sharedInstanceWithBugSenseAPIKey:@"<Your BugSense API Key>"
																																			       	   userDictionary:myMutableDictionary];
                                                   
    	//...
    	
    	// Adding another pair
    	[myMutableDictionary setObject:@"mySecondObject" forKey:@"mySecondKey"];
    	
    	// ...
    	
    	// <--- crash happens here
	}
	
BugSense will only report the first pair.

Pre-mortem example:

	#import <BugSense-iOS/BugSenseCrashController.h>

	- (BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {   
		// Setting up mutable dictionary
		NSMutableDictionary *myMutableDictionary = [[NSMutableDictionary alloc] initWithCapacity:10];
		// Adding a pair of object/key
		[myMutableDictionary setObject:@"myObject" forKey:@"myKey"];

		// Pre-mortem mode
    	BugSenseCrashController *crashController = [BugSenseCrashController sharedInstanceWithBugSenseAPIKey:@"<Your BugSense API Key>"
																																			       	   userDictionary:myMutableDictionary];
                                                   
    	//...
    	
    	// Adding another pair
    	[myMutableDictionary setObject:@"mySecondObject" forKey:@"mySecondKey"];
    	
    	// ...
    	
    	// <--- crash happens here
	}

BugSense will report both pairs.

## How BugSense works

### Debugger

When the Debugger (gdb, lldb) is on, the crash controller does not send any reports.

### Post-mortem mode

When BugSense works discreetly in this case. BugSense keeps the crash data until the application is run again. Then, when the application resumes the normal mode of operation, BugSense attempts to send the report.

*Implications*: This means that if your application is constantly crashing at start (or immediately after), BugSense may not get the chance to report the crash. In this mode of operation, BugSense depends on the application for it to perform the reporting. This also means that you need to run a demo app twice to see BugSense in action (not including any runs with the Debugger on).


### Pre-mortem mode

BugSense sends the crash data immediately.

*Implications*: Even if your application is constantly crashing at start, BugSense will report the crash. This is extremely satisfying when testing with a demo app, as you can see BugSense in action in the first run (excluding any Test runs with the Debugger on).


### Logs

BugSense prints out some messages on the Console. You will typically see things like:

	Oct 18 17:49:22 unknown BugSenseDemo[176] <Warning>: BugSense --> Processing crash report...
	Oct 18 17:49:22 unknown BugSenseDemo[176] <Warning>: BugSense --> Crashed on 2011-10-18 14:48:38 +0000
	Oct 18 17:49:22 unknown BugSenseDemo[176] <Warning>: BugSense --> Crashed with signal SIGABRT (code #0, address=0x3095032c)
	Oct 18 17:49:22 unknown BugSenseDemo[176] <Warning>: BugSense --> Generating JSON data from crash report...
	Oct 18 17:49:22 unknown BugSenseDemo[176] <Warning>: BugSense --> Posting JSON data...
	Oct 18 17:49:24 unknown BugSenseDemo[176] <Warning>: BugSense --> Server responded with status code: 200
	
