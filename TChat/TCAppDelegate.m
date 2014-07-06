//
//  YCAppDelegate.m
//  YChat
//
//  Created by SWATI KIRVE on 04/07/2014.
//  Copyright (c) 2014 sharaai. All rights reserved.
//

#import "TCAppDelegate.h"

// Log levels: off, error, warn, info, verbose
#if DEBUG
static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
static const int ddLogLevel = LOG_LEVEL_INFO;
#endif

@implementation TCAppDelegate

@synthesize xmppStream;
@synthesize xmppReconnect;
@synthesize xmppRoster;
@synthesize xmppRosterStorage;
@synthesize xmppvCardTempModule;
@synthesize xmppvCardAvatarModule;
@synthesize xmppCapabilities;
@synthesize xmppCapabilitiesStorage;

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    // Override point for customization after application launch.
    
    // Navigation bar appearance (background and title)
    [[UINavigationBar appearance] setBarTintColor:[UIColor colorWithRed:50.0f/255.0f green:177.0f/255.0f blue:242.0f/255.0f alpha:1]];
    
    [[UINavigationBar appearance] setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIColor whiteColor], NSForegroundColorAttributeName, [UIFont fontWithName:@"Helvetica Neue" size:20], NSFontAttributeName, nil]];
    
    [[UINavigationBar appearance] setTintColor:[UIColor whiteColor]];
    
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    
     _currentHost = XMPP_UAT_HOST;
    
    _XMPP_RESOURCE_NAME = [[NSString stringWithFormat:@"TChat-iOS-%@-%@",[[UIDevice currentDevice] localizedModel],[[[UIDevice currentDevice] identifierForVendor] UUIDString]] stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSLog(@"Resource name: %@",_XMPP_RESOURCE_NAME);
    
    [self prepareXmppChat];

  //  [self.window makeKeyAndVisible];
    
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark XMPP

-(void)prepareXmppChat{
    
    [xmppStream setHostName:_currentHost];
    [DDLog addLogger:[DDTTYLogger sharedInstance]]; // Enable DDLog
    [self setupStream];
}

- (void)setupStream
{
    NSLog(@"--XMPPSetup Stream");
	NSAssert(xmppStream == nil, @"Method setupStream invoked multiple times");
	
	// Setup xmpp stream
	//
	// The XMPPStream is the base class for all activity.
	// Everything else plugs into the xmppStream, such as modules/extensions and delegates.
    
	xmppStream = [[XMPPStream alloc] init];
	
#if !TARGET_IPHONE_SIMULATOR
	{
		// Want xmpp to run in the background?
		//
		// P.S. - The simulator doesn't support backgrounding yet.
		//        When you try to set the associated property on the simulator, it simply fails.
		//        And when you background an app on the simulator,
		//        it just queues network traffic til the app is foregrounded again.
		//        We are patiently waiting for a fix from Apple.
		//        If you do enableBackgroundingOnSocket on the simulator,
		//        you will simply see an error message from the xmpp stack when it fails to set the property.
		
		xmppStream.enableBackgroundingOnSocket = YES;
	}
#endif
	
	// Setup reconnect
	//
	// The XMPPReconnect module monitors for "accidental disconnections" and
	// automatically reconnects the stream for you.
	// There's a bunch more information in the XMPPReconnect header file.
	
	xmppReconnect = [[XMPPReconnect alloc] init];
	
	// Setup roster
	//
	// The XMPPRoster handles the xmpp protocol stuff related to the roster.
	// The storage for the roster is abstracted.
	// So you can use any storage mechanism you want.
	// You can store it all in memory, or use core data and store it on disk, or use core data with an in-memory store,
	// or setup your own using raw SQLite, or create your own storage mechanism.
	// You can do it however you like! It's your application.
	// But you do need to provide the roster with some storage facility.
	
	xmppRosterStorage = [[XMPPRosterCoreDataStorage alloc] init];
    //	xmppRosterStorage = [[XMPPRosterCoreDataStorage alloc] initWithInMemoryStore];
	
	xmppRoster = [[XMPPRoster alloc] initWithRosterStorage:xmppRosterStorage];
	
	xmppRoster.autoFetchRoster = YES;
	xmppRoster.autoAcceptKnownPresenceSubscriptionRequests = YES;
	
	// Setup vCard support
	//
	// The vCard Avatar module works in conjuction with the standard vCard Temp module to download user avatars.
	// The XMPPRoster will automatically integrate with XMPPvCardAvatarModule to cache roster photos in the roster.
	
	xmppvCardStorage = [XMPPvCardCoreDataStorage sharedInstance];
	xmppvCardTempModule = [[XMPPvCardTempModule alloc] initWithvCardStorage:xmppvCardStorage];
	
	xmppvCardAvatarModule = [[XMPPvCardAvatarModule alloc] initWithvCardTempModule:xmppvCardTempModule];
	
	// Setup capabilities
	//
	// The XMPPCapabilities module handles all the complex hashing of the caps protocol (XEP-0115).
	// Basically, when other clients broadcast their presence on the network
	// they include information about what capabilities their client supports (audio, video, file transfer, etc).
	// But as you can imagine, this list starts to get pretty big.
	// This is where the hashing stuff comes into play.
	// Most people running the same version of the same client are going to have the same list of capabilities.
	// So the protocol defines a standardized way to hash the list of capabilities.
	// Clients then broadcast the tiny hash instead of the big list.
	// The XMPPCapabilities protocol automatically handles figuring out what these hashes mean,
	// and also persistently storing the hashes so lookups aren't needed in the future.
	//
	// Similarly to the roster, the storage of the module is abstracted.
	// You are strongly encouraged to persist caps information across sessions.
	//
	// The XMPPCapabilitiesCoreDataStorage is an ideal solution.
	// It can also be shared amongst multiple streams to further reduce hash lookups.
	
	xmppCapabilitiesStorage = [XMPPCapabilitiesCoreDataStorage sharedInstance];
    xmppCapabilities = [[XMPPCapabilities alloc] initWithCapabilitiesStorage:xmppCapabilitiesStorage];
    
    xmppCapabilities.autoFetchHashedCapabilities = NO;
    xmppCapabilities.autoFetchNonHashedCapabilities = NO;
    
	// Activate xmpp modules
    
	[xmppReconnect         activate:xmppStream];
	[xmppRoster            activate:xmppStream];
	[xmppvCardTempModule   activate:xmppStream];
	[xmppvCardAvatarModule activate:xmppStream];
	[xmppCapabilities      activate:xmppStream];
    
	// Add ourself as a delegate to anything we may be interested in
    
	[xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[xmppRoster addDelegate:self delegateQueue:dispatch_get_main_queue()];
    
	// Optional:
	//
	// Replace me with the proper domain and port.
	// The example below is setup for a typical google talk account.
	//
	// If you don't supply a hostName, then it will be automatically resolved using the JID (below).
	// For example, if you supply a JID like 'user@quack.com/rsrc'
	// then the xmpp framework will follow the xmpp specification, and do a SRV lookup for quack.com.
	//
	// If you don't specify a hostPort, then the default (5222) will be used.
	
    //	[xmppStream setHostName:@"talk.google.com"];
    //	[xmppStream setHostPort:5222];
	
    
	// You may need to alter these settings depending on the server you're connecting to
	_allowSelfSignedCertificates = YES;
	_allowSSLHostNameMismatch = YES;
}

- (void)teardownStream
{
	[xmppStream removeDelegate:self];
	[xmppRoster removeDelegate:self];
	
	[xmppReconnect deactivate];
	[xmppRoster deactivate];
	[xmppvCardTempModule deactivate];
	[xmppvCardAvatarModule deactivate];
	[xmppCapabilities deactivate];
	
	[xmppStream disconnect];
	
	xmppStream = nil;
	xmppReconnect = nil;
    xmppRoster = nil;
	xmppRosterStorage = nil;
	xmppvCardStorage = nil;
    xmppvCardTempModule = nil;
	xmppvCardAvatarModule = nil;
	xmppCapabilities = nil;
	xmppCapabilitiesStorage = nil;
}

#pragma XMPPStream Delegate
-(void)xmppStream:(XMPPStream *)sender socketDidConnect:(GCDAsyncSocket *)socket
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStream:(XMPPStream *)sender willSecureWithSettings:(NSMutableDictionary *)settings
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	if (_allowSelfSignedCertificates)
	{
		[settings setObject:[NSNumber numberWithBool:YES] forKey:(NSString *)kCFStreamSSLAllowsAnyRoot];
	}
	
	if (_allowSSLHostNameMismatch)
	{
		[settings setObject:[NSNull null] forKey:(NSString *)kCFStreamSSLPeerName];
	}
}

- (void)xmppStreamDidSecure:(XMPPStream *)sender
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

-(void)xmppReconnect:(XMPPReconnect *)sender didDetectAccidentalDisconnect:(SCNetworkConnectionFlags)connectionFlags{
    
    DDLogVerbose(@"%@: %@ - Donald King's Reconnect",THIS_FILE, THIS_METHOD);
}

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
    NSError *error = nil;
	[xmppStream secureConnection:&error];
    _isXmppConnected = YES;
    
    //TODO - read password from keychain
    _thisPassword = @"default";
    
    if ([xmppStream isSecure]) {
        if (![[self xmppStream] authenticateWithPassword:_thisPassword error:&error])
        {
            DDLogError(@"Error authenticating: %@", error);
        }
    }
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    if ([XAppDelegate.chatConnectionDelegate respondsToSelector:@selector(loginSuccessful)]) {
        [XAppDelegate.chatConnectionDelegate loginSuccessful];
    }
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    if ([XAppDelegate.chatConnectionDelegate respondsToSelector:@selector(loginUnsuccessful)]) {
        [XAppDelegate.chatConnectionDelegate loginUnsuccessful];
    }
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	return NO;
}



