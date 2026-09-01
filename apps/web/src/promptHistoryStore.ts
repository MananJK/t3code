import { type ScopedThreadRef } from "@t3tools/contracts";
import { scopedThreadKey } from "@t3tools/client-runtime/environment";
import { create } from "zustand";
import { createJSONStorage, persist } from "zustand/middleware";

export const PROMPT_HISTORY_STORAGE_KEY = "t3code:prompt-history:v1";
export const PROMPT_HISTORY_LIMIT = 100;

export function getPromptHistoryKey(threadRef: ScopedThreadRef): string {
  return `server:${scopedThreadKey(threadRef)}`;
}

export interface PromptHistoryNavigationState {
  readonly draft: string;
  readonly index: number;
}

interface PromptHistoryStoreState {
  promptsByThreadKey: Record<string, string[]>;
  addPrompt: (threadKey: string, prompt: string) => void;
  clear: () => void;
}

function createFallbackStorage(): Storage {
  const entries = new Map<string, string>();
  return {
    get length() {
      return entries.size;
    },
    clear: () => entries.clear(),
    getItem: (key) => entries.get(key) ?? null,
    key: (index) => Array.from(entries.keys())[index] ?? null,
    removeItem: (key) => entries.delete(key),
    setItem: (key, value) => entries.set(key, value),
  };
}

export function addPromptToHistory(
  prompts: readonly string[],
  prompt: string,
  limit = PROMPT_HISTORY_LIMIT,
): string[] {
  if (prompt.trim().length === 0) {
    return [...prompts];
  }

  const withoutConsecutiveDuplicate = prompts.at(-1) === prompt ? prompts.slice(0, -1) : prompts;
  return [...withoutConsecutiveDuplicate, prompt].slice(-limit);
}

export function resolvePromptHistoryDirection(input: {
  readonly key: "ArrowDown" | "ArrowUp" | "Enter" | "Tab";
  readonly cursor: number;
  readonly isNavigating: boolean;
}): "newer" | "older" | null {
  if (input.key === "ArrowUp" && (input.isNavigating || input.cursor === 0)) {
    return "older";
  }
  if (input.key === "ArrowDown" && input.isNavigating) {
    return "newer";
  }
  return null;
}

export function navigatePromptHistory(input: {
  readonly direction: "newer" | "older";
  readonly prompts: readonly string[];
  readonly currentPrompt: string;
  readonly state: PromptHistoryNavigationState | null;
}): {
  readonly nextPrompt: string;
  readonly nextState: PromptHistoryNavigationState | null;
} | null {
  if (input.prompts.length === 0 || (input.direction === "newer" && input.state === null)) {
    return null;
  }

  const initialState =
    input.state ??
    ({
      draft: input.currentPrompt,
      index: input.prompts.length,
    } satisfies PromptHistoryNavigationState);

  const nextIndex =
    input.direction === "older"
      ? Math.max(0, initialState.index - 1)
      : Math.min(input.prompts.length, initialState.index + 1);
  const nextPrompt =
    nextIndex === input.prompts.length ? initialState.draft : (input.prompts[nextIndex] ?? "");

  return {
    nextPrompt,
    nextState:
      nextIndex === input.prompts.length
        ? null
        : {
            draft: initialState.draft,
            index: nextIndex,
          },
  };
}

export const usePromptHistoryStore = create<PromptHistoryStoreState>()(
  persist(
    (set) => ({
      promptsByThreadKey: {},
      addPrompt: (threadKey, prompt) =>
        set((state) => ({
          promptsByThreadKey: {
            ...state.promptsByThreadKey,
            [threadKey]: addPromptToHistory(state.promptsByThreadKey[threadKey] ?? [], prompt),
          },
        })),
      clear: () => set({ promptsByThreadKey: {} }),
    }),
    {
      name: PROMPT_HISTORY_STORAGE_KEY,
      version: 2,
      storage: createJSONStorage(() =>
        typeof localStorage === "undefined" ? createFallbackStorage() : localStorage,
      ),
      partialize: (state) => ({ promptsByThreadKey: state.promptsByThreadKey }),
      migrate: (persisted, version) => {
        if (version < 2) {
          const old = persisted as { prompts?: string[] } | null;
          return {
            promptsByThreadKey: old?.prompts ? { legacy: [...old.prompts] } : {},
          };
        }
        return persisted as { promptsByThreadKey: Record<string, string[]> };
      },
    },
  ),
);
