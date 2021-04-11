//  Copyright (C) 2010-2014 Pierre-Olivier Latour <info@pol-online.net>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.

#import "WebServer.h"
#import "DocumentsUpdate.h"
#import "SRDiskUtils.h"
#import <UIKit/UIKit.h>

NSString *const kWebServerStatusUpdateNotificationName = @"org.themilletgrainfromouterspace.maidocs.webserverupdatenotif";

#define kDisconnectLatency 1.0

@interface WebsiteServer : GCDWebUploader
@end

@interface WebDAVServer : GCDWebDAVServer
@end

@implementation WebsiteServer

- (BOOL) shouldUploadFileAtPath:(NSString*)path withTemporaryFile:(NSString*)tempPath {
    return YES;
}

@end

@implementation WebDAVServer

- (BOOL) shouldUploadFileAtPath:(NSString*)path withTemporaryFile:(NSString*)tempPath {
    return YES;
}

@end

@implementation WebServer

@synthesize delegate=_delegate, type=_type;

-(BOOL)isRunning {
    return _webServer.isRunning;
}

+ (instancetype) sharedWebServer {
    static WebServer* server = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        server = [[WebServer alloc] init];
        server.type = kWebServerType_Off;
        [GCDWebServer setLogLevel:4];
    });
    return server;
}

