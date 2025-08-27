import React, { useEffect, useRef, useState } from 'react';
import { Loader } from '@googlemaps/js-api-loader';

interface GoogleMapProps {
  apiKey: string;
  center?: { lat: number; lng: number };
  zoom?: number;
  style?: React.CSSProperties;
  waypoints?: Array<{ lat: number; lng: number; title?: string }>;
}

const GoogleMap: React.FC<GoogleMapProps> = ({ 
  apiKey, 
  center = { lat: 37.5665, lng: 126.9780 }, // 서울 시청
  zoom = 12,
  style = { width: '100%', height: '400px' },
  waypoints = []
}) => {
  const mapRef = useRef<HTMLDivElement>(null);
  const mapInstanceRef = useRef<any>(null);
  const directionsServiceRef = useRef<any>(null);
  const directionsRenderersRef = useRef<any[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [routeInfo, setRouteInfo] = useState<any[]>([]);
  const [optimizedWaypoints, setOptimizedWaypoints] = useState<any[]>([]);

  useEffect(() => {
    const loader = new Loader({
      apiKey: apiKey,
      version: 'weekly',
      libraries: ['marker'],
      mapIds: ['88a6fe7e90395c1f950315b2'] // AdvancedMarkerElement를 위한 Map ID
    });

    loader.load().then(() => {
      console.log('✅ Google Maps 로딩 성공');
      
      if (mapRef.current && !mapInstanceRef.current) {
        // 지도 생성 (AdvancedMarkerElement 지원)
        const map = new (window as any).google.maps.Map(mapRef.current, {
          center: center,
          zoom: zoom,
          mapTypeId: (window as any).google.maps.MapTypeId.ROADMAP,
          mapId: '88a6fe7e90395c1f950315b2' // AdvancedMarkerElement를 위한 Map ID
        });

        mapInstanceRef.current = map;
        directionsServiceRef.current = new (window as any).google.maps.DirectionsService();

        // 최적화된 경유지가 있으면 사용, 없으면 원본 사용
        const pointsToShow = optimizedWaypoints.length > 0 ? optimizedWaypoints : waypoints;
        
        // AdvancedMarkerElement로 마커 추가
        pointsToShow.forEach((point, index) => {
          try {
            // AdvancedMarkerElement 사용 (권장)
            if ((window as any).google.maps.marker && 
                (window as any).google.maps.marker.AdvancedMarkerElement) {
              
              const pinElement = new (window as any).google.maps.marker.PinElement({
                background: '#FF6B6B',
                borderColor: '#FFFFFF',
                glyph: (index + 1).toString(),
                glyphColor: '#FFFFFF'
              });

              new (window as any).google.maps.marker.AdvancedMarkerElement({
                position: { lat: point.lat, lng: point.lng },
                map: map,
                title: point.title || `마커 ${index + 1}`,
                content: pinElement.element
              });
              
              console.log(`✅ AdvancedMarker ${index + 1} 추가: ${point.title} (${point.lat}, ${point.lng})`);
            } else {
              // 폴백: 기존 Marker 사용
              new (window as any).google.maps.Marker({
                position: { lat: point.lat, lng: point.lng },
                map: map,
                title: point.title || `마커 ${index + 1}`,
                label: (index + 1).toString()
              });
              
              console.log(`✅ 기존 Marker ${index + 1} 추가: ${point.title} (${point.lat}, ${point.lng})`);
            }
          } catch (error) {
            console.error(`❌ 마커 ${index + 1} 추가 실패:`, error);
          }
        });

        console.log(`✅ 총 ${waypoints.length}개 마커 추가 완료`);
        
        // 경로가 2개 이상이면 대중교통 경로 계산
        if (waypoints.length >= 2) {
          calculateTransitRoute();
        }
      }
    }).catch((error) => {
      console.error('❌ Google Maps 로딩 실패:', error);
    });

    return () => {
      if (mapInstanceRef.current) {
        mapInstanceRef.current = null;
      }
    };
  }, [apiKey, center.lat, center.lng, zoom, waypoints]);

  // 두 지점 간의 거리 계산 (Haversine 공식)
  const calculateDistance = (lat1: number, lng1: number, lat2: number, lng2: number) => {
    const R = 6371; // 지구의 반지름 (km)
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLng = (lng2 - lng1) * Math.PI / 180;
    const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
              Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
              Math.sin(dLng/2) * Math.sin(dLng/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    return R * c;
  };

  // 최단 경로 최적화 (Nearest Neighbor 알고리즘)
  const optimizeRoute = (points: any[]) => {
    if (points.length <= 2) return points;
    
    const optimized = [];
    const unvisited = [...points];
    
    // 시작점 (첫 번째 지점)
    let current = unvisited.shift();
    optimized.push(current);
    
    // 가장 가까운 다음 지점을 찾아서 순서대로 방문
    while (unvisited.length > 0) {
      let nearestIndex = 0;
      let minDistance = Infinity;
      
      for (let i = 0; i < unvisited.length; i++) {
        const distance = calculateDistance(
          current.lat, current.lng,
          unvisited[i].lat, unvisited[i].lng
        );
        
        if (distance < minDistance) {
          minDistance = distance;
          nearestIndex = i;
        }
      }
      
      current = unvisited.splice(nearestIndex, 1)[0];
      optimized.push(current);
    }
    
    return optimized;
  };

  // 대중교통 경로 계산 함수 (최적화된 경로 사용)
  const calculateTransitRoute = async () => {
    if (!directionsServiceRef.current || waypoints.length < 2) return;

    setIsLoading(true);
    setRouteInfo([]);

    // 경로 최적화 수행
    const optimized = optimizeRoute(waypoints);
    setOptimizedWaypoints(optimized);
    
    console.log('🔍 경로 최적화 결과:');
    optimized.forEach((point, index) => {
      console.log(`${index + 1}. ${point.title} (${point.lat}, ${point.lng})`);
    });

    const routeResults: any[] = [];

    try {
      // 최적화된 경로로 A→B, B→C 순차적으로 경로 계산
      for (let i = 0; i < optimized.length - 1; i++) {
        const origin = optimized[i];
        const destination = optimized[i + 1];

        console.log(`🚇 구간 ${i + 1} 대중교통 경로 계산 시작...`);
        console.log(`📍 출발: ${origin.title} (${origin.lat}, ${origin.lng})`);
        console.log(`📍 도착: ${destination.title} (${destination.lat}, ${destination.lng})`);

        const request = {
          origin: new (window as any).google.maps.LatLng(origin.lat, origin.lng),
          destination: new (window as any).google.maps.LatLng(destination.lat, destination.lng),
          travelMode: (window as any).google.maps.TravelMode.TRANSIT,
          transitOptions: {
            modes: [
              (window as any).google.maps.TransitMode.BUS,
              (window as any).google.maps.TransitMode.SUBWAY,
              (window as any).google.maps.TransitMode.TRAIN,
              (window as any).google.maps.TransitMode.RAIL
            ],
            routingPreference: (window as any).google.maps.TransitRoutePreference.FEWER_TRANSFERS,
            departureTime: new Date()
          }
        };

        const result = await directionsServiceRef.current.route(request);
        
        if (result.routes && result.routes.length > 0) {
          const route = result.routes[0];
          const leg = route.legs[0];
          
          routeResults.push({
            origin: origin.title,
            destination: destination.title,
            duration: leg.duration?.text,
            distance: leg.distance?.text,
            steps: leg.steps || [],
            result: result
          });

          console.log(`✅ 구간 ${i + 1} 대중교통 경로 계산 완료`);
          console.log(`⏱️ 소요시간: ${leg.duration?.text}`);
          console.log(`📏 거리: ${leg.distance?.text}`);
        } else {
          console.log(`❌ 구간 ${i + 1} 대중교통 경로를 찾을 수 없습니다.`);
        }

        // 구간 간 약간의 지연
        if (i < waypoints.length - 2) {
          await new Promise(resolve => setTimeout(resolve, 1000));
        }
      }

      // 모든 경로를 지도에 표시
      if (routeResults.length > 0) {
        setRouteInfo(routeResults);
        
        // 기존 렌더러들 제거
        directionsRenderersRef.current.forEach(renderer => {
          if (renderer) renderer.setMap(null);
        });
        directionsRenderersRef.current = [];
        
        // 각 구간별로 별도의 렌더러 생성
        routeResults.forEach((route, index) => {
          const renderer = new (window as any).google.maps.DirectionsRenderer({
            map: mapInstanceRef.current,
            suppressMarkers: true, // 마커는 우리가 직접 추가
            preserveViewport: index > 0, // 첫 번째 이후는 뷰포트 유지
            polylineOptions: {
              strokeColor: index === 0 ? '#FF6B6B' : '#4ECDC4', // 구간별 다른 색상
              strokeWeight: 6,
              strokeOpacity: 0.8
            }
          });
          
          renderer.setDirections(route.result);
          directionsRenderersRef.current.push(renderer);
        });
        
        console.log(`✅ 총 ${routeResults.length}개 구간 경로 계산 완료`);
      }
    } catch (error) {
      console.error('❌ 경로 계산 실패:', error);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div style={{ position: 'relative' }}>
      <div 
        ref={mapRef} 
        style={style}
        className="google-map"
      />
      
      {/* 로딩 표시 */}
      {isLoading && (
        <div style={{
          position: 'absolute',
          top: '10px',
          left: '10px',
          background: 'rgba(255, 255, 255, 0.9)',
          padding: '10px',
          borderRadius: '5px',
          zIndex: 1000
        }}>
          🚇 경로 계산 중...
        </div>
      )}
      
      {/* 경로 정보 표시 */}
      {routeInfo && routeInfo.length > 0 && (
        <div style={{
          position: 'absolute',
          top: '10px',
          right: '10px',
          background: 'rgba(255, 255, 255, 0.95)',
          padding: '15px',
          borderRadius: '8px',
          zIndex: 1000,
          maxWidth: '350px',
          maxHeight: '500px',
          overflowY: 'auto',
          boxShadow: '0 2px 10px rgba(0,0,0,0.1)'
        }}>
          <div style={{ fontWeight: 'bold', marginBottom: '10px', fontSize: '14px' }}>
            🚇 대중교통 경로 ({routeInfo.length}개 구간)
            {optimizedWaypoints.length > 0 && (
              <span style={{ fontSize: '12px', color: '#4CAF50', marginLeft: '10px' }}>
                ✨ 최적화된 경로
              </span>
            )}
          </div>
          
          {routeInfo.map((route: any, index: number) => (
            <div key={index} style={{ 
              marginBottom: '15px', 
              padding: '10px', 
              background: '#f8f9fa', 
              borderRadius: '5px' 
            }}>
              <div style={{ fontWeight: 'bold', marginBottom: '5px', fontSize: '13px' }}>
                구간 {index + 1}: {route.origin} → {route.destination}
              </div>
              <div style={{ fontSize: '12px', color: '#666' }}>
                <div>⏱️ 소요시간: {route.duration}</div>
                <div>📏 거리: {route.distance}</div>
              </div>
              
              {/* 경로 상세 정보 */}
              {route.steps && route.steps.length > 0 && (
                <div style={{ fontSize: '11px', color: '#888', marginTop: '5px' }}>
                  <div style={{ fontWeight: 'bold', marginBottom: '3px' }}>경로:</div>
                  {route.steps.slice(0, 2).map((step: any, stepIndex: number) => (
                    <div key={stepIndex} style={{ marginBottom: '2px' }}>
                      {step.transit ? (
                        <span>🚇 {step.transit.line?.name || '대중교통'}</span>
                      ) : step.travel_mode === 'WALKING' ? (
                        <span>🚶 도보 {step.distance?.text}</span>
                      ) : (
                        <span>{step.instructions}</span>
                      )}
                    </div>
                  ))}
                  {route.steps.length > 2 && (
                    <div style={{ color: '#999' }}>... 및 {route.steps.length - 2}개 단계</div>
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default GoogleMap;