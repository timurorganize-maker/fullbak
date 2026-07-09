'use client';

import { useMemo, useState } from 'react';
import { CloudOff, List, MapIcon, Navigation, Plus, User } from 'lucide-react';
import { MapView } from '@/components/map/map-view';
import { FilterBar } from '@/components/map/filter-bar';
import { BottomSheet } from '@/components/ui/bottom-sheet';
import { StationDetail } from '@/components/station/station-detail';
import { QuickReport } from '@/components/report/quick-report';
import { StationList } from '@/components/station/station-list';
import { ProfileView } from '@/components/profile/profile-view';
import { AddStation } from '@/components/report/add-station';
import { useStore } from '@/lib/store';
import { cn } from '@/lib/utils';
import { hapticTap } from '@/lib/haptics';

type Sheet = 'none' | 'station' | 'report' | 'list' | 'profile' | 'addStation';

export default function Home() {
  const { stations, getStation, userLocation, online } = useStore();
  const [sheet, setSheet] = useState<Sheet>('none');
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [recenterKey, setRecenterKey] = useState(0);

  const selected = selectedId ? getStation(selectedId) : undefined;

  const nearest = useMemo(() => {
    if (stations.length === 0) return undefined;
    return stations.reduce((a, b) =>
      (a.distanceKm ?? 9e9) < (b.distanceKm ?? 9e9) ? a : b,
    );
  }, [stations]);

  const reportStation = selected ?? nearest;

  const openStation = (id: string) => {
    setSelectedId(id);
    setSheet('station');
    hapticTap();
  };

  const closeSheet = () => setSheet('none');

  return (
    <main className="relative h-full w-full">
      <MapView
        stations={stations}
        selectedId={sheet === 'station' ? selectedId : null}
        onSelect={openStation}
        userLocation={userLocation}
        recenterKey={recenterKey}
      />

      <FilterBar />

      {/* Offline banner */}
      {!online && (
        <div className="pointer-events-none absolute inset-x-0 top-[calc(env(safe-area-inset-top)+70px)] z-20 flex justify-center px-4">
          <div className="pointer-events-auto inline-flex items-center gap-2 rounded-full bg-low px-3.5 py-2 text-sm font-semibold text-white shadow-pill animate-fade-in">
            <CloudOff className="h-4 w-4" /> Нет сети — работаем офлайн
          </div>
        </div>
      )}

      {/* Recenter button */}
      <button
        onClick={() => {
          setRecenterKey((k) => k + 1);
          hapticTap();
        }}
        className="absolute bottom-[calc(env(safe-area-inset-bottom)+96px)] right-4 z-20 flex h-12 w-12 items-center justify-center rounded-full bg-bg-elevated/90 text-brand shadow-card backdrop-blur-xl active:scale-95"
        aria-label="Моё местоположение"
      >
        <Navigation className="h-5 w-5" />
      </button>

      {/* Bottom navigation */}
      <nav className="absolute inset-x-0 bottom-0 z-20 border-t border-border/50 bg-bg-elevated/90 px-2 pb-[calc(env(safe-area-inset-bottom)+8px)] pt-2 backdrop-blur-xl">
        <div className="mx-auto flex max-w-md items-end justify-around">
          <TabButton
            icon={<MapIcon className="h-6 w-6" />}
            label="Карта"
            active={sheet === 'none' || sheet === 'station'}
            onClick={closeSheet}
          />
          <TabButton
            icon={<List className="h-6 w-6" />}
            label="Список"
            active={sheet === 'list'}
            onClick={() => setSheet('list')}
          />

          {/* Center FAB — the primary driver action */}
          <button
            onClick={() => {
              if (reportStation) {
                setSelectedId(reportStation.id);
                setSheet('report');
                hapticTap();
              }
            }}
            className="-mt-6 flex h-14 w-14 items-center justify-center rounded-full bg-brand text-brand-fg shadow-pill transition-transform active:scale-90"
            aria-label="Обновить данные"
          >
            <Plus className="h-7 w-7" strokeWidth={2.5} />
          </button>

          <TabButton
            icon={<PlusStationIcon />}
            label="Добавить"
            active={sheet === 'addStation'}
            onClick={() => setSheet('addStation')}
          />
          <TabButton
            icon={<User className="h-6 w-6" />}
            label="Профиль"
            active={sheet === 'profile'}
            onClick={() => setSheet('profile')}
          />
        </div>
      </nav>

      {/* Station detail */}
      <BottomSheet
        open={sheet === 'station' && !!selected}
        onClose={closeSheet}
        snapPoints={[0.5, 0.92]}
      >
        {selected && (
          <StationDetail station={selected} onUpdate={() => setSheet('report')} />
        )}
      </BottomSheet>

      {/* Quick report */}
      <BottomSheet
        open={sheet === 'report' && !!reportStation}
        onClose={closeSheet}
        snapPoints={[0.85]}
        backdrop
      >
        {reportStation && (
          <QuickReport
            station={reportStation}
            onDone={() => setSheet(selected ? 'station' : 'none')}
          />
        )}
      </BottomSheet>

      {/* List */}
      <BottomSheet open={sheet === 'list'} onClose={closeSheet} snapPoints={[0.6, 0.92]}>
        <StationList onSelect={openStation} />
      </BottomSheet>

      {/* Profile */}
      <BottomSheet open={sheet === 'profile'} onClose={closeSheet} snapPoints={[0.75, 0.95]}>
        <ProfileView />
      </BottomSheet>

      {/* Add station */}
      <BottomSheet
        open={sheet === 'addStation'}
        onClose={closeSheet}
        snapPoints={[0.75]}
        backdrop
      >
        <AddStation
          center={userLocation ?? { lat: 55.7963, lng: 49.1088 }}
          onDone={closeSheet}
        />
      </BottomSheet>
    </main>
  );
}

function TabButton({
  icon,
  label,
  active,
  onClick,
}: {
  icon: React.ReactNode;
  label: string;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      onClick={() => {
        hapticTap();
        onClick();
      }}
      className={cn(
        'flex w-14 flex-col items-center gap-0.5 py-1 transition-colors',
        active ? 'text-brand' : 'text-fg-subtle',
      )}
    >
      {icon}
      <span className="text-[10px] font-semibold">{label}</span>
    </button>
  );
}

function PlusStationIcon() {
  return (
    <div className="relative h-6 w-6">
      <MapIcon className="h-6 w-6" />
      <Plus className="absolute -right-1 -top-1 h-3.5 w-3.5" strokeWidth={3} />
    </div>
  );
}
