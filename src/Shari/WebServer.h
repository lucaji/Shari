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

#import "GCDWebDAVServer.h"
#import "GCDWebUploader.h"

extern NSString *const kWebServerStatusUpdateNotificationName;


typedef NS_ENUM(NSInteger, WebServerType) {
    kWebServerType_Off = 0,
    kWebServerType_Website = 1,
    kWebServerType_WebDAV = 2,
    kWebServerType_Both = 4
};

@class WebServer;

@protocol WebServerDelegate <NSObject>
- (void) webServerDidConnect:(WebServer*)server;
- (void) webServerDidUploadComic:(WebServer*)server;
- (void) webServerDidDownloadComic:(WebServer*)server;
- (void) webServerDidUpdate:(WebServer*)server;
- (void) webServerDidDisconnect:(WebServer*)server;
@end

@interface WebServer : NSObject <GCDWebUploaderDelegate, GCDWebDAVServerDelegate> {
@private
    GCDWebServer* _webServer;
}

+(instancetype)sharedWebServer;

@property (nonatomic, weak) id<WebServerDelegate> delegate;
@property (nonatomic) WebServerType type;
@property (nonatomic, readonly) NSString* addressLabel;
@property (nonatomic, readonly) NSString* ipAddress;
@property (nonatomic, readonly) BOOL isRunning;
@end
