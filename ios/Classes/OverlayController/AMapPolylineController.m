//
//  AMapPolylineController.m
//  amap_flutter_map
//
//  Created by lly on 2020/11/6.
//

#import "AMapPolylineController.h"
#import "AMapPolyline.h"
#import "AMapJsonUtils.h"
#import "AMapMarker.h"
#import "MAPolyline+Flutter.h"
#import "MAPolylineRenderer+Flutter.h"
#import "AMapConvertUtil.h"
#import "FlutterMethodChannel+MethodCallDispatch.h"

@interface AMapPolylineController ()

@property (nonatomic,strong) NSMutableDictionary<NSString*,AMapPolyline*> *polylineDict;
@property (nonatomic,strong) FlutterMethodChannel *methodChannel;
@property (nonatomic,strong) NSObject<FlutterPluginRegistrar> *registrar;
@property (nonatomic,strong) MAMapView *mapView;

@end


@implementation AMapPolylineController

- (instancetype)init:(FlutterMethodChannel*)methodChannel
             mapView:(MAMapView*)mapView
           registrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    self = [super init];
    if (self) {
        _methodChannel = methodChannel;
        _mapView = mapView;
        _polylineDict = [NSMutableDictionary dictionaryWithCapacity:1];
        _registrar = registrar;
        
        __weak typeof(self) weakSelf = self;
        [_methodChannel addMethodName:@"polylines#update" withHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
            id polylinesToAdd = call.arguments[@"polylinesToAdd"];
            if ([polylinesToAdd isKindOfClass:[NSArray class]]) {
                [weakSelf addPolylines:polylinesToAdd];
            }
            id polylinesToChange = call.arguments[@"polylinesToChange"];
            if ([polylinesToChange isKindOfClass:[NSArray class]]) {
                [weakSelf changePolylines:polylinesToChange];
            }
            id polylineIdsToRemove = call.arguments[@"polylineIdsToRemove"];
            if ([polylineIdsToRemove isKindOfClass:[NSArray class]]) {
                [weakSelf removePolylineIds:polylineIdsToRemove];
            }
            result(nil);
            
        }];
    }
    return self;
}

- (nullable AMapPolyline *)polylineForId:(NSString *)polylineId {
    return _polylineDict[polylineId];
}

- (void)addPolylines:(NSArray*)polylinesToAdd {
    for (NSDictionary* polyline in polylinesToAdd) {
        AMapPolyline *polylineModel = [AMapJsonUtils modelFromDict:polyline modelClass:[AMapPolyline class]];
        if (polylineModel.customTexture) {
            polylineModel.strokeImage = [AMapConvertUtil imageFromRegistrar:self.registrar iconData:polylineModel.customTexture];
        }
        // ???????????????????????????????????????????????????????????????????????????overlay??????
        if (polylineModel.id_) {
            _polylineDict[polylineModel.id_] = polylineModel;
        }
        [self.mapView addOverlay:polylineModel.polyline];
    }
}

- (void)changePolylines:(NSArray*)polylinesToChange {
    for (NSDictionary* polylineToChange in polylinesToChange) {
        AMapPolyline *polyline = [AMapJsonUtils modelFromDict:polylineToChange modelClass:[AMapPolyline class]];
        AMapPolyline *currentPolyline = _polylineDict[polyline.id_];
        NSAssert(currentPolyline != nil, @"???????????????Polyline?????????");
        // ?????????????????????????????????????????????????????????
        if ([AMapConvertUtil checkIconDescriptionChangedFrom:currentPolyline.customTexture to:polyline.customTexture]) {
            currentPolyline.strokeImage = [AMapConvertUtil imageFromRegistrar:self.registrar iconData:polyline.customTexture];
            currentPolyline.customTexture = polyline.customTexture;
        }
        //???????????????????????????????????????
        [currentPolyline updatePolyline:polyline];
        MAOverlayRenderer *render = [self.mapView rendererForOverlay:currentPolyline.polyline];
        if (render && [render isKindOfClass:[MAPolylineRenderer class]]) { // render?????????????????????????????????????????????????????????
            [(MAPolylineRenderer *)render updateRenderWithPolyline:currentPolyline];
        }
    }
}

- (void)removePolylineIds:(NSArray*)polylineIdsToRemove {
    for (NSString* polylineId in polylineIdsToRemove) {
        if (!polylineId) {
            continue;
        }
        AMapPolyline* polyline = _polylineDict[polylineId];
        if (!polyline) {
            continue;
        }
        [self.mapView removeOverlay:polyline.polyline];
        [_polylineDict removeObjectForKey:polylineId];
    }
}

//MARK: Marker?????????

- (BOOL)onPolylineTap:(NSString*)polylineId {
    if (!polylineId) {
        return NO;
    }
    AMapPolyline* polyline = _polylineDict[polylineId];
    if (!polyline) {
        return NO;
    }
    [_methodChannel invokeMethod:@"polyline#onTap" arguments:@{@"polylineId" : polylineId}];
    return YES;
}

@end