#pragma mark - Login
- (void)doLoginForUsername:(NSString*)theUsername andPassword:(NSString*)thePassword andCallback:(requestCompletedBlock)doLoginCompletionResponse;
{
    //NSLog(@"[%@ %@]",[self class],NSStringFromSelector(_cmd));
    
    [self connectForUsername:theUsername andPasswrod:thePassword andCallBack:^(id completionResponse) {
        
        // Persist username!
      //  NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:theUsername,@"username", nil];
      //  NSLog(@"Will persist to model: %@",params);
        
    /*    [self persistObjectForEntityName:@"CurrentUser" inManagedObjectContext:XAppDelegate.managedObjectContext withDictionary:params andCallback:^(id completionResponse) {
            //
            NSLog(@"Persistence response: %@",completionResponse);
            if ([completionResponse isEqualToString:@"persistObjectForEntityName:OK"]) {
                //[self bootStrap];
                
                NSLog(@"Username persisted");
            }
        }];*/
        
    }];
}

- (BOOL) connectForUsername:(NSString*)theUsername andPasswrod:(NSString*)thePassword andCallBack:(requestCompletedBlock)responseBlock
{
    if (![xmppStream isDisconnected]) {
        return YES;
    }
    
    NSString *jabberID = [NSString stringWithFormat:@"%@@%@/%@",theUsername,_currentHost,_XMPP_RESOURCE_NAME];
    
    if (jabberID == nil || thePassword == nil) {
        return NO;
    }
    
    [xmppStream setMyJID:[XMPPJID jidWithString:jabberID]];
    _thisPassword = thePassword;
    
    NSError *error = nil;
    if (![xmppStream connectWithTimeout:XMPPStreamTimeoutNone error:&error]) {
        
        NSLog(@"conn result: Error");
        
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error connecting"
                                                            message:[NSString stringWithFormat:@"Can't connect to server %@", [error localizedDescription]]
                                                           delegate:nil cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
        
        [alertView show];
        DDLogError(@"Error connecting: %@", error);
        
        // Error connecting
        responseBlock(@"connectForUsername:ERROR");
        return NO;
    }
    // Error
    responseBlock(@"connectForUsername:OK");
    return YES;
}

