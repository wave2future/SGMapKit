//
//  SGLayerMapView.m
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

#import "SGLayerMapView.h"
#import "SGAdditions.h"
#import "SGLatLonNearbyQuery.h"
#import "SGRecordLine.h"
#import "SGRegion.h"

#import "SGAdditions.h"

@interface SGLayerMapView (Private)

- (BOOL) shouldUpdateMapWithRegion:(SGGeohash)region;
- (void) retrieveLayers;

- (NSString*) getKeyForAnnotation:(id<SGRecordAnnotation>)annotation;
- (void) addNewRecordAnnotations;

- (void) initializeMapView;

@end

@implementation SGLayerMapView
@dynamic reloadTimeInterval;
@synthesize limit, addRetrievedRecordsToLayer, requestStartTime, requestEndTime;

- (void) awakeFromNib
{
    [self initializeMapView];
}

- (id) initWithFrame:(CGRect)frame
{
    if(self = [super initWithFrame:frame])
        [self initializeMapView];

    return self;
}

- (void) initializeMapView
{
    limit = 25;
    sgLayers = [[NSMutableDictionary alloc] init];
    presentAnnotations = [[NSMutableArray alloc] init];
    trueDelegate = nil;
    reloadTimeInterval = 0.0;
    
    [[SGLocationService sharedLocationService] addDelegate:self];
    
    layerResponseIds = [[NSMutableArray alloc] init];
    newRecordAnnotations = [[NSMutableArray alloc] init];
    
    addRetrievedRecordsToLayer = YES;
    timer = nil;
    
    requestStartTime = 0.0;
    requestEndTime = 0.0;
    
    containsResponseId = nil;
    validRegionTypes = nil;
    
    [super setDelegate:self];    
}

- (void) startRetrieving
{
    [self retrieveLayers];
    
    if(!timer && reloadTimeInterval >= 0.0)
        timer = [[NSTimer scheduledTimerWithTimeInterval:reloadTimeInterval
                                                  target:self
                                                selector:@selector(retrieveLayers) 
                                                userInfo:nil 
                                                 repeats:YES] retain];
}

- (void) stopRetrieving
{
    if(timer) {
        [timer invalidate];
        [timer release];
        timer = nil;
    }
}

#pragma mark -
#pragma mark Accessor methods 

- (NSArray*) layers
{
    return [sgLayers allValues];
}

- (void) setReloadTimeInterval:(NSTimeInterval)time
{
    reloadTimeInterval = time;
    [self stopRetrieving];
    [self startRetrieving];
}

- (NSTimeInterval) reloadTimeInterval
{
    return reloadTimeInterval;
}
 
- (void) setDelegate:(id<MKMapViewDelegate>)delegate
{
    trueDelegate = delegate;
}

- (id<MKMapViewDelegate>) delegate
{
    return trueDelegate;
}

- (void) addLayers:(NSArray*)layers
{
    for(SGLayer* sgLayer in layers)
        [self addLayer:sgLayer];
}

- (void) removeLayers:(NSArray*)layers
{
    for(SGLayer* sgLayer in layers)
        [self removeLayer:sgLayer];
}

- (void) addLayer:(SGLayer*)sgLayer
{
    if(sgLayer)
        [sgLayers setObject:sgLayer forKey:sgLayer.layerId];
}

- (void) removeLayer:(SGLayer*)sgLayer
{
    if(sgLayer){
        if(sgLayer.recentNearbyQuery && sgLayer.recentNearbyQuery.requestId)
            [layerResponseIds removeObject:sgLayer.recentNearbyQuery.requestId];

        [sgLayers removeObjectForKey:sgLayer.layerId];
        [self removeAnnotations:[sgLayer recordAnnotations]];   
    }
}

#pragma mark -
#pragma mark MKMapView delegate methods

- (void) mapView:(MKMapView*)mapView regionWillChangeAnimated:(BOOL)animated
{
    if(trueDelegate && [trueDelegate respondsToSelector:@selector(mapView:regionWillChangeAnimated:)])
        [trueDelegate mapView:mapView regionWillChangeAnimated:animated];
}

- (void) mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
    if(trueDelegate && [trueDelegate respondsToSelector:@selector(mapView:regionDidChangeAnimated:)])
        [trueDelegate mapView:mapView regionDidChangeAnimated:animated];    

    [self retrieveLayers];
}

- (MKAnnotationView*) mapView:(MKMapView*)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    MKAnnotationView* view = nil;
    if(trueDelegate && [trueDelegate respondsToSelector:@selector(mapView:viewForAnnotation:)])
        view = [trueDelegate mapView:mapView viewForAnnotation:annotation];

    return view;
}

