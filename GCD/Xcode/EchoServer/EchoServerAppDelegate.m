#import "EchoServerAppDelegate.h"
#import "GCDAsyncSocket.h"
#import "DDLog.h"
#import "DDTTYLogger.h"

#define WELCOME_MSG  0
#define ECHO_MSG     1
#define WARNING_MSG  2

#define READ_TIMEOUT 15.0
#define READ_TIMEOUT_EXTENSION 10.0

#define FORMAT(format, ...) [NSString stringWithFormat:(format), ##__VA_ARGS__]

@interface EchoServerAppDelegate (PrivateAPI)

- (void)logError:(NSString *)msg;
- (void)logInfo:(NSString *)msg;
- (void)logMessage:(NSString *)msg;

@end

@implementation EchoServerAppDelegate

- (id)init	{	if (self != super.init) return nil;

// Setup our logging framework. Logging isn't used in this file, but can optionally be enabled in GCDAsyncSocket.
	[DDLog addLogger:[DDTTYLogger sharedInstance]];
	
// Setup our server socket (GCDAsyncSocket). 	The socket will invoke our delegate methods using the usual delegate paradigm. However, it will invoke the delegate methods on a specified GCD delegate dispatch queue.

/* Now we can setup these delegate dispatch queues however we want, Here are a few examples:
	- A different delegate queue for each client connection.
	- Simply use the main dispatch queue, so the delegate methods are invoked on the main thread.
	- Add each client connection to the same dispatch queue.

	The best approach for your application will depend upon convenience, requirements and performance.
	For this simple example, we're just going to share the same dispatch queue amongst all client connections. */

	_socketQueue 	= dispatch_queue_create("SocketQueue", NULL);
	_listenSocket 	= [GCDAsyncSocket.alloc initWithDelegate:self delegateQueue:_socketQueue];
	// Setup an array to store all accepted client connections
	_connectedSockets = [[NSMutableArray alloc] initWithCapacity:1];
	_isRunning = NO;
	return self;
}

- (void)awakeFromNib	{	[_logView setString:@""]; [_logView setBackgroundColor:NSColor.darkGrayColor];	}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Reserved
}

- (void)scrollToBottom
{
	NSScrollView *scrollView = [_logView enclosingScrollView];
	NSPoint newScrollOrigin;
	newScrollOrigin = [[scrollView documentView] isFlipped] ?
		 NSMakePoint(0.0F, NSMaxY([[scrollView documentView]frame])) : NSZeroPoint;
	[[scrollView documentView] scrollPoint:newScrollOrigin];
}

- (void)logError:(NSString *)msg
{
	NSString *paragraph = [NSString stringWithFormat:@"%@\n", msg];
	
	NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithCapacity:1];
	[attributes setObject:[NSColor redColor] forKey:NSForegroundColorAttributeName];
	
	NSAttributedString *as = [[NSAttributedString alloc] initWithString:paragraph attributes:attributes];
	[as autorelease];
	
	[[_logView textStorage] appendAttributedString:as];
	[self scrollToBottom];
}

- (void)logInfo:(NSString *)msg
{
	NSString *paragraph = [NSString stringWithFormat:@"%@\n", msg];
	
	NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithCapacity:1];
	[attributes setObject:[NSColor purpleColor] forKey:NSForegroundColorAttributeName];
	
	NSAttributedString *as = [[NSAttributedString alloc] initWithString:paragraph attributes:attributes];
	[as autorelease];
	
	[[_logView textStorage] appendAttributedString:as];
	[self scrollToBottom];
}

- (void)logMessage:(NSString *)msg
{
	NSString *paragraph = [NSString stringWithFormat:@"%@\n", msg];
	
	NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithCapacity:1];
	[attributes setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
	
	NSAttributedString *as = [[NSAttributedString alloc] initWithString:paragraph attributes:attributes];
	[as autorelease];
	
	[[_logView textStorage] appendAttributedString:as];
	[self scrollToBottom];
}

