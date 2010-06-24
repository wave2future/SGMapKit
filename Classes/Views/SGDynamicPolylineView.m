//
//  SGDynamicPolylineView.m
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

#import "SGDynamicPolylineView.h"
#import "SGLocationService.h"
#import "SGHistoryQuery.h"
#import "SGRecordLine.h"

@interface SGDynamicPolylineView (Private)

- (CGPathRef) createPathForPoints:(MKMapPoint *)points
                       pointCount:(NSUInteger)pointCount
                         clipRect:(MKMapRect)mapRect
                        zoomScale:(MKZoomScale)zoomScale;

@end

@implementation SGDynamicPolylineView
@synthesize fillColor, strokeColor, lineCap, lineJoin;

- (id) initWithOverlay:(id <MKOverlay>)overlay
{
    if(self = [super initWithOverlay:overlay]) {
        fillColor = [UIColor redColor];
        strokeColor = [UIColor redColor];
        lineCap = kCGLineCapRound;
        lineJoin = kCGLineJoinRound;
    }
    
    return self;
}

#pragma mark -
#pragma mark MKOverlayView methods

- (void) drawMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale inContext:(CGContextRef)context
{
    SGRecordLine* historyLine = (SGRecordLine*)self.overlay;
    [historyLine lock];
    CGFloat lineWidth = MKRoadWidthAtZoomScale(zoomScale);
    MKMapRect clipRect = MKMapRectInset(mapRect, -lineWidth, -lineWidth);
    CGPathRef path = [self createPathForPoints:historyLine.points
                                    pointCount:historyLine.pointCount
                                      clipRect:clipRect
                                     zoomScale:zoomScale];
    [historyLine unlock];
    
    if(path) {
        CGContextAddPath(context, path);
        CGContextSetStrokeColorWithColor(context, [strokeColor CGColor]);
        CGContextSetFillColorWithColor(context, [strokeColor CGColor]);
        CGContextSetLineJoin(context, lineJoin);
        CGContextSetLineCap(context, lineCap);
        CGContextSetLineWidth(context, lineWidth);
        CGContextStrokePath(context);
        CGPathRelease(path);
    }
}

static BOOL lineIntersectsRect(MKMapPoint p0, MKMapPoint p1, MKMapRect r) {
    double minX = MIN(p0.x, p1.x);
    double minY = MIN(p0.y, p1.y);
    double maxX = MAX(p0.x, p1.x);
    double maxY = MAX(p0.y, p1.y);
    
    MKMapRect r2 = MKMapRectMake(minX, minY, maxX - minX, maxY - minY);
    return MKMapRectIntersectsRect(r, r2);
}

#define MIN_POINT_DELTA 5.0

- (CGPathRef) createPathForPoints:(MKMapPoint *)points
                      pointCount:(NSUInteger)pointCount
                        clipRect:(MKMapRect)mapRect
                       zoomScale:(MKZoomScale)zoomScale
{    
    if (pointCount < 2)
        return NULL;
    
    CGMutablePathRef path = NULL;
    
    BOOL needsMove = YES;
    
#define POW2(a) ((a) * (a))
    
    double minPointDelta = MIN_POINT_DELTA / zoomScale;
    double c2 = POW2(minPointDelta);
    
    MKMapPoint point, lastPoint = points[0];
    NSUInteger i;
    for (i = 1; i < pointCount - 1; i++) {
        point = points[i];
        double a2b2 = POW2(point.x - lastPoint.x) + POW2(point.y - lastPoint.y);
        if (a2b2 >= c2) {
            if (lineIntersectsRect(point, lastPoint, mapRect)) {
                if (!path) 
                    path = CGPathCreateMutable();
                if (needsMove) {
                    CGPoint lastCGPoint = [self pointForMapPoint:lastPoint];
                    CGPathMoveToPoint(path, NULL, lastCGPoint.x, lastCGPoint.y);
                }
                CGPoint cgPoint = [self pointForMapPoint:point];
                CGPathAddLineToPoint(path, NULL, cgPoint.x, cgPoint.y);
            } else {
                needsMove = YES;
            }
            lastPoint = point;
        }
    }
    
#undef POW2
    
    point = points[pointCount - 1];
    if (lineIntersectsRect(lastPoint, point, mapRect)) {
        if (!path)
            path = CGPathCreateMutable();
        if (needsMove) {
            CGPoint lastCGPoint = [self pointForMapPoint:lastPoint];
            CGPathMoveToPoint(path, NULL, lastCGPoint.x, lastCGPoint.y);
        }
        CGPoint cgPoint = [self pointForMapPoint:point];
        CGPathAddLineToPoint(path, NULL, cgPoint.x, cgPoint.y);
    }
    
    return path;
}

- (void) dealloc
{
    [fillColor release];
    [strokeColor release];
    [super dealloc];
}

@end
