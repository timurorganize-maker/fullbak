'use client';

import { useEffect, useRef, useState } from 'react';
import maplibregl, { type Map as MLMap, type GeoJSONSource } from 'maplibre-gl';
import 'maplibre-gl/dist/maplibre-gl.css';
import type { StationView } from '@/lib/types';
import { STATUS_COLOR } from '@/lib/domain';

const STATUS_HEX_LIGHT: Record<string, string> = {
  available: '#30b060',
  low: '#f5b018',
  out: '#eb4034',
  stale: '#9e9eaa',
};

function rasterStyle(dark: boolean): maplibregl.StyleSpecification {
  const base = dark ? 'dark_all' : 'light_all';
  return {
    version: 8,
    sources: {
      carto: {
        type: 'raster',
        tiles: [
          `https://a.basemaps.cartocdn.com/${base}/{z}/{x}/{y}@2x.png`,
          `https://b.basemaps.cartocdn.com/${base}/{z}/{x}/{y}@2x.png`,
          `https://c.basemaps.cartocdn.com/${base}/{z}/{x}/{y}@2x.png`,
        ],
        tileSize: 256,
        attribution: '© OpenStreetMap © CARTO',
      },
    },
    layers: [
      { id: 'bg', type: 'background', paint: { 'background-color': dark ? '#000' : '#f2f2f7' } },
      { id: 'carto', type: 'raster', source: 'carto' },
    ],
  };
}

function toGeoJSON(stations: StationView[]): GeoJSON.FeatureCollection {
  return {
    type: 'FeatureCollection',
    features: stations.map((s) => ({
      type: 'Feature',
      geometry: { type: 'Point', coordinates: [s.lng, s.lat] },
      properties: {
        id: s.id,
        status: s.status,
        color: STATUS_HEX_LIGHT[s.status],
        price: s.cheapest ? s.cheapest.price.toFixed(0) : '',
      },
    })),
  };
}

interface MapViewProps {
  stations: StationView[];
  selectedId: string | null;
  onSelect: (id: string) => void;
  userLocation: { lat: number; lng: number } | null;
  recenterKey?: number;
}