#pragma mark - Do Logout
-(void)doLogout
{
    NSLog(@"My jid: %@",[xmppStream myJID]);
    
    @try {
        self.username = nil;
        self.password = nil;
        self.profileName = nil;
        self.isXmppConnected = NO;
        self.presence = 0;
    }
    @catch (NSException *exception) {
        NSLog(@"Error resetting params on logout");
    }
    @finally {
        NSLog(@"Params reset finally block");
    }
    
   /* [self clearObjectsForEntityName:@"CurrentUser" inManagedObjectContext:XAppDelegate.managedObjectContext andCallback:^(id completionResponse) {
        //
    }];
    
    [self clearObjectsForEntityName:@"ChatMessages" inManagedObjectContext:XAppDelegate.managedObjectContext andCallback:^(id completionResponse) {
        //
        if ([completionResponse isEqualToString:@"clearObjectsForEntityName:OK"]) {
            
            [xmppvCardStorage clearvCardTempForJID:[xmppStream myJID] xmppStream:xmppStream];
            [xmppRosterStorage clearAllUsersAndResourcesForXMPPStream:xmppStream];
            [xmppRosterStorage clearAllResourcesForXMPPStream:xmppStream];
        }
    }];*/
    
    //TO Remove as its in above
    [xmppvCardStorage clearvCardTempForJID:[xmppStream myJID] xmppStream:xmppStream];
    [xmppRosterStorage clearAllUsersAndResourcesForXMPPStream:xmppStream];
    [xmppRosterStorage clearAllResourcesForXMPPStream:xmppStream];
    
    
    
    [self teardownStream];
    NSLog(@"Calling logoutNotification");
    [[NSNotificationCenter defaultCenter] postNotificationName:@"logoutNotification" object:nil];
    
}



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Core Data
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSManagedObjectContext *)managedObjectContext_roster
{
	return [xmppRosterStorage mainThreadManagedObjectContext];
}

