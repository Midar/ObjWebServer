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

@implementation ConfigParser
@synthesize listenHosts = _listenHosts, modules = _modules;

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
	[_listenHosts release];

	[super dealloc];
}

- (void)_parseConfig: (OFXMLElement *)config
{
	void *pool = objc_autoreleasePoolPush();

	if ([config namespace] != nil ||
	    ![[config name] isEqual: @"ObjWebServer"])
		[self _invalidConfig: @"Root element is not ObjWebServer"];

	[self _parseListens: [config elementsForName: @"listen"]];
	[self _parseModules: [config elementsForName: @"module"]];

	objc_autoreleasePoolPop(pool);
}

- (void)_parseListens: (OFArray OF_GENERIC(OFXMLElement *) *)elements
{
	OFMutableArray OF_GENERIC(OFPair OF_GENERIC(OFString *, OFNumber *) *)
	    *listenHosts = [OFMutableArray array];

	for (OFXMLElement *element in elements) {
		OFString *host = [[element
		    attributeForName: @"host"] stringValue];
		OFString *portString = [[element
		    attributeForName: @"port"] stringValue];
		OFNumber *port;

		if (host == nil)
			[self _invalidConfig:
			    @"<listen/> is missing host attribute"];
		if (portString == nil)
			[self _invalidConfig:
			    @"<listen/> is missing port attribute"];

		@try {
			intmax_t tmp = [portString decimalValue];
			if (tmp < 0 || tmp > 65535)
				@throw [OFInvalidFormatException exception];

			port = [OFNumber numberWithUInt16: (uint16_t)tmp];
		} @catch (OFInvalidFormatException *e) {
			[self _invalidConfig: @"<listen/> has invalid port"];
		}

		[listenHosts addObject: [OFPair pairWithFirstObject: host
						       secondObject: port]];
	}

	[listenHosts makeImmutable];
	_listenHosts = [listenHosts copy];
}

- (void)_parseModules: (OFArray OF_GENERIC(OFXMLElement *) *)elements
{
	OFMutableArray OF_GENERIC(OFXMLElement *) *modules =
	    [OFMutableArray array];

	for (OFXMLElement *element in elements) {
		OFString *path = [[element
		    attributeForName: @"path"] stringValue];
		OFString *prefix = [[element
		    attributeForName: @"prefix"] stringValue];

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
