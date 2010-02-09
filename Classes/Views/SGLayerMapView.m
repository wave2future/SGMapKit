//
//  SGLayerMapView.m
//  CCLocatorServices
//
//  Created by Derek Smith on 9/30/09.
//  Copyright 2010 SimpleGeo. All rights reserved.
//

#import "SGLayerMapView.h"

@interface SGLayerMapView (Private)

- (BOOL) shouldUpdateMapWithRegion:(SGGeohash)region;
- (void) _retrieveLayers;

- (NSString*) _getKeyForAnnotation:(id<SGRecordAnnotation>)annotation;
- (void) _addNewRecordAnnotations;

@end


@implementation SGLayerMapView

@dynamic reloadTimeInterval;
@synthesize limit, addRetrievedRecordsToLayer;

- (id) initWithFrame:(CGRect)frame
{
    if(self = [super initWithFrame:frame]) {
        
        limit = 100;
        _sgLayers = [[NSMutableDictionary alloc] init];
        _presentAnnotations = [[NSMutableArray alloc] init];
        _trueDelegate = nil;
        reloadTimeInterval = 0.0;
        
        [[SGLocationService sharedLocationService] addDelegate:self];
        
        _layerResponseIds = [[NSMutableArray alloc] init];
        _newRecordAnnotations = [[NSMutableArray alloc] init];
        
        _shouldRetrieveRecords = YES;
        _timer = nil;
        
        [super setDelegate:self];
    }

    return self;
}

- (void) startRetrieving
{
    _shouldRetrieveRecords = YES;
    [self _retrieveLayers];
    
    if(!_timer && reloadTimeInterval >= 0.0)
        _timer = [[NSTimer scheduledTimerWithTimeInterval:reloadTimeInterval
                                                  target:self
                                                selector:@selector(_retrieveLayers) 
                                                userInfo:nil 
                                                 repeats:YES] retain];
}

- (void) stopRetrieving
{
    _shouldRetrieveRecords = NO;

    if(_timer) {
        
        [_timer invalidate];
        [_timer release];
        _timer = nil;
    }
    
}


#pragma mark -
#pragma mark Accessor methods 

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
    _trueDelegate = delegate;
}

- (id<MKMapViewDelegate>) delegate
{
    return _trueDelegate;
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
        [_sgLayers setObject:sgLayer forKey:sgLayer.layerId];
}

- (void) removeLayer:(SGLayer*)sgLayer
{
    if(sgLayer){ 
     
        [_sgLayers removeObjectForKey:sgLayer];
        [self removeAnnotations:[sgLayer recordAnnotations]];
        
    }

}


#pragma mark -
#pragma mark MKMapView delegate methods 
 

- (void) mapView:(MKMapView*)mapView regionWillChangeAnimated:(BOOL)animated
{
    if(_trueDelegate && [_trueDelegate respondsToSelector:@selector(mapView:regionWillChangeAnimated:)])
        [_trueDelegate mapView:mapView regionWillChangeAnimated:animated];
}

- (void) mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
    if(_trueDelegate && [_trueDelegate respondsToSelector:@selector(mapView:regionDidChangeAnimated:)])
        [_trueDelegate mapView:mapView regionWillChangeAnimated:animated];    

    [self _retrieveLayers];
}

- (MKAnnotationView*) mapView:(MKMapView*)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    MKAnnotationView* view = nil;
    if(_trueDelegate && [_trueDelegate respondsToSelector:@selector(mapView:viewForAnnotation:)])
        view = [_trueDelegate mapView:mapView viewForAnnotation:annotation];

    return view;
}

- (void) mapViewDidFailLoadingMap:(MKMapView*)mapView withError:(NSError*)error
{
    if(_trueDelegate && [_trueDelegate respondsToSelector:@selector(mapViewDidFailLoadingMap:withError:)])
        [_trueDelegate mapViewDidFailLoadingMap:mapView withError:error];
}

- (void) mapViewDidFinishLoadingMap:(MKMapView*)mapView
{
    if(_trueDelegate && [_trueDelegate respondsToSelector:@selector(mapViewDidFinishLoadingMap:)])
        [_trueDelegate mapViewDidFinishLoadingMap:mapView];
}

