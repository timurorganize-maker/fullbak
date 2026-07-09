'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { cn } from '@/lib/utils';
import { hapticTap } from '@/lib/haptics';

interface BottomSheetProps {
  open: boolean;
  onClose: () => void;
  children: React.ReactNode;
  /** Snap heights as viewport fractions, smallest first. */
  snapPoints?: number[];
  initialSnap?: number;
  /** Dim the map behind the sheet. */
  backdrop?: boolean;
  className?: string;
}

/**
 * iOS/Yandex-style bottom sheet with a drag handle, snap points, and
 * rubber-band + fling-to-dismiss. Content scrolls when at the top snap.
 */
export function BottomSheet({
  open,
  onClose,
  children,
  snapPoints = [0.42, 0.9],
  initialSnap = 0,
  backdrop = false,
  className,
}: BottomSheetProps) {
  const [mounted, setMounted] = useState(open);
  const [snap, setSnap] = useState(initialSnap);
  const sheetRef = useRef<HTMLDivElement>(null);
  const scrollRef = useRef<HTMLDivElement>(null);
  const drag = useRef<{
    startY: number;
    startTranslate: number;
    dragging: boolean;
    lastY: number;
    lastT: number;
    velocity: number;
  } | null>(null);
  const [translate, setTranslate] = useState(0); // px offset from resting snap position

  useEffect(() => {
    if (open) {
      setMounted(true);
      setSnap(initialSnap);
      setTranslate(0);
    }
  }, [open, initialSnap]);

  const heightFor = useCallback(
    (s: number) => `${(snapPoints[s] ?? 0.5) * 100}%`,
    [snapPoints],
  );

  const onPointerDown = (e: React.PointerEvent) => {
    // Only start a drag from the handle area, or when content is scrolled to top.
    const scroller = scrollRef.current;
    const fromHandle = (e.target as HTMLElement).closest('[data-sheet-handle]');
    if (!fromHandle && scroller && scroller.scrollTop > 0) return;
    drag.current = {
      startY: e.clientY,
      startTranslate: 0,
      dragging: true,
      lastY: e.clientY,
      lastT: performance.now(),
      velocity: 0,
    };
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
  };

  const onPointerMove = (e: React.PointerEvent) => {
    const d = drag.current;
    if (!d?.dragging) return;
    let dy = e.clientY - d.startY;
    // Rubber-band when dragging up past the top snap.
    if (snap === snapPoints.length - 1 && dy < 0) dy = dy / 3;
    const now = performance.now();
    const dt = now - d.lastT;
    if (dt > 0) d.velocity = (e.clientY - d.lastY) / dt;
    d.lastY = e.clientY;
    d.lastT = now;
    setTranslate(dy);
  };

  const settle = (e: React.PointerEvent) => {
    const d = drag.current;
    if (!d?.dragging) return;
    d.dragging = false;
    const dy = translate;
    const v = d.velocity; // px/ms, positive = downward fling

    // Fling down hard → close or step down.
    if (v > 0.6 || dy > 140) {
      if (snap === 0) {
        onClose();
      } else {
        setSnap((s) => Math.max(0, s - 1));
        hapticTap();
      }
    } else if (v < -0.6 || dy < -100) {
      setSnap((s) => Math.min(snapPoints.length - 1, s + 1));
      hapticTap();
    }
    setTranslate(0);
    try {
      (e.currentTarget as HTMLElement).releasePointerCapture(e.pointerId);
    } catch {
      /* ignore */
    }
  };

  const handleTransitionEnd = () => {
    if (!open) setMounted(false);
  };

  if (!mounted) return null;

  return (
    <>
      {backdrop && (
        <div
          className={cn(
            'fixed inset-0 z-30 bg-black/40 transition-opacity duration-300',
            open ? 'opacity-100' : 'opacity-0',
          )}
          onClick={onClose}
        />
      )}
      <div
        ref={sheetRef}
        onTransitionEnd={handleTransitionEnd}
        className={cn(
          'fixed inset-x-0 bottom-0 z-40 mx-auto flex max-w-lg flex-col rounded-t-3xl bg-bg-elevated shadow-sheet',
          'border-t border-border/60',
          drag.current?.dragging ? '' : 'transition-[height,transform] duration-300 ease-[cubic-bezier(0.32,0.72,0,1)]',
          className,
        )}
        style={{
          height: heightFor(snap),
          transform: open
            ? `translateY(${translate}px)`
            : 'translateY(100%)',
          touchAction: 'none',
        }}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={settle}
        onPointerCancel={settle}
      >
        <div
          data-sheet-handle
          className="flex cursor-grab touch-none justify-center pt-2.5 pb-1 active:cursor-grabbing"
        >
          <div className="h-1.5 w-10 rounded-full bg-fg-subtle/40" />
        </div>
        <div
          ref={scrollRef}
          className="no-scrollbar flex-1 overflow-y-auto overscroll-contain px-4 pb-[calc(env(safe-area-inset-bottom)+16px)]"
        >
          {children}
        </div>
      </div>
    </>
  );
}
