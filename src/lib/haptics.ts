/** Light haptic feedback on supporting devices (no-op elsewhere). */
export function haptic(pattern: number | number[] = 8) {
  if (typeof navigator !== 'undefined' && 'vibrate' in navigator) {
    try {
      navigator.vibrate(pattern);
    } catch {
      /* ignore */
    }
  }
}

export const hapticSuccess = () => haptic([10, 40, 20]);
export const hapticTap = () => haptic(8);
