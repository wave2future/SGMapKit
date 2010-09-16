//
//  SGRegion.m
//  SGMapKit
//
//  Copyright (c) 2009-2010, SimpleGeo
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without 
//  modification, are permitted provided that the following conditions are met:
//
//  Redistributions of source code must retain the above copyright notice, 
//  this list of conditions and the following disclaimer. Redistributions 
//  in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or 
//  other materials provided with the distribution.
//  
//  Neither the name of the SimpleGeo nor the names of its contributors may
//  be used to endorse or promote products derived from this software 
//  without specific prior written permission.
//   
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS 
//  BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE 
//  GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
//  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, 
//  EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//  Created by Derek Smith.
//

#import "SGRegion.h"
#import "SGAdditions.h"
#import "SGPointHelper.h"

@implementation SGRegion
@synthesize gazetteer, polygons;
@dynamic type;

+ (SGRegion*) regionFromFeature:(NSDictionary*)feature
{
    SGRegion* region = [[SGRegion alloc] init];
    
    NSMutableArray* polygons = [NSMutableArray array];
    NSDictionary* geometry = [feature geometry];
    NSArray* coordinates = [geometry coordinates];
    if([geometry isPolygon])
        coordinates = [NSArray arrayWithObject:coordinates];

#if __IPHONE_4_0 && __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_4_0

    for(NSArray* linearRing in coordinates) {
        NSArray* exteriorPolygon = [linearRing objectAtIndex:0];
        
        NSRange range;
        range.location = 1;
        range.length = [linearRing count] - 1;
        
        NSArray* interiorGaps = [linearRing subarrayWithRange:range];
        NSMutableArray* interiorPolygons = [NSMutableArray array];

        for(NSArray* gap in interiorGaps) {
            CLLocationCoordinate2D* coords = SGLonLatArrayToCLLocationCoordArray(gap);
            [interiorPolygons addObject:[MKPolygon polygonWithCoordinates:coords
                                                                    count:[gap count]]];
        }
        
        CLLocationCoordinate2D* coords = SGLonLatArrayToCLLocationCoordArray(exteriorPolygon);
        [polygons addObject:[MKPolygon polygonWithCoordinates:coords
                                                        count:[exteriorPolygon count]
                                             interiorPolygons:interiorPolygons]];
    }

#endif
    
    region.polygons = polygons;
    region.gazetteer = [feature properties];
    
    return region;
}

#pragma mark -
#pragma mark Accessor methods 

- (NSString*) type
{
    NSString* regionType = nil;
    if(gazetteer)
        regionType = [gazetteer objectForKey:@"type"];
    
    return regionType;
}

- (void) dealloc
{
    [gazetteer release];    
    [super dealloc];
}

@end
