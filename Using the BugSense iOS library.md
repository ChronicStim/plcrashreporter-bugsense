# Using the BugSense iOS library

## Installing the BugSense library for iOS

* Download the `BugSense-iOS.framework.zip` file, and unzip it. 
* In Xcode, select the target that you want to use and, in the "Build Phases" tab expand the "Link Binary With Libraries" section. Press the "+" button, and then press "Add Other...". In the dialog box that appears, go to the framework's location and select it. 
* The framework will appear at the top of the "Link Binary With Libraries" section and will also be added to your project files (left-hand pane). 

## Configuring your project

* Since BugSense depends on `SystemConfiguration.framework` and `CoreLocation.framework`, you have to add these as well to your project. 
* Then, in your target properties:

  * in "Other Linker Flags" put -ObjC -all_load
  * in "Strip Debug Symbols" select No for Debug and Release

* Make sure that "Generate Debug Symbols" is set to Yes.


## Using BugSense

Add the following lines in the implementation file for your app delegate (something like `AppDelegate.m`), ideally at the top of `application:didFinishLaunchingWithOptions:`:

	#import <BugSense-iOS/BugSenseCrashController.h>
	
	- (BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {   
		//...
		NSDictionary *myStuff = [NSDictionary dictionaryWithObjectsAndKeys:@"myObject", @"myKey", nil];
		BugSenseCrashController *crash = 
			[BugSenseCrashController sharedInstanceWithBugSenseAPIKey:@"<Your BugSense API Key>" 
													   								 userDictionary:myStuff 
													  							 sendImmediately:NO];
		//...
	}

The first argument is the **BugSense API key** (`NSString`). The second argument is an `NSDictionary` where you can put any object/key pairs to send back with the crash report. The third argument is a switch (`BOOL`) that can enable the dispatch of a crash report immediately after the crash has occurred, instead of on relaunch.