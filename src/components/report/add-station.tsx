'use client';

import { useState } from 'react';
import { Check, MapPin, X } from 'lucide-react';
import { useStore } from '@/lib/store';
import { Button } from '@/components/ui/button';
import { hapticSuccess } from '@/lib/haptics';

const BRANDS = ['Татнефть', 'Лукойл', 'Роснефть', 'Газпромнефть', 'ИРБИС', 'Нефтегаз', 'Другой'];

export function AddStation({
  center,
  onDone,
}: {
  center: { lat: number; lng: number };
  onDone: () => void;
}) {
  const { addStation } = useStore();
  const [name, setName] = useState('');
  const [brand, setBrand] = useState(BRANDS[0]);
  const [address, setAddress] = useState('');
  const [done, setDone] = useState(false);

  const submit = () => {
    if (!name.trim()) return;
    addStation({
      name: name.trim(),
      brand,
      address: address.trim() || 'Адрес уточняется',
      lat: center.lat,
      lng: center.lng,
    });
    setDone(true);
    hapticSuccess();
    setTimeout(onDone, 1200);
  };

  if (done) {
    return (
      <div className="flex flex-col items-center justify-center py-12 text-center animate-fade-in">
        <div className="flex h-20 w-20 items-center justify-center rounded-full bg-avail/15">
          <Check className="h-11 w-11 text-avail animate-check-pop" strokeWidth={3} />
        </div>
        <h3 className="mt-4 text-xl font-bold">АЗС добавлена</h3>
        <p className="mt-1 max-w-xs text-sm text-fg-muted">
          Она появится на карте после модерации. Спасибо, что делаете карту полнее!
        </p>
      </div>
    );
  }

  return (
    <div className="animate-fade-in">
      <div className="flex items-start justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">Новая АЗС</h2>
          <p className="mt-0.5 text-sm text-fg-muted">Не нашли заправку? Добавьте её.</p>
        </div>
        <button
          onClick={onDone}
          className="flex h-9 w-9 items-center justify-center rounded-full bg-surface-2 text-fg-muted active:scale-95"
        >
          <X className="h-5 w-5" />
        </button>
      </div>

      <Field label="Название">
        <input
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Например, АЗС №15"
          className="h-12 w-full rounded-xl bg-surface-2 px-3.5 text-[15px] outline-none placeholder:text-fg-subtle focus:ring-2 focus:ring-brand/40"
        />
      </Field>

      <Field label="Бренд">
        <div className="no-scrollbar -mx-1 flex gap-1.5 overflow-x-auto px-1">
          {BRANDS.map((b) => (
            <button
              key={b}
              onClick={() => setBrand(b)}
              className={`shrink-0 rounded-full px-3.5 py-2 text-sm font-semibold ${
                brand === b ? 'bg-brand text-brand-fg' : 'bg-surface-2 text-fg-muted'
              }`}
            >
              {b}
            </button>
          ))}
        </div>
      </Field>

      <Field label="Адрес">
        <input
          value={address}
          onChange={(e) => setAddress(e.target.value)}
          placeholder="Улица, дом"
          className="h-12 w-full rounded-xl bg-surface-2 px-3.5 text-[15px] outline-none placeholder:text-fg-subtle focus:ring-2 focus:ring-brand/40"
        />
      </Field>

      <div className="mt-3 flex items-center gap-2 rounded-xl bg-surface-2 px-3.5 py-3 text-sm text-fg-muted">
        <MapPin className="h-4 w-4 shrink-0 text-brand" />
        Координаты берутся из центра карты: {center.lat.toFixed(4)}, {center.lng.toFixed(4)}
      </div>

      <Button size="lg" className="mt-5 w-full" disabled={!name.trim()} onClick={submit}>
        Добавить АЗС
      </Button>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="mt-4">
      <p className="mb-1.5 text-sm font-semibold text-fg-muted">{label}</p>
      {children}
    </div>
  );
}
