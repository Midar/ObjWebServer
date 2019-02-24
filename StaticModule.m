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

#define BUFFER_SIZE 4096

@interface StaticModule: OFPlugin <Module>
{
	OFString *_root;
	OFDictionary OF_GENERIC(OFString *, OFString *) *_MIMETypes;
}
@end

@interface StaticModule_FileSender: OFObject <OFStreamDelegate>
{
@public
	OFFile *_file;
	OFHTTPResponse *_response;
}
@end

static OFData *
readData(OFStream *stream)
{
	void *buffer;
	OFData *ret;

	if ((buffer = malloc(BUFFER_SIZE)) == NULL)
		@throw [OFOutOfMemoryException
		    exceptionWithRequestedSize: BUFFER_SIZE];

	@try {
		size_t length = [stream readIntoBuffer: buffer
						length: BUFFER_SIZE];

		ret = [OFData dataWithItemsNoCopy: buffer
					    count: length
				     freeWhenDone: true];
	} @catch (id e) {
		free(buffer);
		@throw e;
	}

	return ret;
}

@implementation StaticModule_FileSender
- (void)dealloc
{
	[_file release];
	[_response release];

	[super dealloc];
}

- (OFData *)stream: (OF_KINDOF(OFStream *))stream
      didWriteData: (OFData *)data
      bytesWritten: (size_t)bytesWritten
	 exception: (id)exception
{
	if (exception != nil || [_file isAtEndOfStream])
		return nil;

	return readData(_file);
}
@end

@implementation StaticModule
- (void)dealloc
{
	[_root release];

	[super dealloc];
}

- (void)parseConfig: (OFXMLElement *)config
{
	OFMutableDictionary OF_GENERIC(OFString *, OFString *) *MIMETypes;

	_root = [[[config elementForName: @"root"] stringValue] copy];
	if (_root == nil) {
		[of_stderr writeString:
		    @"Error parsing config: No <root/> element!"];
		[OFApplication terminateWithStatus: 1];
	}

	MIMETypes = [OFMutableDictionary dictionary];
	for (OFXMLElement *MIMEType in [config elementsForName: @"mime-type"]) {
		OFString *extension =
		    [[MIMEType attributeForName: @"extension"] stringValue];
		OFString *type =
		    [[MIMEType attributeForName: @"type"] stringValue];

		if (extension == nil) {
			[of_stderr writeString:
			    @"Error parsing config: "
			    @"<mime-type/> has no extension attribute!"];
			[OFApplication terminateWithStatus: 1];
		}
		if (type == nil) {
			[of_stderr writeString:
			    @"Error parsing config: "
			    @"<mime-type/> has no type attribute!"];
			[OFApplication terminateWithStatus: 1];
		}

		[MIMETypes setObject: type
			      forKey: extension];
	}
	[MIMETypes makeImmutable];
	_MIMETypes = [MIMETypes mutableCopy];
}

- (bool)handleRequest: (OFHTTPRequest *)request
	  requestBody: (OFStream *)requestBody
	     response: (OFHTTPResponse *)response
{
	OFURL *URL = [[request URL] URLByStandardizingPath];
	OFString *path = [URL path];
	OFMutableDictionary *headers = [OFMutableDictionary dictionary];
	OFFileManager *fileManager;
	bool firstComponent = true;
	OFString *MIMEType;
	StaticModule_FileSender *fileSender;

	for (OFString *component in [URL pathComponents]) {
		if (firstComponent && [component length] != 0)
			return false;

		if ([component isEqual: @"."] || [component isEqual: @".."])
			return false;

		firstComponent = false;
	}

	/* TODO: Properly handle for OSes that do not use UNIX paths */
	if (![path hasPrefix: @"/"])
		return false;

	path = [_root stringByAppendingString: path];

	fileManager = [OFFileManager defaultManager];
	if ([fileManager directoryExistsAtPath: path])
		path = [path stringByAppendingPathComponent: @"index.html"];

	if (![fileManager fileExistsAtPath: path]) {
		[response setStatusCode: 404];
		return false;
	}

	MIMEType = [_MIMETypes objectForKey: [path pathExtension]];
	if (MIMEType == nil)
		MIMEType = [_MIMETypes objectForKey: @""];

	if (MIMEType != nil)
		[headers setObject: MIMEType
			    forKey: @"Content-Type"];

	fileSender = [[[StaticModule_FileSender alloc] init] autorelease];
	fileSender->_file = [[OFFile alloc] initWithPath: path
						    mode: @"r"];
	fileSender->_response = [response retain];

	[response setStatusCode: 200];
	[response setHeaders: headers];
	[response setDelegate: fileSender];
	[response asyncWriteData: readData(fileSender->_file)];

	return true;
}
@end

StaticModule *
init_plugin(void)
{
	return [[[StaticModule alloc] init] autorelease];
}
