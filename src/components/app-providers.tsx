'use client';

import { useEffect } from 'react';
import { StoreProvider } from '@/lib/store';

export function AppProviders({ children }: { children: React.ReactNode }) {
  useEffect(() => {
    if ('serviceWorker' in navigator && process.env.NODE_ENV === 'production') {
      navigator.serviceWorker.register('/sw.js').catch(() => {});
    }
  }, []);

  return <StoreProvider>{children}</StoreProvider>;
}
