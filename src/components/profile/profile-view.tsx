'use client';

import { Award, Flame, ShieldCheck, TrendingUp, Trophy, Zap } from 'lucide-react';
import { useStore } from '@/lib/store';
import { driverLevel } from '@/lib/domain';
import { cn, formatPrice, timeAgo } from '@/lib/utils';
import { AVAIL_LABEL } from '@/lib/domain';
import type { AvailabilityReport, PriceReport } from '@/lib/types';

export function ProfileView() {
  const { user, myReports, pendingQueue } = useStore();
  const level = driverLevel(user.trust_score);
  const progress = level.next
    ? Math.min(100, ((user.trust_score - level.min) / (level.next - level.min)) * 100)
    : 100;

  return (
    <div className="animate-fade-in">
      {/* Identity */}
      <div className="flex items-center gap-4">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-gradient-to-br from-brand to-brand/60 text-2xl font-bold text-white">
          {user.display_name.slice(0, 1)}
        </div>
        <div className="min-w-0">
          <h2 className="text-2xl font-bold tracking-tight">{user.display_name}</h2>
          <div className="mt-0.5 inline-flex items-center gap-1.5 rounded-full bg-surface-2 px-2.5 py-1 text-sm font-semibold">
            <span>{level.emoji}</span>
            {level.name}
          </div>
        </div>
      </div>

      {/* Trust progress */}
      <div className="mt-4 rounded-2xl border border-border/60 bg-surface p-4">
        <div className="flex items-center justify-between">
          <span className="inline-flex items-center gap-1.5 text-sm font-semibold text-fg-muted">
            <ShieldCheck className="h-4 w-4 text-brand" /> Рейтинг доверия
          </span>
          <span className="text-lg font-extrabold text-brand tnum">{user.trust_score}</span>
        </div>
        <div className="mt-2.5 h-2.5 overflow-hidden rounded-full bg-surface-2">
          <div
            className="h-full rounded-full bg-gradient-to-r from-brand to-avail transition-all duration-500"
            style={{ width: `${progress}%` }}
          />
        </div>
        <p className="mt-2 text-xs text-fg-subtle">
          {level.next
            ? `Ещё ${level.next - user.trust_score} до уровня «${
                driverLevel(level.next).name
              }»`
            : 'Максимальный уровень достигнут 👑'}
        </p>
      </div>

      {/* Stats */}
      <div className="mt-3 grid grid-cols-3 gap-2.5">
        <Stat icon={<TrendingUp className="h-4 w-4" />} value={user.reports_count} label="репортов" />
        <Stat icon={<Flame className="h-4 w-4" />} value={12} label="дней подряд" />
        <Stat icon={<Trophy className="h-4 w-4" />} value="#4" label="в Казани" />
      </div>

      {/* Badges */}
      <h3 className="mt-6 text-lg font-bold">Достижения</h3>
      <div className="mt-2 grid grid-cols-4 gap-2">
        <Badge icon={<Zap />} label="Первый репорт" earned />
        <Badge icon={<Flame />} label="7 дней" earned />
        <Badge icon={<Award />} label="50 подтверждений" earned />
        <Badge icon={<Trophy />} label="Топ-10" earned={false} />
      </div>

      {pendingQueue.length > 0 && (
        <div className="mt-5 rounded-2xl bg-low/10 p-3 text-sm font-medium text-low">
          {pendingQueue.length} отчёт(ов) ждут отправки — появятся, когда вернётся сеть.
        </div>
      )}

      {/* Report history */}
      <h3 className="mt-6 text-lg font-bold">Мои репорты</h3>
      <div className="mt-2 space-y-2 pb-2">
        {myReports.length === 0 && (
          <p className="py-4 text-center text-sm text-fg-subtle">
            Пока нет репортов. Обновите данные на ближайшей АЗС!
          </p>
        )}
        {myReports.slice(0, 30).map(({ kind, report, stationName }) => (
          <div
            key={report.id}
            className="flex items-center gap-3 rounded-xl bg-surface p-3"
          >
            <div
              className={cn(
                'flex h-9 w-9 shrink-0 items-center justify-center rounded-lg text-xs font-bold',
                kind === 'price' ? 'bg-brand/12 text-brand' : 'bg-avail/12 text-avail',
              )}
            >
              {kind === 'price' ? '₽' : '⛽'}
            </div>
            <div className="min-w-0 flex-1">
              <div className="truncate text-sm font-semibold">{stationName}</div>
              <div className="text-xs text-fg-subtle">{timeAgo(report.created_at)}</div>
            </div>
            <div className="text-right">
              {kind === 'price' ? (
                <span className="text-sm font-bold tnum">
                  {formatPrice((report as PriceReport).price)} ₽
                </span>
              ) : (
                <span className="text-sm font-bold">
                  {AVAIL_LABEL[(report as AvailabilityReport).status]}
                </span>
              )}
              {report.confirms > 0 && (
                <div className="text-[11px] font-semibold text-avail">
                  +{report.confirms} подтв.
                </div>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function Stat({
  icon,
  value,
  label,
}: {
  icon: React.ReactNode;
  value: React.ReactNode;
  label: string;
}) {
  return (
    <div className="flex flex-col items-center rounded-2xl border border-border/60 bg-surface p-3">
      <span className="text-fg-subtle">{icon}</span>
      <span className="mt-1 text-xl font-extrabold tnum">{value}</span>
      <span className="text-[11px] text-fg-subtle">{label}</span>
    </div>
  );
}

function Badge({
  icon,
  label,
  earned,
}: {
  icon: React.ReactNode;
  label: string;
  earned: boolean;
}) {
  return (
    <div
      className={cn(
        'flex flex-col items-center gap-1 rounded-2xl border p-2.5 text-center',
        earned ? 'border-brand/30 bg-brand/8' : 'border-border/50 bg-surface opacity-45',
      )}
    >
      <span
        className={cn(
          'flex h-9 w-9 items-center justify-center rounded-full',
          earned ? 'bg-brand/15 text-brand' : 'bg-surface-2 text-fg-subtle',
        )}
      >
        <span className="[&>svg]:h-4.5 [&>svg]:w-4.5">{icon}</span>
      </span>
      <span className="text-[10px] font-semibold leading-tight text-fg-muted">{label}</span>
    </div>
  );
}