- (void) mapViewDidFailLoadingMap:(MKMapView*)mapView withError:(NSError*)error
{
    if(trueDelegate && [trueDelegate respondsToSelector:@selector(mapViewDidFailLoadingMap:withError:)])
        [trueDelegate mapViewDidFailLoadingMap:mapView withError:error];
}

- (void) mapViewDidFinishLoadingMap:(MKMapView*)mapView
{
    if(trueDelegate && [trueDelegate respondsToSelector:@selector(mapViewDidFinishLoadingMap:)])
        [trueDelegate mapViewDidFinishLoadingMap:mapView];
}

- (void) mapViewWillStartLoadingMap:(MKMapView*)mapView
{
    if(trueDelegate && [trueDelegate respondsToSelector:@selector(mapViewWillStartLoadingMap:)])
        [trueDelegate mapViewWillStartLoadingMap:mapView];
}

- (void) mapView:(MKMapView*)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
{
    if(trueDelegate && [trueDelegate respondsToSelector:@selector(mapView:annotationView:calloutAccessoryControlTapped:)])
        [trueDelegate mapView:mapView annotationView:view calloutAccessoryControlTapped:control];
}

- (void) mapView:(MKMapView*)mapView didAddAnnotationViews:(NSArray*)views
{    
    // Check to see if any of the new records already exist on the map.
    id<SGRecordAnnotation> annotation;
    for(MKAnnotationView* annotationView in views) {
        annotation = (id<SGRecordAnnotation>)annotationView.annotation;
        NSString* key = [self getKeyForAnnotation:annotation];
        if(key)
            [presentAnnotations addObject:key];
    }    
    
    if(trueDelegate && [trueDelegate respondsToSelector:@selector(mapView:didAddAnnotationViews:)])
        [trueDelegate mapView:mapView didAddAnnotationViews:views];
}

#if __IPHONE_4_0 && __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_4_0

- (MKOverlayView*) mapView:(MKMapView*)mapView viewForOverlay:(id<MKOverlay>)overlay
{
    MKOverlayView* view = nil;
    if(trueDelegate && [trueDelegate respondsToSelector:@selector(mapView:viewForOverlay:)])
        view = [trueDelegate mapView:mapView viewForOverlay:overlay];
    
    return view;
}

- (void) mapView:(MKMapView*)mapView didAddOverlayViews:(NSArray*)overlayViews
{   
    if(trueDelegate && [trueDelegate respondsToSelector:@selector(mapView:didAddOverlayViews:)])
        [trueDelegate mapView:mapView didAddOverlayViews:overlayViews];
}

- (void) mapView:(MKMapView*)mapView annotationView:(MKAnnotationView*)annotationView didChangeDragState:(MKAnnotationViewDragState)newState fromOldState:(MKAnnotationViewDragState)oldState
{
    if(trueDelegate && [trueDelegate respondsToSelector:@selector(mapView:annotationView:didChangeDragState:fromOldState:)])
        [trueDelegate mapView:mapView annotationView:annotationView didChangeDragState:newState fromOldState:oldState];
}

- (void) mapViewWillStartLocatingUser:(MKMapView*)mapView
{
    if(trueDelegate && [trueDelegate respondsToSelector:@selector(mapViewWillStartLocatingUser:)])
        [trueDelegate mapViewWillStartLocatingUser:mapView];    
}

- (void) mapViewDidStopLocatingUser:(MKMapView*)mapView
{
    if(trueDelegate && [trueDelegate respondsToSelector:@selector(mapViewDidStopLocatingUser:)])
        [trueDelegate mapViewDidStopLocatingUser:mapView];    
}

- (void) mapView:(MKMapView*)mapView didUpdateUserLocation:(MKUserLocation*)userLocation
{
    if(trueDelegate && [trueDelegate respondsToSelector:@selector(mapView:didUpdateUserLocation:)])
        [trueDelegate mapView:mapView didUpdateUserLocation:userLocation];    
}

- (void) mapView:(MKMapView*)mapView didFailToLocateUserWithError:(NSError*)error
{
    if(trueDelegate && [trueDelegate respondsToSelector:@selector(mapView:didFailToLocateUserWithError:)])
        [trueDelegate mapView:mapView didFailToLocateUserWithError:error];
}

- (void) drawRegionsForLocation:(CLLocation*)location types:(NSArray*)types
{
    if(!containsResponseId) {
        SGLocationService* locationService = [SGLocationService sharedLocationService];
        containsResponseId = [locationService contains:location.coordinate];
        if(types)
            validRegionTypes = [types retain];
        else
            validRegionTypes = nil;
    }
}

