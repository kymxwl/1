/** Minimal design tokens. TGI palette: felt green + brass. */
export const theme = {
  color: {
    felt: '#0B3D2E',
    feltLight: '#14563F',
    brass: '#C7A044',
    bg: '#F5F6F4',
    card: '#FFFFFF',
    text: '#14211B',
    subtle: '#5C6B63',
    border: '#E1E5E1',
    danger: '#B23B3B',
    bronze: '#B08D57',
    silver: '#9AA3A8',
    gold: '#C7A044',
  },
  space: (n: number) => n * 8,
  radius: 12,
} as const;

export function tierColor(tier: 'bronze' | 'silver' | 'gold' | null): string {
  if (tier === 'gold') return theme.color.gold;
  if (tier === 'silver') return theme.color.silver;
  if (tier === 'bronze') return theme.color.bronze;
  return theme.color.border;
}