- (IBAction)startStop:(id)sender
{

	int port;
	if(!_isRunning)
	{
		port = [self.portField intValue];
		
		if(port < 0 || port > 65535)
		{
			[self.portField setStringValue:@""];
			port = 0;
		}
		
		NSError *error = nil;
		if(![self.listenSocket acceptOnPort:port error:&error])
		{
			[self logError:FORMAT(@"Error starting server: %@", error)];
			return;
		}
		
		[self logInfo:FORMAT(@"Echo server started on port %hu", [self.listenSocket localPort])];
		self.isRunning = YES;
		
		[self.portField setEnabled:NO];
		[self.startStopButton setTitle:@"Stop"];
	}
	else
	{
		// Stop accepting connections
		[self.listenSocket disconnect];
		
		// Stop any client connections
		@synchronized(self.connectedSockets)
		{
			NSUInteger i;
			for (i = 0; i < [self.connectedSockets count]; i++)
			{
				// Call disconnect on the socket,
				// which will invoke the socketDidDisconnect: method,
				// which will remove the socket from the list.
				[self.connectedSockets[i] disconnect];
			}
		}
		
		[self logInfo:@"Stopped Echo server"];
		self.isRunning = false;
		
		[_portField setEnabled:YES];
		[self.startStopButton setTitle:@"Start"];
	}
	_webView.mainFrameURL = [NSString stringWithFormat:@"http://localhost:%i",port];
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
	// This method is executed on the socketQueue (not the main thread)
	
	@synchronized(_connectedSockets)
	{
		[_connectedSockets addObject:newSocket];
	}
	
	NSString *host = [newSocket connectedHost];
	UInt16 port = [newSocket connectedPort];
	
	dispatch_async(dispatch_get_main_queue(), ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		[self logInfo:FORMAT(@"Accepted client %@:%hu", host, port)];
		
		[pool release];
	});

//   exampleSocket.onmessage = function (event) { console.log(event.data); }

	NSString *welcomeMsg =	@"<!DOCTYPE html><html><head><meta charset='UTF-8' /><style type='text/css>"
									"<!--"
									".chat_wrapper {	width: 100%;margin-right: auto;margin-left: auto;"
									"						background: #CCCCCC;	border: 1px solid #999999;	padding: 10px;"
									"						font: 12px 'UbuntuMono-Bold',tahoma,verdana,arial,sans-serif; }"
									".chat_wrapper .message_box {	background: #FFFFFF;	height: 100%	overflow: auto;"
									"						padding: 10px;	border: 1px solid #999999;	}"
									".chat_wrapper .panel input{	padding: 2px 2px 2px 5px;}"
									".system_msg 	{color: steel ; font-style: italic;}"
									".user_name 		{font-weight:bold;}"
									".user_message 	{color: #88B6E0;}"
									"-->"
									"</style><script src='http://ajax.googleapis.com/ajax/libs/jquery/2.0.0/jquery.min.js'></script>"
									"<script src='http://mrgray.com/websocket-example/socket.js'></script>"
									"</head><body>"
								   @"Welcome to the AsyncSocket Echo Server\r\n"
									"<div id='poop' style='background-color:red;'><h1>HELLO</h1></div>"
		"<script>		//create a new WebSocket object."
		"websocket = new WebSocket('ws://localhost:4444');"
		"websocket.onopen = function(evt) { /* do stuff */ }; //on open event"
		"websocket.onclose = function(evt) { /* do stuff */ }; //on close event"
		"websocket.onmessage = function(evt) { /* do stuff */ }; //on message event"
		"websocket.onerror = function(evt) { /* do stuff */ }; //on error event"
		"websocket.send(message); //send method"
		"websocket.close(); //close method";
		

	NSData *welcomeData = [welcomeMsg dataUsingEncoding:NSUTF8StringEncoding];
	
	[newSocket writeData:welcomeData withTimeout:-1 tag:WELCOME_MSG];
	
	[newSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:READ_TIMEOUT tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
	if (tag == ECHO_MSG)
	{
		[sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:READ_TIMEOUT tag:0];
	}
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
	dispatch_async(dispatch_get_main_queue(), ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		NSData *strData = [data subdataWithRange:NSMakeRange(0, [data length] - 2)];
		NSString *msg = [[[NSString alloc] initWithData:strData encoding:NSUTF8StringEncoding] autorelease];
		if (msg)
		{
			[self logMessage:msg];
		}
		else
		{
			[self logError:@"Error converting received data into UTF-8 String"];
		}
		
		[pool release];
	});
	
	// Echo message back to client
	[sock writeData:data withTimeout:-1 tag:ECHO_MSG];
}

/**
 * This method is called if a read has timed out.
 * It allows us to optionally extend the timeout.
 * We use this method to issue a warning to the user prior to disconnecting them.
**/
- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag
                                                                 elapsed:(NSTimeInterval)elapsed
                                                               bytesDone:(NSUInteger)length
{
	if (elapsed <= READ_TIMEOUT)
	{
		NSString *warningMsg = @"Are you still there?\r\n";
		NSData *warningData = [warningMsg dataUsingEncoding:NSUTF8StringEncoding];
		
		[sock writeData:warningData withTimeout:-1 tag:WARNING_MSG];
		
		return READ_TIMEOUT_EXTENSION;
	}
	
	return 0.0;
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
	if (sock != _listenSocket)
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			[self logInfo:FORMAT(@"Client Disconnected")];
			
			[pool release];
		});
		
		@synchronized(_connectedSockets)
		{
			[_connectedSockets removeObject:sock];
		}
	}
}

@end
