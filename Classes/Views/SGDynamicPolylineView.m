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
#import "SGHistoryLine.h"

@implementation SGDynamicPolylineView

- (id) initWithPolyline:(MKPolyline*)newPolyline
{
    if(self = [super initWithPolyline:newPolyline]) {
        id<SGHistoricRecordAnnoation> annoation = ((SGHistoryLine*)newPolyline).recordAnnotation;
        historyQuery = [[SGHistoryQuery alloc] initWithRecord:annoation];
    }
    
    return self;
}

#pragma mark -
#pragma mark MKOverlayView methods

- (BOOL) canDrawMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale
{
    return historyQuery.requestId == nil ? YES : NO;
}

- (void) createPath
{
    // Maybe semaphores are not required here...
    SGHistoryLine* historyLine = (SGHistoryLine*)self.overlay;
    [historyLine lock];
    
    // TODO: set the path
    
    [historyLine unlock];
}

#pragma mark -
#pragma mark SGLocationService delegate methods 

- (void) locationService:(SGLocationService*)service succeededForResponseId:(NSString*)requestId responseObject:(NSObject*)objects
{
    if(historyQuery && [historyQuery.requestId isEqualToString:requestId]) {
        NSDictionary* newHistory = (NSDictionary*)objects;        
        SGHistoryLine* historyLine = (SGHistoryLine*)self.polyline;
        [historyLine.recordAnnotation updateHistory:newHistory];
        if(historyQuery.cursor)
            [[SGLocationService sharedLocationService] history:historyQuery];
        else
            [self invalidatePath];
        
        historyQuery.requestId = nil;
    }
}

- (void) locationService:(SGLocationService*)service failedForResponseId:(NSString*)requestId error:(NSError*)error
{
    if(historyQuery && [historyQuery.requestId isEqualToString:requestId])
        historyQuery.requestId = nil;
}

- (void) dealloc
{
    [historyQuery release];
    [super dealloc];
}

@end
