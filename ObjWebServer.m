/*
 * ObjWebServer
 * Copyright (C) 2018, 2019  Jonathan Schleifer <js@heap.zone>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <inttypes.h>

#import <ObjFW/ObjFW.h>

#import "ConfigParser.h"
#import "Module.h"

@interface ObjWebServer: OFObject <OFApplicationDelegate, OFHTTPServerDelegate>
{
	ConfigParser *_config;
	OFArray OF_GENERIC(OFPair OF_GENERIC(OFString *, OFPlugin <Module> *) *)
	    *_modules;
}

- (OFPlugin <Module> *)loadModuleAtPath: (OFString *)path
			     withConfig: (OFXMLElement *)config;
- (void)startWebserverWithListenConfig: (ListenConfig *)listenConfig;
@end

OF_APPLICATION_DELEGATE(ObjWebServer)

@implementation ObjWebServer
- (void)applicationDidFinishLaunching
{
	OFMutableArray OF_GENERIC(OFPair OF_GENERIC(OFString *,
	    OFPlugin <Module> *) *) *modules;

	_config = [[ConfigParser alloc]
	    initWithConfigPath: @"ObjWebServer.xml"];

	modules = [OFMutableArray array];
	for (OFXMLElement *config in [_config modules]) {
		OFString *path =
		    [[config attributeForName: @"path"] stringValue];
		OFString *prefix =
		    [[config attributeForName: @"prefix"] stringValue];
		OFPlugin <Module> *module = [self loadModuleAtPath: path
							withConfig: config];

		[modules addObject: [OFPair pairWithFirstObject: prefix
						   secondObject: module]];
	}
	[modules makeImmutable];
	_modules = [modules copy];

	for (ListenConfig *listenConfig in [_config listenConfigs])
		[self startWebserverWithListenConfig: listenConfig];
}

- (OFPlugin <Module> *)loadModuleAtPath: (OFString *)path
			     withConfig: (OFXMLElement *)config
{
	OFPlugin <Module> *module;

	of_log(@"Loading module at %@", path);

	module = [OFPlugin pluginFromFile: path];
	[module parseConfig: config];

	return module;
}

- (void)startWebserverWithListenConfig: (ListenConfig *)listenConfig
{
	OFHTTPServer *server = [OFHTTPServer server];
	[server setHost: [listenConfig host]];
	[server setPort: [listenConfig port]];

	if ([listenConfig TLSCertificateFile] != nil &&
	    [listenConfig TLSKeyFile] != nil) {
		[server setUsesTLS: true];
		[server setCertificateFile: [listenConfig TLSCertificateFile]];
		[server setPrivateKeyFile: [listenConfig TLSKeyFile]];
	}

	[server setNumberOfThreads: [OFSystemInfo numberOfCPUs] + 1];
	[server setDelegate: self];

	of_log(@"Starting server on host %@ port %" PRIu16,
	    [listenConfig host], [listenConfig port]);

	[server start];
}

-      (void)server: (OFHTTPServer *)server
  didReceiveRequest: (OFHTTPRequest *)request
	requestBody: (OFStream *)requestBody
	   response: (OFHTTPResponse *)response
{
	OFString *path = [[request URL] path];

	of_log(@"Request: %@", request);

	for (OFPair OF_GENERIC(OFString *, id <Module>) *module in _modules)
		if ([path hasPrefix: [module firstObject]])
			if ([[module secondObject] handleRequest: request
						     requestBody: requestBody
							response: response])
				return;
}

-			  (bool)server: (OFHTTPServer *)server
  didReceiveExceptionOnListeningSocket: (id)exception
{
	of_log(@"Exception on listening socket: %@", exception);

	return true;
}
@end
