import { type ScopedThreadRef } from "@t3tools/contracts";
import { scopedThreadKey } from "@t3tools/client-runtime";
import { create } from "zustand";
import { createJSONStorage, persist } from "zustand/middleware";

import { type DraftId } from "./composerDraftStore";

export const PROMPT_HISTORY_STORAGE_KEY = "t3code:prompt-history:v1";
export const PROMPT_HISTORY_LIMIT = 100;

export function getPromptHistoryKey(target: ScopedThreadRef | DraftId): string {
  return typeof target === "string" ? `draft:${target}` : `server:${scopedThreadKey(target)}`;
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

function normalizePrompt(prompt: string): string {
  return prompt.trim();
}

export function addPromptToHistory(
  prompts: readonly string[],
  prompt: string,
  limit = PROMPT_HISTORY_LIMIT,
): string[] {
  const normalizedPrompt = normalizePrompt(prompt);
  if (normalizedPrompt.length === 0) {
    return [...prompts];
  }

  const withoutConsecutiveDuplicate =
    prompts.at(-1) === normalizedPrompt ? prompts.slice(0, -1) : prompts;
  return [...withoutConsecutiveDuplicate, normalizedPrompt].slice(-limit);
}

export function navigatePromptHistory(input: {
  readonly direction: "newer" | "older";
  readonly prompts: readonly string[];
  readonly currentPrompt: string;
  readonly state: PromptHistoryNavigationState | null;
}): {
  readonly nextPrompt: string;
  readonly nextState: PromptHistoryNavigationState;
} | null {
  if (input.prompts.length === 0) {
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
    nextState: {
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
