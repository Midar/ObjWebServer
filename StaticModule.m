/*
 * ObjWebServer
 * Copyright (C) 2018, 2019  Jonathan Schleifer <js@heap.zone>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#import <ObjFW/ObjFW.h>

#import "Module.h"

@interface StaticModule: OFPlugin <Module>
{
	OFString *_root;
}
@end

@implementation StaticModule
- (void)dealloc
{
	[_root release];

	[super dealloc];
}

- (void)parseConfig: (OFXMLElement *)element
{
	_root = [[[element elementForName: @"root"] stringValue] copy];
}

-      (void)server: (OFHTTPServer *)server
  didReceiveRequest: (OFHTTPRequest *)request
	requestBody: (OFStream *)requestBody
	   response: (OFHTTPResponse *)response
{
}
@end

StaticModule *
init_plugin(void)
{
	return [[[StaticModule alloc] init] autorelease];
}
