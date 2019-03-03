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

#import <ObjFW/ObjFW.h>

@interface ConfigParser: OFObject
{
	OFArray OF_GENERIC(OFPair OF_GENERIC(OFString *, OFNumber *) *)
	    *_listenHosts;
	OFArray OF_GENERIC(OFXMLElement *) *_modules;
}

@property (readonly, nonatomic) OFArray OF_GENERIC(
    OFPair OF_GENERIC(OFString *, OFNumber *) *) *listenHosts;
@property (readonly, nonatomic) OFArray OF_GENERIC(OFXMLElement *) *modules;

- (instancetype)init OF_UNAVAILABLE;
- (instancetype)initWithConfigPath: (OFString *)configPath;
@end
