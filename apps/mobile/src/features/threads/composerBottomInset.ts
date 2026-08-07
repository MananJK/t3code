export const COMPOSER_MIN_BOTTOM_INSET = 12;

/**
 * Bottom padding applied beneath the thread composer. Android can dismiss the
 * keyboard while the editor keeps focus (back button/gesture), leaving the
 * composer expanded above a closed keyboard — only drop the safe-area inset
 * while the keyboard is actually open, otherwise the composer toolbar renders
 * underneath the system navigation bar and its controls are untappable.
 */
export function resolveComposerBottomInset(input: {
  readonly expanded: boolean;
  readonly keyboardVisible: boolean;
  readonly safeAreaBottom: number;
}): number {
  if (input.expanded && input.keyboardVisible) {
    return 0;
  }
  return Math.max(input.safeAreaBottom, COMPOSER_MIN_BOTTOM_INSET);
}
