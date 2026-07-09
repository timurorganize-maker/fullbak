'use client';

import { useMemo, useState } from 'react';
import { ImagePlus, Star, ThumbsUp } from 'lucide-react';
import { useStore } from '@/lib/store';
import { cn, timeAgo } from '@/lib/utils';
import { Button } from '@/components/ui/button';
import { hapticSuccess } from '@/lib/haptics';

export function ReviewsSection({ stationId }: { stationId: string }) {
  const { reviewsFor, addReview } = useStore();
  const reviews = reviewsFor(stationId);
  const [sort, setSort] = useState<'new' | 'helpful'>('new');
  const [composing, setComposing] = useState(false);

  const sorted = useMemo(() => {
    const list = reviews.slice();
    if (sort === 'helpful') list.sort((a, b) => b.helpful - a.helpful);
    return list;
  }, [reviews, sort]);

  const avg =
    reviews.length > 0
      ? reviews.reduce((s, r) => s + r.rating, 0) / reviews.length
      : 0;

  return (
    <div className="mt-6 border-t border-border/60 pt-4">
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-bold">Отзывы</h3>
        {reviews.length > 0 && (
          <div className="flex items-center gap-1.5 text-sm">
            <Star className="h-4 w-4 fill-low text-low" />
            <span className="font-bold tnum">{avg.toFixed(1)}</span>
            <span className="text-fg-subtle">· {reviews.length}</span>
          </div>
        )}
      </div>

      <div className="mt-3 flex items-center gap-2">
        <SortChip active={sort === 'new'} onClick={() => setSort('new')}>
          Новые
        </SortChip>
        <SortChip active={sort === 'helpful'} onClick={() => setSort('helpful')}>
          Полезные
        </SortChip>
        <div className="flex-1" />
        <Button size="sm" variant="secondary" onClick={() => setComposing((v) => !v)}>
          Оставить отзыв
        </Button>
      </div>

      {composing && (
        <ReviewComposer
          onSubmit={(rating, text) => {
            addReview({ station_id: stationId, rating, text, photo_urls: [] });
            setComposing(false);
            hapticSuccess();
          }}
        />
      )}

      <div className="mt-3 space-y-3">
        {sorted.length === 0 && !composing && (
          <p className="py-4 text-center text-sm text-fg-subtle">
            Пока нет отзывов. Будьте первым!
          </p>
        )}
        {sorted.map((r) => (
          <div key={r.id} className="rounded-2xl bg-surface p-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <div className="flex h-8 w-8 items-center justify-center rounded-full bg-brand/15 text-sm font-bold text-brand">
                  {r.user_name.slice(0, 1)}
                </div>
                <div>
                  <div className="text-sm font-semibold leading-tight">{r.user_name}</div>
                  <div className="text-[11px] text-fg-subtle">{timeAgo(r.created_at)}</div>
                </div>
              </div>
              <div className="flex gap-0.5">
                {[1, 2, 3, 4, 5].map((i) => (
                  <Star
                    key={i}
                    className={cn(
                      'h-3.5 w-3.5',
                      i <= r.rating ? 'fill-low text-low' : 'text-fg-subtle/30',
                    )}
                  />
                ))}
              </div>
            </div>
            {r.text && <p className="mt-2 text-sm leading-snug text-fg">{r.text}</p>}
            <button className="mt-2 inline-flex items-center gap-1.5 text-xs font-semibold text-fg-subtle active:text-brand">
              <ThumbsUp className="h-3.5 w-3.5" /> Полезно · {r.helpful}
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}

function SortChip({
  active,
  onClick,
  children,
}: {
  active: boolean;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      onClick={onClick}
      className={cn(
        'rounded-full px-3 py-1.5 text-xs font-semibold transition-colors',
        active ? 'bg-fg text-bg' : 'bg-surface-2 text-fg-muted',
      )}
    >
      {children}
    </button>
  );
}

function ReviewComposer({
  onSubmit,
}: {
  onSubmit: (rating: number, text: string) => void;
}) {
  const [rating, setRating] = useState(5);
  const [text, setText] = useState('');
  return (
    <div className="mt-3 rounded-2xl border border-border/60 bg-surface p-3">
      <div className="flex items-center justify-center gap-1.5">
        {[1, 2, 3, 4, 5].map((i) => (
          <button key={i} onClick={() => setRating(i)} className="p-1">
            <Star
              className={cn(
                'h-7 w-7 transition-transform active:scale-90',
                i <= rating ? 'fill-low text-low' : 'text-fg-subtle/30',
              )}
            />
          </button>
        ))}
      </div>
      <textarea
        value={text}
        onChange={(e) => setText(e.target.value)}
        placeholder="Как заправка? Была ли очередь, есть ли нужное топливо…"
        rows={3}
        className="mt-2 w-full resize-none rounded-xl bg-surface-2 p-3 text-sm outline-none placeholder:text-fg-subtle focus:ring-2 focus:ring-brand/40"
      />
      <div className="mt-2 flex items-center gap-2">
        <button className="inline-flex items-center gap-1.5 rounded-xl bg-surface-2 px-3 py-2 text-xs font-semibold text-fg-muted">
          <ImagePlus className="h-4 w-4" /> Фото
        </button>
        <div className="flex-1" />
        <Button size="sm" onClick={() => onSubmit(rating, text.trim())}>
          Опубликовать
        </Button>
      </div>
    </div>
  );
}
