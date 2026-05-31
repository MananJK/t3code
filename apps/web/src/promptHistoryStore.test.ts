import { describe, expect, it } from "vitest";

import { addPromptToHistory, navigatePromptHistory } from "./promptHistoryStore";

describe("prompt history helpers", () => {
  it("ignores blank prompts", () => {
    expect(addPromptToHistory(["one"], "   ")).toEqual(["one"]);
  });

  it("deduplicates consecutive prompts and caps the list", () => {
    expect(addPromptToHistory(["one", "two"], "two", 3)).toEqual(["one", "two"]);
    expect(addPromptToHistory(["one", "two", "three"], "four", 3)).toEqual([
      "two",
      "three",
      "four",
    ]);
  });

  it("walks older prompts from the current draft", () => {
    const first = navigatePromptHistory({
      direction: "older",
      prompts: ["one", "two"],
      currentPrompt: "draft",
      state: null,
    });

    expect(first?.nextPrompt).toBe("two");
    const second = navigatePromptHistory({
      direction: "older",
      prompts: ["one", "two"],
      currentPrompt: first!.nextPrompt,
      state: first!.nextState,
    });
    expect(second?.nextPrompt).toBe("one");
  });

  it("walks newer prompts and restores the draft after the newest prompt", () => {
    const newestFromDraft = navigatePromptHistory({
      direction: "older",
      prompts: ["one", "two"],
      currentPrompt: "",
      state: null,
    });
    const older = navigatePromptHistory({
      direction: "older",
      prompts: ["one", "two"],
      currentPrompt: newestFromDraft!.nextPrompt,
      state: newestFromDraft!.nextState,
    });
    const newest = navigatePromptHistory({
      direction: "newer",
      prompts: ["one", "two"],
      currentPrompt: older!.nextPrompt,
      state: older!.nextState,
    });
    const draft = navigatePromptHistory({
      direction: "newer",
      prompts: ["one", "two"],
      currentPrompt: newest!.nextPrompt,
      state: newest!.nextState,
    });

    expect(newest?.nextPrompt).toBe("two");
    expect(draft?.nextPrompt).toBe("");
  });
});