export function MapView({
  stations,
  selectedId,
  onSelect,
  userLocation,
  recenterKey,
}: MapViewProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<MLMap | null>(null);
  const userMarker = useRef<maplibregl.Marker | null>(null);
  const ready = useRef(false);
  const stationsRef = useRef(stations);
  stationsRef.current = stations;
  const [dark, setDark] = useState(
    typeof window !== 'undefined' &&
      window.matchMedia('(prefers-color-scheme: dark)').matches,
  );

  // Track system theme so the map style can follow it.
  useEffect(() => {
    const mq = window.matchMedia('(prefers-color-scheme: dark)');
    const onTheme = () => setDark(mq.matches);
    mq.addEventListener('change', onTheme);
    return () => mq.removeEventListener('change', onTheme);
  }, []);

  // Init map. Re-inits cleanly when the theme flips.
  useEffect(() => {
    if (!containerRef.current) return;

    const map = new maplibregl.Map({
      container: containerRef.current,
      style: rasterStyle(dark),
      center: [userLocation?.lng ?? 49.1088, userLocation?.lat ?? 55.7963],
      zoom: 12,
      attributionControl: false,
      maxZoom: 18,
      minZoom: 4,
    });
    mapRef.current = map;
    map.addControl(new maplibregl.AttributionControl({ compact: true }), 'bottom-right');
    map.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'bottom-right');

    map.on('load', () => {
      map.addSource('stations', {
        type: 'geojson',
        data: toGeoJSON(stationsRef.current),
        cluster: true,
        clusterRadius: 46,
        clusterMaxZoom: 14,
      });

      // Cluster bubbles
      map.addLayer({
        id: 'clusters',
        type: 'circle',
        source: 'stations',
        filter: ['has', 'point_count'],
        paint: {
          'circle-color': '#0a84ff',
          'circle-radius': ['step', ['get', 'point_count'], 18, 5, 22, 15, 28],
          'circle-stroke-width': 3,
          'circle-stroke-color': dark ? '#0b0b0d' : '#ffffff',
        },
      });
      map.addLayer({
        id: 'cluster-count',
        type: 'symbol',
        source: 'stations',
        filter: ['has', 'point_count'],
        layout: {
          'text-field': ['get', 'point_count_abbreviated'],
          'text-size': 13,
          'text-font': ['Open Sans Bold'],
        },
        paint: { 'text-color': '#ffffff' },
      });

      // Individual station dots colored by status
      map.addLayer({
        id: 'station-halo',
        type: 'circle',
        source: 'stations',
        filter: ['!', ['has', 'point_count']],
        paint: {
          'circle-radius': 13,
          'circle-color': ['get', 'color'],
          'circle-opacity': 0.18,
        },
      });
      map.addLayer({
        id: 'station-dot',
        type: 'circle',
        source: 'stations',
        filter: ['!', ['has', 'point_count']],
        paint: {
          'circle-radius': 8,
          'circle-color': ['get', 'color'],
          'circle-stroke-width': 3,
          'circle-stroke-color': dark ? '#1c1c1e' : '#ffffff',
        },
      });
      map.addLayer({
        id: 'station-price',
        type: 'symbol',
        source: 'stations',
        filter: ['!', ['has', 'point_count']],
        layout: {
          'text-field': ['get', 'price'],
          'text-size': 11,
          'text-font': ['Open Sans Bold'],
          'text-offset': [0, 1.4],
          'text-anchor': 'top',
        },
        paint: {
          'text-color': dark ? '#f5f5f7' : '#111114',
          'text-halo-color': dark ? '#000' : '#fff',
          'text-halo-width': 1.4,
        },
      });

      ready.current = true;

      map.on('click', 'clusters', (e) => {
        const features = map.queryRenderedFeatures(e.point, { layers: ['clusters'] });
        const clusterId = features[0]?.properties?.cluster_id;
        const src = map.getSource('stations') as GeoJSONSource;
        if (clusterId == null) return;
        // @ts-expect-error maplibre types are loose here
        src.getClusterExpansionZoom(clusterId, (err: unknown, zoom: number) => {
          if (err) return;
          const geo = features[0].geometry as GeoJSON.Point;
          map.easeTo({ center: geo.coordinates as [number, number], zoom });
        });
      });

      const onDotClick = (e: maplibregl.MapLayerMouseEvent) => {
        const id = e.features?.[0]?.properties?.id as string | undefined;
        if (id) onSelect(id);
      };
      map.on('click', 'station-dot', onDotClick);
      map.on('click', 'station-halo', onDotClick);

      for (const layer of ['clusters', 'station-dot', 'station-halo']) {
        map.on('mouseenter', layer, () => (map.getCanvas().style.cursor = 'pointer'));
        map.on('mouseleave', layer, () => (map.getCanvas().style.cursor = ''));
      }
    });

    return () => {
      map.remove();
      mapRef.current = null;
      ready.current = false;
      userMarker.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [dark]);

  // Push station updates into the source.
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !ready.current) return;
    const src = map.getSource('stations') as GeoJSONSource | undefined;
    if (src) src.setData(toGeoJSON(stations));
  }, [stations]);

  // User location marker.
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !userLocation) return;
    if (!userMarker.current) {
      const el = document.createElement('div');
      el.className = 'user-loc';
      el.innerHTML =
        '<div style="width:18px;height:18px;border-radius:9999px;background:#0a84ff;border:3px solid #fff;box-shadow:0 0 0 4px rgba(10,132,255,0.25)"></div>';
      userMarker.current = new maplibregl.Marker({ element: el })
        .setLngLat([userLocation.lng, userLocation.lat])
        .addTo(map);
    } else {
      userMarker.current.setLngLat([userLocation.lng, userLocation.lat]);
    }
  }, [userLocation]);

  // Recenter to user on demand.
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !userLocation || !recenterKey) return;
    map.easeTo({ center: [userLocation.lng, userLocation.lat], zoom: 13, duration: 600 });
  }, [recenterKey, userLocation]);

  // Fly to selected station.
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !selectedId) return;
    const st = stations.find((s) => s.id === selectedId);
    if (st) {
      map.easeTo({
        center: [st.lng, st.lat],
        zoom: Math.max(map.getZoom(), 14),
        offset: [0, -120],
        duration: 500,
      });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedId]);

  return <div ref={containerRef} className="absolute inset-0" />;
}
