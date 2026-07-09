'use client';

import { useEffect, useState } from 'react';
import { Check, CloudOff, Fuel, TriangleAlert, X } from 'lucide-react';
import type { AvailabilityStatus, FuelCode, QueueLength, StationView } from '@/lib/types';
import { FUEL_TYPES } from '@/lib/domain';
import { cn } from '@/lib/utils';
import { Button } from '@/components/ui/button';
import { useStore } from '@/lib/store';
import { hapticSuccess, hapticTap } from '@/lib/haptics';

const STATUS_OPTIONS: {
  value: AvailabilityStatus;
  label: string;
  cls: string;
  activeCls: string;
}[] = [
  { value: 'available', label: 'Есть', cls: 'text-avail', activeCls: 'bg-avail text-white' },
  { value: 'low', label: 'Мало', cls: 'text-low', activeCls: 'bg-low text-white' },
  { value: 'out', label: 'Нет', cls: 'text-out', activeCls: 'bg-out text-white' },
];

const QUEUE_OPTIONS: { value: QueueLength; label: string }[] = [
  { value: 'none', label: 'Нет' },
  { value: 'small', label: 'Небольшая' },
  { value: 'long', label: 'Большая' },
];

export function QuickReport({
  station,
  onDone,
}: {
  station: StationView;
  onDone: () => void;
}) {
  const { submitReport, online } = useStore();
  const available = station.fuels.length
    ? station.fuels.map((f) => f.fuel.code)
    : (['ai92', 'ai95', 'dt'] as FuelCode[]);
  const [fuel, setFuel] = useState<FuelCode>(available[0]);
  const [price, setPrice] = useState('');
  const [status, setStatus] = useState<AvailabilityStatus | null>(null);
  const [queue, setQueue] = useState<QueueLength>('none');
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  const prefill = station.fuels.find((f) => f.fuel.code === fuel)?.price;
  useEffect(() => {
    setPrice('');
    setStatus(null);
  }, [fuel]);

  const canSubmit = price.trim().length > 0 || status !== null;

  const submit = () => {
    setError(null);
    const parsed = price.trim() ? Number(price.replace(',', '.')) : undefined;
    if (parsed !== undefined && (!Number.isFinite(parsed) || parsed <= 0 || parsed > 500)) {
      setError('Введите корректную цену');
      return;
    }
    const res = submitReport({
      stationId: station.id,
      fuelCode: fuel,
      price: parsed,
      status: status ?? undefined,
      queue: status ? queue : undefined,
    });
    if (!res.ok) {
      setError(res.error ?? 'Не удалось отправить');
      hapticTap();
      return;
    }
    setSuccess(true);
    hapticSuccess();
    setTimeout(onDone, 1100);
  };

  if (success) {
    return (
      <div className="flex flex-col items-center justify-center py-12 text-center animate-fade-in">
        <div className="flex h-20 w-20 items-center justify-center rounded-full bg-avail/15">
          <span className="animate-check-pop">
            {online ? (
              <Check className="h-11 w-11 text-avail" strokeWidth={3} />
            ) : (
              <CloudOff className="h-10 w-10 text-low" strokeWidth={2.5} />
            )}
          </span>
        </div>
        <h3 className="mt-4 text-xl font-bold">
          {online ? 'Спасибо! Данные обновлены' : 'Сохранено офлайн'}
        </h3>
        <p className="mt-1 max-w-xs text-sm text-fg-muted">
          {online
            ? 'Другие водители увидят вашу информацию прямо сейчас. +1 к рейтингу доверия.'
            : 'Отправим автоматически, когда появится сеть.'}
        </p>
      </div>
    );
  }

  return (
    <div className="animate-fade-in">
      <div className="flex items-start justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">Обновить данные</h2>
          <p className="mt-0.5 text-sm text-fg-muted">
            {station.name} · {station.brand}
          </p>
        </div>
        <button
          onClick={onDone}
          className="flex h-9 w-9 items-center justify-center rounded-full bg-surface-2 text-fg-muted active:scale-95"
        >
          <X className="h-5 w-5" />
        </button>
      </div>

      {/* 1. Fuel */}
      <p className="mt-5 text-sm font-semibold text-fg-muted">Вид топлива</p>
      <div className="no-scrollbar -mx-4 mt-2 flex gap-2 overflow-x-auto px-4">
        {FUEL_TYPES.filter((f) => available.includes(f.code)).map((f) => (
          <button
            key={f.code}
            onClick={() => {
              setFuel(f.code);
              hapticTap();
            }}
            className={cn(
              'flex h-16 min-w-[76px] shrink-0 flex-col items-center justify-center gap-1 rounded-2xl border-2 px-3 font-bold transition-all active:scale-95',
              fuel === f.code
                ? 'border-brand bg-brand/10 text-brand'
                : 'border-border/60 bg-surface text-fg-muted',
            )}
          >
            <Fuel className="h-4 w-4" />
            <span className="text-sm">{f.label}</span>
          </button>
        ))}
      </div>

      {/* 2. Availability status */}
      <p className="mt-5 text-sm font-semibold text-fg-muted">Наличие</p>
      <div className="mt-2 grid grid-cols-3 gap-2">
        {STATUS_OPTIONS.map((o) => (
          <button
            key={o.value}
            onClick={() => {
              setStatus((s) => (s === o.value ? null : o.value));
              hapticTap();
            }}
            className={cn(
              'flex h-14 items-center justify-center rounded-2xl border-2 text-base font-bold transition-all active:scale-95',
              status === o.value
                ? cn('border-transparent', o.activeCls)
                : cn('border-border/60 bg-surface', o.cls),
            )}
          >
            {o.label}
          </button>
        ))}
      </div>

      {/* queue — appears when low/available */}
      {status && status !== 'out' && (
        <div className="mt-3 animate-fade-in">
          <p className="text-sm font-semibold text-fg-muted">Очередь</p>
          <div className="mt-2 grid grid-cols-3 gap-2">
            {QUEUE_OPTIONS.map((o) => (
              <button
                key={o.value}
                onClick={() => {
                  setQueue(o.value);
                  hapticTap();
                }}
                className={cn(
                  'h-11 rounded-xl text-sm font-semibold transition-all active:scale-95',
                  queue === o.value ? 'bg-fg text-bg' : 'bg-surface-2 text-fg-muted',
                )}
              >
                {o.label}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* 3. Price */}
      <p className="mt-5 text-sm font-semibold text-fg-muted">
        Цена <span className="font-normal text-fg-subtle">(необязательно)</span>
      </p>
      <div className="mt-2 flex items-center gap-2 rounded-2xl border-2 border-border/60 bg-surface px-4 focus-within:border-brand">
        <input
          type="text"
          inputMode="decimal"
          value={price}
          onChange={(e) => setPrice(e.target.value.replace(/[^0-9.,]/g, ''))}
          placeholder={prefill ? prefill.toFixed(2) : '00.00'}
          className="h-16 w-full bg-transparent text-3xl font-extrabold tabular-nums outline-none placeholder:text-fg-subtle/50"
        />
        <span className="text-lg font-bold text-fg-subtle">₽/л</span>
      </div>

      {error && (
        <div className="mt-3 flex items-center gap-2 rounded-xl bg-out/10 px-3 py-2.5 text-sm font-medium text-out">
          <TriangleAlert className="h-4 w-4 shrink-0" /> {error}
        </div>
      )}

      {!online && (
        <div className="mt-3 flex items-center gap-2 rounded-xl bg-low/10 px-3 py-2.5 text-sm font-medium text-low">
          <CloudOff className="h-4 w-4 shrink-0" /> Нет сети — отчёт отправится позже
        </div>
      )}

      <Button
        size="lg"
        className="mt-5 w-full"
        disabled={!canSubmit}
        onClick={submit}
      >
        Отправить
      </Button>
      <p className="mt-2 text-center text-xs text-fg-subtle">
        Занимает 10 секунд · помогает сотням водителей
      </p>
    </div>
  );
}
