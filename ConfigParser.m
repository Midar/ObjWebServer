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

#import "ConfigParser.h"

@interface ConfigParser ()
- (void)_parseConfig: (OFXMLElement *)config;
- (void)_parseListens: (OFArray OF_GENERIC(OFXMLElement *) *)elements;
- (void)_parseModules: (OFArray OF_GENERIC(OFXMLElement *) *)elements;
- (void)_invalidConfig: (OFString *)message;
@end

@implementation ListenConfig
@synthesize host = _host, port = _port;
@synthesize TLSCertificateFile = _TLSCertificateFile;
@synthesize TLSKeyFile = _TLSKeyFile;

- (void)dealloc
{
	[_host release];
	[_TLSCertificateFile release];
	[_TLSKeyFile release];

	[super dealloc];
}
@end

@implementation ConfigParser
@synthesize listenConfigs = _listenConfigs, modules = _modules;

- (instancetype)init
{
	OF_INVALID_INIT_METHOD
}

- (instancetype)initWithConfigPath: (OFString *)configPath
{
	self = [super init];

	@try {
		OFXMLElement *config = [[OFXMLElement alloc]
		    initWithFile: configPath];
		@try {
			[self _parseConfig: config];
		} @finally {
			[config release];
		}
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- (void)dealloc
{
	[_listenConfigs release];

	[super dealloc];
}

- (void)_parseConfig: (OFXMLElement *)config
{
	void *pool = objc_autoreleasePoolPush();

	if (config.namespace != nil || ![config.name isEqual: @"ObjWebServer"])
		[self _invalidConfig: @"Root element is not ObjWebServer"];

	[self _parseListens: [config elementsForName: @"listen"]];
	[self _parseModules: [config elementsForName: @"module"]];

	objc_autoreleasePoolPop(pool);
}

- (void)_parseListens: (OFArray OF_GENERIC(OFXMLElement *) *)elements
{
	OFMutableArray OF_GENERIC(ListenConfig *) *listenConfigs =
	    [OFMutableArray array];

	for (OFXMLElement *element in elements) {
		ListenConfig *listenConfig =
		    [[[ListenConfig alloc] init] autorelease];
		OFString *host =
		    [element attributeForName: @"host"].stringValue;
		OFString *portString =
		    [element attributeForName: @"port"].stringValue;
		OFXMLElement *TLS = [element elementForName: @"tls"];

		if (host == nil)
			[self _invalidConfig:
			    @"<listen/> is missing host attribute"];
		if (portString == nil)
			[self _invalidConfig:
			    @"<listen/> is missing port attribute"];

		listenConfig.host = host;

		@try {
			intmax_t port = portString.decimalValue;
			if (port < 0 || port > 65535)
				@throw [OFInvalidFormatException exception];

			listenConfig.port = port;
		} @catch (OFInvalidFormatException *e) {
			[self _invalidConfig: @"<listen/> has invalid port"];
		}

		if (TLS != nil) {
			OFString *certificateFile =
			    [TLS attributeForName: @"cert"].stringValue;
			OFString *keyFile =
			    [TLS attributeForName: @"key"].stringValue;

			if (certificateFile == nil)
				[self _invalidConfig:
				    @"<tls/> has no cert attribute"];
			if (keyFile == nil)
				[self _invalidConfig:
				    @"<tls/> has no key attribute"];

			listenConfig.TLSCertificateFile = certificateFile;
			listenConfig.TLSKeyFile = keyFile;
		}

		[listenConfigs addObject: listenConfig];
	}

	[listenConfigs makeImmutable];
	_listenConfigs = [listenConfigs copy];
}

- (void)_parseModules: (OFArray OF_GENERIC(OFXMLElement *) *)elements
{
	OFMutableArray OF_GENERIC(OFXMLElement *) *modules =
	    [OFMutableArray array];

	for (OFXMLElement *element in elements) {
		OFString *path =
		    [element attributeForName: @"path"].stringValue;
		OFString *prefix =
		    [element attributeForName: @"prefix"].stringValue;

		if (path == nil || prefix == nil)
			[self _invalidConfig:
			    @"<module/> has no path attribute"];

		[modules addObject: element];
	}

	[modules makeImmutable];
	_modules = [modules copy];
}

- (void)_invalidConfig: (OFString *)message
{
	[of_stderr writeFormat: @"Error parsing config: %@", message];
	[OFApplication terminateWithStatus: 1];
}
@end
