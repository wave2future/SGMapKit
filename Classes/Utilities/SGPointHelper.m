//
//  SGPointHelper.m
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

#include "SGPointHelper.h"

CLLocationCoordinate2D* SGLonLatArrayToCLLocationCoordArray(NSArray* lonLatArray) {
    int count = [lonLatArray count];
    CLLocationCoordinate2D* polyline = malloc(sizeof(CLLocationCoordinate2D)*count);
    NSArray* coordinate = nil;
    for(int i = 0; i < count; i++) {
        coordinate = [lonLatArray objectAtIndex:i];
        CLLocationCoordinate2D coord = {[[coordinate objectAtIndex:1] doubleValue], [[coordinate objectAtIndex:0] doubleValue]};
        polyline[i] = coord;
    }
    
    return polyline;
}

NSArray* SGCLLocationCoordArrayToLonLatArray(CLLocationCoordinate2D* coordArray, int length) {
    NSMutableArray* coordinates = [NSMutableArray arrayWithCapacity:length];
    for(int i = 0; i < length; i++) {
        CLLocationCoordinate2D coord = coordArray[i];
        [coordinates addObject:[NSArray arrayWithObjects:[NSNumber numberWithDouble:coord.longitude],
                                [NSNumber numberWithDouble:coord.latitude],
                                nil]];
    }
    
    return coordinates;
}

#if __IPHONE_4_0 >= __IPHONE_OS_VERSION_MAX_ALLOWED

MKMapRect SGGetAxisAlignedBoundingBox(CLLocationCoordinate2D* coordArray, int length) {
    
    MKMapRect unionMapRect = MKMapRectWorld;
    for(int i = 0; i < length; i++) {
        CLLocationCoordinate2D coord = coordArray[i];
        MKMapPoint point = MKMapPointForCoordinate(coord);
        MKMapRect mapRect = MKMapRectMake(point.x, point.y, 1.0, 1.0);        
        unionMapRect = MKMapRectUnion(mapRect, unionMapRect);
    }

    return unionMapRect;
}

MKMapRect SGEnvelopeToMKMapRect(SGEnvelope envelope) {
    NSString* stringEnvelope = SGEnvelopeGetString(envelope);
    NSArray* coords = [stringEnvelope componentsSeparatedByString:@","];
    CLLocationCoordinate2D* locationCoords = SGLonLatArrayToCLLocationCoordArray(coords);
    return SGGetAxisAlignedBoundingBox(locationCoords, [coords count]);
}

#endif