#endif

#pragma mark -
#pragma mark SGLocationService delegate methods 
 
- (void) locationService:(SGLocationService*)service succeededForResponseId:(NSString*)requestId responseObject:(NSObject*)objects
{    
    if([layerResponseIds containsObject:requestId]) {    
        NSDictionary* geoJSONObject = (NSDictionary*)objects;
        NSArray* nearbyRecords = nil;
        if([geoJSONObject isFeatureCollection])
            nearbyRecords = [geoJSONObject objectForKey:@"features"];
        else if([geoJSONObject isFeature])
            nearbyRecords = [NSArray arrayWithObject:geoJSONObject];
            
        if(nearbyRecords && [nearbyRecords count]) {
            NSDictionary* lastGeoJSONRecord = [nearbyRecords lastObject];
            NSString* recordLayerName = [SGGeoJSONEncoder layerNameFromLayerLink:[lastGeoJSONRecord layerLink]];
            SGLayer* recordLayer = [sgLayers objectForKey:recordLayerName];
            
            SGLog(@"SGLayerMapView - retrieved %i for %@", [nearbyRecords count], recordLayerName);
            
            NSMutableArray* newRecords = [NSMutableArray array];
            id<SGRecordAnnotation> recordAnnotation = nil;
            NSString* annotationKey = nil;
            for(NSDictionary* recordDictionary in nearbyRecords) {
                    recordAnnotation = [recordLayer recordAnnotationFromGeoJSONObject:recordDictionary];
                    annotationKey = [self getKeyForAnnotation:recordAnnotation];
                    if(annotationKey && ![presentAnnotations containsObject:annotationKey])
                        [newRecords addObject:recordAnnotation];
            }
            
            if(addRetrievedRecordsToLayer)
                [recordLayer addRecordAnnotations:newRecords update:NO];
            
            [newRecordAnnotations addObjectsFromArray:newRecords];
        }
        
        [layerResponseIds removeObject:requestId];
        if(![layerResponseIds count])
            [self addNewRecordAnnotations];
    } else if(containsResponseId && [containsResponseId isEqualToString:requestId]) {
        // Fire of more requests because we will need to have the polygon information
        // for each boundary
        NSMutableArray* validRegionIds = [NSMutableArray array];
        for(NSDictionary* feature in (NSArray*)objects) {
            if(validRegionTypes && [validRegionTypes count]) {
                if([validRegionTypes containsObject:[[feature properties] objectForKey:@"type"]])
                    [validRegionIds addObject:[feature recordId]];
            } else
                [validRegionIds addObject:[feature objectForKey:@"id"]];
        }
        
        if([validRegionIds count]) {
            SGLocationService* locationService = [SGLocationService sharedLocationService];
            boundaryResponseIds = [[NSMutableArray alloc] init];
            for(NSString* validRegionId in validRegionIds)
                [boundaryResponseIds addObject:[locationService boundary:validRegionId]];
        }
        containsResponseId = nil;
    } 

#if __IPHONE_4_0 && __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_4_0

    else if(boundaryResponseIds && [boundaryResponseIds containsObject:requestId]) {
        NSDictionary* feature = (NSDictionary*)objects;
        SGRegion* region = [SGRegion regionFromFeature:feature];
        [regions addObject:region];
        for(MKPolygon* polygon in region.polygons)
            [self addOverlay:polygon];
        [boundaryResponseIds removeObject:requestId];        
    }

#endif

}

- (void) locationService:(SGLocationService*)service failedForResponseId:(NSString*)requestId error:(NSError*)error
{
    if([layerResponseIds count] && [layerResponseIds containsObject:requestId]) {   
        [layerResponseIds removeObject:requestId];
        if(![layerResponseIds count])
            [self addNewRecordAnnotations];
    } else if(containsResponseId && [containsResponseId isEqualToString:requestId]) {
        [boundaryResponseIds release];
        containsResponseId = nil;
    } else if(boundaryResponseIds && [boundaryResponseIds containsObject:requestId]) {
        [boundaryResponseIds removeObject:requestId];
    }
}

#pragma mark -
#pragma mark Zoombox helpers 

- (BOOL) shouldUpdateMapWithRegion:(SGGeohash)region
{
    // We want to add some logic here so we aren't updating
    // the map for everyone plain old region that comes in.
    return YES;
}

#pragma mark -
#pragma mark Helper methods 
 