- (void) setType:(WebServerType)type {
    if (type == _type) {
        NSLog(@"%s ignoring same type.", __PRETTY_FUNCTION__);
        return;
    }
    if (_webServer.isRunning) {
        NSLog(@"Stopping server before changing type.");
        [_webServer stop];
        _webServer = nil;
        _type = kWebServerType_Off;
    }
    if (type != kWebServerType_Off) {
        NSString* documentsPath = [SRDiskUtils DocumentsPath];
//        NSArray* fileExtensions = @[@"pdf"];
        if (type == kWebServerType_Website) {
            NSLog(@"%s starting website...", __PRETTY_FUNCTION__);
            
            _webServer = [[WebsiteServer alloc] initWithUploadDirectory:documentsPath];
//            ((WebsiteServer*)_webServer).allowedFileExtensions = fileExtensions;
            ((WebsiteServer*)_webServer).title = UIDevice.currentDevice.name;
            ((WebsiteServer*)_webServer).prologue = [NSString stringWithFormat:@"README! - a file and document transfer app for your local networks."];
            ((WebsiteServer*)_webServer).footer = [NSString stringWithFormat:@"(c) 2018-2021 Luca Cipressi %@",
                                                   [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
        } else if (type == kWebServerType_WebDAV) {
            NSLog(@"%s starting webDAV...", __PRETTY_FUNCTION__);
            _webServer = [[WebDAVServer alloc] initWithUploadDirectory:documentsPath];
//            ((WebDAVServer*)_webServer).allowedFileExtensions = fileExtensions;
        }
        
        if (_webServer) {
            _webServer.delegate = self;
            NSDictionary* options = @{
                                      GCDWebServerOption_Port : @(80),
                                      GCDWebServerOption_ServerName : UIDevice.currentDevice.name,
                                      GCDWebServerOption_ConnectedStateCoalescingInterval : @(kDisconnectLatency)
                                      };
            __autoreleasing NSError* error = nil;
            BOOL success = [_webServer startWithOptions:options error:&error];
            if (success) {
                NSLog(@"GCDWebServer running locally %@ on port %i", _webServer.bonjourName, (int)_webServer.port);
                _type = type;
            } else {
                NSLog(@"Server not started.");
                _webServer = nil;
            }
        }
    }
}

-(void)webServerDidCompleteBonjourRegistration:(GCDWebServer *)server {
    NSLog(@"%s %@", __PRETTY_FUNCTION__, server.bonjourServerURL.path);
}

-(void)webServerDidStop:(GCDWebServer *)server {
    NSLog(@"%s %@", __PRETTY_FUNCTION__, server.bonjourServerURL.path);
    [NSNotificationCenter.defaultCenter postNotificationName:kWebServerStatusUpdateNotificationName object:nil];

}

-(void)webServerDidStart:(GCDWebServer *)server {
    NSLog(@"%s %@", __PRETTY_FUNCTION__, server.bonjourServerURL.path);
    [NSNotificationCenter.defaultCenter postNotificationName:kWebServerStatusUpdateNotificationName object:nil];

}

- (NSString*) ipAddress {
    if (!_webServer.isRunning) {
        return nil;
    }
    NSString* serverURL = _webServer.serverURL.absoluteString;
    if (serverURL == nil) {
        NSString* bonjourServerURL = _webServer.bonjourServerURL.absoluteString;
        return bonjourServerURL;
    }
    return serverURL;
}

- (NSString*) addressLabel {
    NSURL* serverURL = _webServer.serverURL;
    NSURL* bonjourServerURL = _webServer.bonjourServerURL;
    switch (_type) {
        case kWebServerType_Off:
            break;
        case kWebServerType_Both:
        case kWebServerType_Website:
            if (serverURL) {
                if (bonjourServerURL) {
                    return [NSString stringWithFormat:@"%@ %@", bonjourServerURL.absoluteString, serverURL.absoluteString];
                } else {
                    return [NSString stringWithFormat:@"%@", serverURL.absoluteString];
                }
            }
            if (_type == kWebServerType_Website)
                break;
            
        case kWebServerType_WebDAV:
            if (serverURL) {
                if (bonjourServerURL) {
                    return [NSString stringWithFormat:@"WebDAV %@ %@", bonjourServerURL.absoluteString, serverURL.absoluteString];
                } else {
                    return [NSString stringWithFormat:@"WebDAV %@", serverURL.absoluteString];
                }
            }
            break;
            
    }
    return NSLocalizedString(@"ADDRESS_UNAVAILABLE", nil);
}

- (void) webServerDidConnect:(GCDWebServer*)server {
    [_delegate webServerDidConnect:self];
}

- (void) webServerDidDisconnect:(GCDWebServer*)server {
    [_delegate webServerDidDisconnect:self];
}

- (void) webUploader:(GCDWebUploader*)uploader didDownloadFileAtPath:(NSString*)path {
#ifdef DEBUG
    NSLog(@"%s %@", __FUNCTION__, path);
#endif
    
    [_delegate webServerDidDownloadComic:self];
}


- (void) webUploader:(GCDWebUploader*)uploader didUploadFileAtPath:(NSString*)path {
#ifdef DEBUG
    NSLog(@"%s %@", __FUNCTION__, path);
#endif
    
    // NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    // [notificationCenter postNotificationName:ForceLibraryRebuildNotification object:nil userInfo:nil];
    
    [[DocumentsUpdate sharedInstance] queueDocumentsUpdate]; // Queue a documents update
    
    //[_delegate webServerDidUploadComic:self];
}

- (void) webUploader:(GCDWebUploader*)uploader didMoveItemFromPath:(NSString*)fromPath toPath:(NSString*)toPath {
    [_delegate webServerDidUpdate:self];
}

- (void) webUploader:(GCDWebUploader*)uploader didDeleteItemAtPath:(NSString*)path {
#ifdef DEBUG
    NSLog(@"%s %@", __FUNCTION__, path);
#endif
    
    [[DocumentsUpdate sharedInstance] queueDocumentsUpdate];
    [_delegate webServerDidUpdate:self];
}

- (void) webUploader:(GCDWebUploader*)uploader didCreateDirectoryAtPath:(NSString*)path {
#ifdef DEBUG
    NSLog(@"%s %@", __FUNCTION__, path);
#endif
    
    [_delegate webServerDidUpdate:self];
}

- (void) davServer:(GCDWebDAVServer*)server didDownloadFileAtPath:(NSString*)path {
#ifdef DEBUG
    NSLog(@"%s %@", __FUNCTION__, path);
#endif
    
    [_delegate webServerDidDownloadComic:self];
}

- (void) davServer:(GCDWebDAVServer*)server didUploadFileAtPath:(NSString*)path {
#ifdef DEBUG
    NSLog(@"%s %@", __FUNCTION__, path);
#endif
    [[DocumentsUpdate sharedInstance] queueDocumentsUpdate];
    
    [_delegate webServerDidUploadComic:self];
}

- (void) davServer:(GCDWebDAVServer*)server didMoveItemFromPath:(NSString*)fromPath toPath:(NSString*)toPath {
    [_delegate webServerDidUpdate:self];
}

- (void) davServer:(GCDWebDAVServer*)server didCopyItemFromPath:(NSString*)fromPath toPath:(NSString*)toPath {
    [_delegate webServerDidUpdate:self];
}

- (void) davServer:(GCDWebDAVServer*)server didDeleteItemAtPath:(NSString*)path {
#ifdef DEBUG
    NSLog(@"%s %@", __FUNCTION__, path);
#endif
    
    [_delegate webServerDidUpdate:self];
}

- (void) davServer:(GCDWebDAVServer*)server didCreateDirectoryAtPath:(NSString*)path {
#ifdef DEBUG
    NSLog(@"%s %@", __FUNCTION__, path);
#endif
    
    [_delegate webServerDidUpdate:self];
}

@end
