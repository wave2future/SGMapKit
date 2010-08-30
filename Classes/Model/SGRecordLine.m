//
//  SGRecordLine.m
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

#import "SGRecordLine.h"
#import "SGAdditions.h"
#import "SGPointHelper.h"

#if __IPHONE_4_0 >= __IPHONE_OS_VERSION_MAX_ALLOWED

#define INITIAL_POINT_SPACE 1000
#define MINIMUM_DELTA_METERS 10.0

@interface SGRecordLine (Private)

- (void) _addCoordinate:(CLLocationCoordinate2D)coord;
- (MKMapRect) mapRectForCoord:(CLLocationCoordinate2D)coordOne andCoord:(CLLocationCoordinate2D)coordTwo;
- (void) generateBoundingMapRect;

@end

@implementation SGRecordLine
@synthesize recordAnnotation, points, pointCount;

- (id) initWithRecordAnnoation:(id<SGHistoricRecordAnnoation>)annotation
{
    if(self = [super init]) {  
        recordAnnotation = annotation;
        points = nil;
        [self reloadAnnotation];        
        pthread_rwlock_init(&rwLock, NULL);        
    }

    return self;
}

- (void) reloadAnnotation
{
    if(points)
        free(points);

    pointSpace = INITIAL_POINT_SPACE;
    points = malloc(sizeof(MKMapPoint) * pointSpace);
    points[0] = MKMapPointForCoordinate(recordAnnotation.coordinate);
    pointCount = 1;
    
    NSDictionary* history = [recordAnnotation history];
    if(history) {
        NSMutableArray* coords = [NSMutableArray array];
        for(NSDictionary* geometry in [history geometries])
            [coords addObject:[geometry coordinates]];
        
        boundingMapRect = [self addCoordinates:SGLonLatArrayToCLLocationCoordArray(coords) count:[coords count]];
    }
}

- (void) generateBoundingMapRect
{
    MKMapPoint origin = points[0];
    origin.x -= MKMapSizeWorld.width / 8.0;
    origin.y -= MKMapSizeWorld.height / 8.0;
    MKMapSize size = MKMapSizeWorld;
    size.width /= 4.0;
    size.height /= 4.0;
    boundingMapRect = (MKMapRect){origin, size};
    MKMapRect worldRect = MKMapRectMake(0, 0, MKMapSizeWorld.width, MKMapSizeWorld.height);
    boundingMapRect = MKMapRectIntersection(boundingMapRect, worldRect);        
}

- (void) lock
{
    pthread_rwlock_rdlock(&rwLock);
}

- (void) unlock
{
    pthread_rwlock_unlock(&rwLock);
}

- (CLLocationCoordinate2D) coordinate
{
    return recordAnnotation.coordinate;
}

- (MKMapRect) boundingMapRect
{
    return boundingMapRect;
}

- (MKMapRect) addCoordinate:(CLLocationCoordinate2D)coord
{
    pthread_rwlock_wrlock(&rwLock);
    [self _addCoordinate:coord];
    pthread_rwlock_unlock(&rwLock);
    
    MKMapRect updatedRect = MKMapRectNull;
    if(pointCount > 0) {
        CLLocationCoordinate2D oldCoord = MKCoordinateForMapPoint(points[pointCount-1]);
        updatedRect = [self mapRectForCoord:oldCoord andCoord:coord];
    }
    
    return updatedRect;
}

- (MKMapRect) addCoordinates:(CLLocationCoordinate2D*)coord count:(int)count
{
    pthread_rwlock_wrlock(&rwLock);    
    for(int i = 0; i < count; i++)
        [self _addCoordinate:coord[i]];
    pthread_rwlock_unlock(&rwLock);
    
    MKMapRect updatedRect = MKMapRectNull;
    if(count > 0 && pointCount > 0) {
        CLLocationCoordinate2D oldCoord = MKCoordinateForMapPoint(points[pointCount-1]);
        updatedRect = [self mapRectForCoord:oldCoord andCoord:coord[0]];
    }
        
    return updatedRect;
}

- (void) _addCoordinate:(CLLocationCoordinate2D)coord
{
    MKMapPoint newPoint = MKMapPointForCoordinate(coord);
    MKMapPoint prevPoint = points[pointCount - 1];
    CLLocationDistance metersApart = MKMetersBetweenMapPoints(newPoint, prevPoint);
    if (metersApart > MINIMUM_DELTA_METERS) {
        if (pointSpace == pointCount) {
            pointSpace *= 2;
            points = realloc(points, pointSpace);
        }
        
        points[pointCount] = newPoint;
        pointCount++;           
    }
}

- (MKMapRect) mapRectForCoord:(CLLocationCoordinate2D)coordOne andCoord:(CLLocationCoordinate2D)coordTwo
{
    MKMapPoint newPoint = MKMapPointForCoordinate(coordOne);
    MKMapPoint prevPoint = MKMapPointForCoordinate(coordTwo);
    double minX = MIN(newPoint.x, prevPoint.x);
    double minY = MIN(newPoint.y, prevPoint.y);
    double maxX = MAX(newPoint.x, prevPoint.x);
    double maxY = MAX(newPoint.y, prevPoint.y);
    return MKMapRectMake(minX, minY, maxX - minX, maxY - minY);
}

- (void) dealloc
{
    free(points);
    pthread_rwlock_destroy(&rwLock);
    [super dealloc];
}

@end

#endif