- (void) addNewRecordAnnotations
{
    if([newRecordAnnotations count]) {
        BOOL workingOnMainThread = [NSThread isMainThread];
        
        SGLog(@"SGLayerMapView - Discovered %i new location records.", [newRecordAnnotations count]);
        
        NSArray* annotations = [self annotations];
        if(annotations && [annotations count]) {
            
            NSMutableArray* annotationsToRemove = [NSMutableArray array];
            
            CGFloat leeway = 10.0;
            CGPoint point = CGPointMake(self.frame.size.width + leeway, self.frame.size.height + leeway);
            
            // Check every annotation to see if it still deserves to be shown
            // or registered with the map
            CGPoint recordViewPoint;
            for(id<SGRecordAnnotation> annotatedRecord in annotations) {
                recordViewPoint = [self convertCoordinate:annotatedRecord.coordinate toPointToView:self];
                
                if(recordViewPoint.x > point.x || recordViewPoint.x < -leeway  ||
                   recordViewPoint.y > point.y || recordViewPoint.y < -leeway) {
                    
                    [presentAnnotations removeObject:[self getKeyForAnnotation:annotatedRecord]];
                    [annotationsToRemove addObject:annotatedRecord];
                }
            }
            
            if(workingOnMainThread)
                [self removeAnnotations:annotationsToRemove];
            else
                [self performSelectorOnMainThread:@selector(removeAnnotations:)
                                       withObject:annotationsToRemove
                                    waitUntilDone:YES];
        }
        
        if(workingOnMainThread)
            [self addAnnotations:newRecordAnnotations];        
        else 
            [self performSelectorOnMainThread:@selector(addAnnotations:)
                                   withObject:newRecordAnnotations
                                waitUntilDone:NO];
        
    }
    
    [newRecordAnnotations removeAllObjects];
    
}

- (void) retrieveLayers
{
    if(![newRecordAnnotations count] && ![layerResponseIds count]) {
        
        // We just care about the center point.
        MKCoordinateRegion region = self.region;
        SGGeohash sgRegion = {region.center.latitude, region.center.longitude, 12};
        
        if([self shouldUpdateMapWithRegion:sgRegion]) {
            
            CLLocation* centerLocation = [[CLLocation alloc] initWithLatitude:self.centerCoordinate.latitude
                                                                    longitude:self.centerCoordinate.longitude];
            CLLocationCoordinate2D leftCornerCoord = [self convertPoint:CGPointZero toCoordinateFromView:self];
            CLLocation* cornerLocation = [[CLLocation alloc] initWithLatitude:leftCornerCoord.latitude
                                                                    longitude:leftCornerCoord.longitude];
            
            double radius = [centerLocation distanceFromLocation:cornerLocation] / 1000.0;
            
            // A little leeway
            radius += (radius * 0.1);
            
            SGLatLonNearbyQuery* query = [[SGLatLonNearbyQuery alloc] init];
            query.radius = radius;
            query.limit = limit;
            query.start = requestStartTime;
            query.end = requestEndTime;
            query.coordinate = centerLocation.coordinate;
            
            NSArray* layers = [sgLayers allValues];
            for(SGLayer* recordLayer in layers) {
                NSString* requestId = nil;
                if(recordLayer.recentNearbyQuery && [recordLayer.recentNearbyQuery isKindOfClass:[SGLatLonNearbyQuery class]]) {
                    SGLatLonNearbyQuery* layerQuery = (SGLatLonNearbyQuery*)recordLayer.recentNearbyQuery;
                    if(layerQuery.coordinate.latitude == query.coordinate.latitude &&
                       layerQuery.coordinate.longitude == query.coordinate.longitude)
                        requestId = [recordLayer nextNearby];
                }
                
                if(!requestId)
                    requestId = [recordLayer nearby:query];
                
                [layerResponseIds addObject:requestId];
            }
            
            [centerLocation release];
            [cornerLocation release];
            [query release];
        }
    }        
}

- (NSString*) getKeyForAnnotation:(id<SGRecordAnnotation>)annotation
{
    return [annotation conformsToProtocol:@protocol(SGRecordAnnotation)] ? [NSString stringWithFormat:@"%@-%@", annotation.layer, annotation.recordId] : nil;
}

- (void) dealloc
{
    [self stopRetrieving];
    [sgLayers release];
    [presentAnnotations release];
    [layerResponseIds release];
    [newRecordAnnotations release];
    
    [containsResponseId release];
    
    [[SGLocationService sharedLocationService] removeDelegate:self];
    
    [super dealloc];
}

@end