- (NSManagedObjectContext *)managedObjectContext_capabilities
{
	return [xmppCapabilitiesStorage mainThreadManagedObjectContext];
}


- (void)saveContext
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

#pragma mark - Core Data stack
- (void)persistObjectForEntityName:(NSString*)entityName inManagedObjectContext:(NSManagedObjectContext*)context
                    withDictionary:(NSDictionary*)dictionary andCallback:(requestCompletedBlock)completionResponse
{
    NSManagedObject *newObject = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:context];
    
    // Persist objects
    [newObject setValuesForKeysWithDictionary:dictionary];
    
    NSError *error;
    if([XAppDelegate.managedObjectContext save:&error])
    {
        completionResponse(@"persistObjectForEntityName:OK");
        NSLog(@"persisted for entity name: %@",entityName);
    }
    else{
        completionResponse(@"persistObjectForEntityName:ERROR");
    }
}

- (void)checkIfObjectExistsForEntityName:(NSString*)entityName inManagedObjectContext:(NSManagedObjectContext*)context
                             andCallback:(requestCompletedBlock)completionResponse
{
    NSEntityDescription *entityToCheck = [NSEntityDescription entityForName:entityName inManagedObjectContext:context];
    NSFetchRequest *fetchAllObjects = [[NSFetchRequest alloc] init];
    
    [fetchAllObjects setEntity:entityToCheck];
    [fetchAllObjects setIncludesPropertyValues:NO];
    
    NSError *error;
    NSArray *allObjects = [context executeFetchRequest:fetchAllObjects error:&error];
    
    if ([allObjects count]>=1)
    {
        completionResponse(@"checkIfObjectExistsForEntityName:YES");
        NSLog(@"Object exists for entity name: %@",entityName);
        
    }
    else
    {
        completionResponse(@"checkIfObjectExistsForEntityName:NO");
    }
}

