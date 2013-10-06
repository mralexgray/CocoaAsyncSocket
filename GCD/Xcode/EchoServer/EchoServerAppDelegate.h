#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@class GCDAsyncSocket;


@interface EchoServerAppDelegate : NSObject <NSApplicationDelegate>

@property (assign)	dispatch_queue_t socketQueue;
@property (strong)	GCDAsyncSocket *listenSocket;
@property (strong)	NSMutableArray *connectedSockets;
	
@property	BOOL isRunning;
	
@property (assign)	IBOutlet id logView;
@property (assign)	IBOutlet id portField;
@property (assign)	IBOutlet id startStopButton;
	
@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet WebView *webView;
- (IBAction)startStop:(id)sender;

@end
