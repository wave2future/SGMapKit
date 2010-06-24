//
//  SGMainViewController.m
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

#import "SGMainViewController.h"
#import "SGDynamicPolylineView.h"
#import "SGRecordLine.h"

@interface SGMainViewController (Private) <MKMapViewDelegate, SGLocationServiceDelegate>

- (void) startTimer;
- (void) stopTimer;

- (void) addLine;
- (void) removeLine;

@end

@implementation SGMainViewController

- (id) initWithLayer:(NSString*)layer
{
    if(self = [super init]) {
        self.title = @"SGMapKit Demo";
        
        mapView = [[SGLayerMapView alloc] initWithFrame:CGRectZero];
        mapView.delegate = self;

        updatePointTimer = nil;
        trackedRecord = [[SGRecord alloc] init];
        trackedRecord.recordId = @"sg_mapkit_demo_app_tracked_record";
        trackedRecord.layer = layer;
        trackedRecord.latitude = 0.0;
        trackedRecord.longitude = 0.0;
        
        [[SGLocationService sharedLocationService] addDelegate:self];
    }

    return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UIViewController methods 
//////////////////////////////////////////////////////////////////////////////////////////////// 

- (void) viewDidLoad
{
    mapView.frame = self.view.bounds;
    [self.view addSubview:mapView];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self addLine];    
    [self startTimer];
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self removeLine];
    [self stopTimer];
}

- (void) startTimer
{
    if(!updatePointTimer) {
        updatePointTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0
                                                   target:self
                                                 selector:@selector(updateRecord)
                                                 userInfo:nil
                                                   repeats:YES] retain];
    }
}

- (void) stopTimer
{
    if(updatePointTimer) {
        [updatePointTimer invalidate];
        [updatePointTimer release];
        updatePointTimer = nil;
    }
}

- (void) addLine
{
    SGLocationService* locationService = [SGLocationService sharedLocationService];
    [locationService deleteRecordAnnotation:trackedRecord];
    [locationService updateRecordAnnotation:trackedRecord];
    SGRecordLine* historyLine = [[SGRecordLine alloc] initWithRecordAnnoation:trackedRecord];
    [mapView addOverlay:historyLine];
}

- (void) updateRecord
{
    if(overlayView) {
        CLLocationCoordinate2D coord = {trackedRecord.latitude+1.0, trackedRecord.longitude-1.0};
        [trackedRecord updateCoordinate:coord];
        MKMapRect mapRect = [(SGRecordLine*)overlayView.overlay addCoordinate:coord];
        if(!MKMapRectIsNull(mapRect))
            [overlayView setNeedsDisplayInMapRect:mapRect];
    }
}

- (void) removeLine
{
    [mapView removeOverlays:mapView.overlays];
    [[SGLocationService sharedLocationService] deleteRecordAnnotation:trackedRecord];
}

////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark MKMapView delegate methods 
//////////////////////////////////////////////////////////////////////////////////////////////// 

- (MKOverlayView*) mapView:(MKMapView*)mv viewForOverlay:(id<MKOverlay>)overlay
{
    MKPolyline* polyline = (MKPolyline*)overlay;
    overlayView = [[SGDynamicPolylineView alloc] initWithOverlay:polyline];
    return overlayView;
}

- (void) dealloc
{
    [self removeLine];
    [self stopTimer];
    [mapView release];
    [super dealloc];
}

@end