-(void)receiveAndPersistObjectForEntityName:(NSString *)entityName inManagedObjectContext:(NSManagedObjectContext *)context withDictionary:(NSDictionary *)dictionary andCallback:(requestCompletedBlock)completionResponse
{
    
    NSLog(@"Saving dictionary: %@",dictionary);
    NSManagedObject *newObject = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:context];
    
    // Persist objects
    [newObject setValuesForKeysWithDictionary:dictionary];
    
    NSError *error;
    if([XAppDelegate.managedObjectContext save:&error])
    {
        completionResponse(@"receiveAndPersistObjectForEntityName:OK");
    }
    else{
        completionResponse(@"receiveAndPersistObjectForEntityName:ERROR");
    }
    
}

// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"YookosChatiPhone" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"YookosChatiPhone.sqlite"];
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
         @{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES}
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _persistentStoreCoordinator;
}

- (void)clearObjectsForEntityName:(NSString*)entityName inManagedObjectContext:(NSManagedObjectContext*)context
                      andCallback:(requestCompletedBlock)completionResponse
{
    NSEntityDescription *entityToDelete = [NSEntityDescription entityForName:entityName inManagedObjectContext:context];
    NSFetchRequest *fetchAllObjects = [[NSFetchRequest alloc] init];
    
    [fetchAllObjects setEntity:entityToDelete];
    [fetchAllObjects setIncludesPropertyValues:NO]; //only fetch the managedObjectID
    
    NSError *error = nil;
    NSArray *allObjects = [context executeFetchRequest:fetchAllObjects error:&error];
    
    for (NSManagedObject *objectToDelete in allObjects) {
        [context deleteObject:objectToDelete];
    }
    
    NSError *saveError = nil;
    
    if (![context save:&saveError]) {
        
        completionResponse(@"clearObjectsForEntityName:ERROR");
    }
    else{
        completionResponse(@"clearObjectsForEntityName:OK");
        NSLog(@"Object cleared for entity name: %@",entityName);
    }
}

- (void)clearObjectForEntityName:(NSString*)entityName withPredicate:(NSPredicate*)predicate inManagedObjectContext:(NSManagedObjectContext*)context andCallback:(requestCompletedBlock)completionResponse
{
    NSEntityDescription *entityToDelete = [NSEntityDescription entityForName:entityName inManagedObjectContext:context];
    NSFetchRequest *fetchObject = [[NSFetchRequest alloc] init];
    
    [fetchObject setEntity:entityToDelete];
    
    NSLog(@"Predicate val: %@",predicate);
    [fetchObject setPredicate:predicate];
    
    NSError *error = nil;
    NSArray *allObjects = [XAppDelegate.managedObjectContext executeFetchRequest:fetchObject error:&error];
    
    for (NSManagedObject *objectToDelete in allObjects) {
        [context deleteObject:objectToDelete];
    }
    
    NSError *saveError = nil;
    
    if (![XAppDelegate.managedObjectContext save:&saveError]) {
        
        completionResponse(@"clearObject:ERROR");
    }
    else{
        completionResponse(@"clearObject:OK");
        NSLog(@"Object cleared for entity name: %@",entityName);
    }
    
}

- (void)checkIfObjectExistsForEntityName:(NSString*)entityName withPredicate:(NSPredicate*)predicate
                  inManagedObjectContext:(NSManagedObjectContext*)context andCallback:(requestCompletedBlock)completionResponse
{
    NSEntityDescription *entityToCheck = [NSEntityDescription entityForName:entityName inManagedObjectContext:context];
    NSFetchRequest *fetchAllObjects = [[NSFetchRequest alloc] init];
    
    [fetchAllObjects setEntity:entityToCheck];
    
    NSLog(@"Predicate val: %@",predicate);
    [fetchAllObjects setPredicate:predicate];
    
    [fetchAllObjects setIncludesPropertyValues:NO];
    
    NSError *error;
    NSArray *allObjects = [context executeFetchRequest:fetchAllObjects error:&error];
    
    if ([allObjects count]>=1)
    {
        completionResponse(@"checkIfObjectExistsForEntityName:YES");
        NSLog(@"Object exists for entity name: %@",entityName);
        
    }
    else
    {
        completionResponse(@"checkIfObjectExistsForEntityName:NO");
    }
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}



@end