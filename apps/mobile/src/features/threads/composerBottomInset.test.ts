import { describe, expect, it } from "@effect/vitest";

import { COMPOSER_MIN_BOTTOM_INSET, resolveComposerBottomInset } from "./composerBottomInset";

describe("resolveComposerBottomInset", () => {
  it("drops the inset only while the expanded composer rides an open keyboard", () => {
    expect(
      resolveComposerBottomInset({ expanded: true, keyboardVisible: true, safeAreaBottom: 34 }),
    ).toBe(0);
  });

  it("keeps the safe-area inset when expanded above a closed keyboard", () => {
    // Android back-button dismissal leaves the editor focused: expanded stays
    // true but the navigation bar is back and must not cover the toolbar.
    expect(
      resolveComposerBottomInset({ expanded: true, keyboardVisible: false, safeAreaBottom: 34 }),
    ).toBe(34);
  });

  it("keeps the safe-area inset when collapsed with the keyboard open", () => {
    expect(
      resolveComposerBottomInset({ expanded: false, keyboardVisible: true, safeAreaBottom: 34 }),
    ).toBe(34);
  });

  it("keeps the safe-area inset when collapsed with the keyboard closed", () => {
    expect(
      resolveComposerBottomInset({ expanded: false, keyboardVisible: false, safeAreaBottom: 34 }),
    ).toBe(34);
  });

  it("falls back to the minimum inset when the safe area is smaller", () => {
    expect(
      resolveComposerBottomInset({ expanded: false, keyboardVisible: false, safeAreaBottom: 0 }),
    ).toBe(COMPOSER_MIN_BOTTOM_INSET);
    expect(
      resolveComposerBottomInset({ expanded: true, keyboardVisible: false, safeAreaBottom: 4 }),
    ).toBe(COMPOSER_MIN_BOTTOM_INSET);
  });
});