- (void) mapViewWillStartLoadingMap:(MKMapView*)mapView
{
    if(_trueDelegate && [_trueDelegate respondsToSelector:@selector(mapViewWillStartLoadingMap:)])
        [_trueDelegate mapViewWillStartLoadingMap:mapView];
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
{
    if(_trueDelegate && [_trueDelegate respondsToSelector:@selector(mapView:annotationView:calloutAccessoryControlTapped:)])
        [_trueDelegate mapView:mapView annotationView:view calloutAccessoryControlTapped:control];
}

- (void)mapView:(MKMapView *)mapView didAddAnnotationViews:(NSArray*)views
{    
    // Check to see if any of the new records already exist on the map.
    id<SGRecordAnnotation> annotation;
    for(MKAnnotationView* annotationView in views) {
        
        annotation = (id<SGRecordAnnotation>)annotationView.annotation;
        if([annotation conformsToProtocol:@protocol(SGRecordAnnotation)])
            [_presentAnnotations addObject:[self _getKeyForAnnotation:annotation]];
    }    
    
    if(_trueDelegate && [_trueDelegate respondsToSelector:@selector(mapView:didAddAnnotationViews:)])
        [_trueDelegate mapView:mapView didAddAnnotationViews:views];
}


#pragma mark -
#pragma mark SGLocationService delegate methods 
 

- (void) locationService:(SGLocationService*)service succeededForResponseId:(NSString*)requestId responseObject:(NSObject*)objects
{    
    if([_layerResponseIds count] && [_layerResponseIds containsObject:requestId]) {    
        
        NSDictionary* geoJSONObject = (NSDictionary*)objects;
        NSArray* nearbyRecords = nil;
        if([geoJSONObject isFeatureCollection])
            nearbyRecords = [geoJSONObject objectForKey:@"features"];
        else if([geoJSONObject isFeature])
            nearbyRecords = [NSArray arrayWithObject:geoJSONObject];
            
        if(nearbyRecords && [nearbyRecords count]) {
            
            NSDictionary* lastGeoJSONRecord = [nearbyRecords lastObject];
            NSString* recordLayerName = [SGGeoJSONEncoder layerNameFromLayerLink:[lastGeoJSONRecord layerLink]];
            SGLayer* recordLayer = [_sgLayers objectForKey:recordLayerName];
            
            SGLog(@"SGLayerMapView - retrieved %i for %@", [nearbyRecords count], [recordLayer description]);
            
            NSMutableArray* newRecords = [NSMutableArray array];
            id<SGRecordAnnotation> recordAnnotation;
            for(NSDictionary* recordDictionary in nearbyRecords) {

                    recordAnnotation = [recordLayer recordAnnotationFromGeoJSONObject:recordDictionary];
                    if(![_presentAnnotations containsObject:[self _getKeyForAnnotation:recordAnnotation]])
                        [newRecords addObject:recordAnnotation];
                 
            }
            
            if(addRetrievedRecordsToLayer)
                [recordLayer addRecordAnnotations:newRecords];
            
            [_newRecordAnnotations addObjectsFromArray:newRecords];
        }
        
        [_layerResponseIds removeObject:requestId];
        if(![_layerResponseIds count])
            [self _addNewRecordAnnotations];
                
    }
}

- (void) locationService:(SGLocationService*)service failedForResponseId:(NSString*)requestId error:(NSError*)error
{
    if([_layerResponseIds count] && [_layerResponseIds containsObject:requestId]) {   
        
        [_layerResponseIds removeObject:requestId];
     
        if(![_layerResponseIds count])
            [self _addNewRecordAnnotations];

    }
}


#pragma mark -
#pragma mark Zoombox helpers 
 

- (BOOL) shouldUpdateMapWithRegion:(SGGeohash)region
{
    return YES;
}


#pragma mark -
#pragma mark Helper methods 
 
- (void) _addNewRecordAnnotations
{
        
    if([_newRecordAnnotations count]) {
        
        BOOL workingOnMainThread = [NSThread isMainThread];
        
        SGLog(@"SGLayerMapView - Discovered %i new location records.", [_newRecordAnnotations count]);
        
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
                    
                    [_presentAnnotations removeObject:[self _getKeyForAnnotation:annotatedRecord]];
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
            [self addAnnotations:_newRecordAnnotations];        
        else 
            [self performSelectorOnMainThread:@selector(addAnnotations:)
                                   withObject:_newRecordAnnotations
                                waitUntilDone:NO];
        
    }
    
    [_newRecordAnnotations removeAllObjects];
    
}

- (void) _retrieveLayers
{
    if(_shouldRetrieveRecords && ![_newRecordAnnotations count] && ![_layerResponseIds count]) {
        
        // We just care about the center point.
        MKCoordinateRegion region = self.region;
        SGGeohash sgRegion = {region.center.latitude, region.center.longitude, 12};
        
        if([self shouldUpdateMapWithRegion:sgRegion]) {
            
            CLLocation* centerLocation = [[CLLocation alloc] initWithLatitude:self.centerCoordinate.latitude
                                                                    longitude:self.centerCoordinate.longitude];
            CLLocationCoordinate2D leftCornerCoord = [self convertPoint:CGPointZero toCoordinateFromView:self];
            CLLocation* cornerLocation = [[CLLocation alloc] initWithLatitude:leftCornerCoord.latitude
                                                                    longitude:leftCornerCoord.longitude];
            
            double radius = [centerLocation getDistanceFrom:cornerLocation] / 1000.0;
            
            // A little leeway
            radius += (radius * 0.1);
            
            NSArray* layers = [_sgLayers allValues];
            for(SGLayer* recordLayer in layers) 
                [_layerResponseIds addObject:[recordLayer retrieveRecordsForCoordinate:centerLocation.coordinate
                                                                          radius:radius
                                                                           types:nil
                                                                           limit:limit]];
            
            [centerLocation release];
            [cornerLocation release];
        }
    }        
}

- (NSString*) _getKeyForAnnotation:(id<SGRecordAnnotation>)annotation
{
    return [NSString stringWithFormat:@"%@-%@", annotation.layer, annotation.recordId];
}

- (void) dealloc
{
    [self stopRetrieving];
    [_sgLayers release];
    [_presentAnnotations release];
    [_layerResponseIds release];
    [_newRecordAnnotations release];
    
    [[SGLocationService sharedLocationService] removeDelegate:self];
    
    [super dealloc];
}

@end