import { expect, test } from "bun:test"
import { LLMEvent } from "@opencode-ai/llm"
import { titleOutput } from "../../src/session/title-output"

function block(id: string, text: string, phase?: string) {
  return [
    LLMEvent.textStart({
      id,
      providerMetadata: phase ? { openai: { phase } } : undefined,
    }),
    LLMEvent.textDelta({ id, text }),
    LLMEvent.textEnd({ id }),
  ]
}

function collect(...events: LLMEvent[]) {
  const output = titleOutput()
  for (const event of events) output.accept(event)
  return output.value()
}

test("single final answer", () => {
  expect(collect(...block("a", "正常標題", "final_answer"))).toBe("正常標題")
})

test("commentary is excluded", () => {
  expect(collect(...block("a", "We need a title.", "commentary"), ...block("b", "正確標題", "final_answer"))).toBe(
    "正確標題",
  )
})

test("multiple final answer blocks preserve order", () => {
  expect(collect(...block("a", "前半", "final_answer"), ...block("b", "後半", "final_answer"))).toBe("前半後半")
})

test("unphased provider preserves legacy aggregation", () => {
  expect(collect(...block("a", "第一段"), ...block("b", "第二段"))).toBe("第一段第二段")
})

test("commentary without final answer is rejected", () => {
  expect(collect(...block("a", "Intermediate text", "commentary"))).toBe("")
})

test("mixed commentary and unphased text without final is rejected", () => {
  expect(collect(...block("a", "Intermediate text", "commentary"), ...block("b", "Unknown text"))).toBe("")
})

test("phase on text-end is recognized", () => {
  expect(
    collect(
      LLMEvent.textStart({ id: "a" }),
      LLMEvent.textDelta({ id: "a", text: "正確標題" }),
      LLMEvent.textEnd({
        id: "a",
        providerMetadata: { openai: { phase: "final_answer" } },
      }),
    ),
  ).toBe("正確標題")
})

test("text delta without text-start is preserved", () => {
  expect(
    collect(
      LLMEvent.textDelta({ id: "a", text: "前半" }),
      LLMEvent.textDelta({ id: "a", text: "後半" }),
      LLMEvent.textEnd({ id: "a" }),
    ),
  ).toBe("前半後半")
})

test("phase on text-delta is recognized", () => {
  expect(
    collect(
      LLMEvent.textStart({ id: "a" }),
      LLMEvent.textDelta({
        id: "a",
        text: "Intermediate commentary",
        providerMetadata: { openai: { phase: "commentary" } },
      }),
      LLMEvent.textEnd({ id: "a" }),
      LLMEvent.textStart({ id: "b" }),
      LLMEvent.textDelta({
        id: "b",
        text: "正確標題",
        providerMetadata: { openai: { phase: "final_answer" } },
      }),
      LLMEvent.textEnd({ id: "b" }),
    ),
  ).toBe("正確標題")
})

test("text-start after an initial delta preserves text", () => {
  expect(
    collect(
      LLMEvent.textDelta({ id: "a", text: "前半" }),
      LLMEvent.textStart({ id: "a" }),
      LLMEvent.textDelta({ id: "a", text: "後半" }),
      LLMEvent.textEnd({
        id: "a",
        providerMetadata: { openai: { phase: "final_answer" } },
      }),
    ),
  ).toBe("前半後半")
})

test("interleaved unphased blocks preserve delta order", () => {
  expect(
    collect(
      LLMEvent.textStart({ id: "a" }),
      LLMEvent.textDelta({ id: "a", text: "前半" }),
      LLMEvent.textStart({ id: "b" }),
      LLMEvent.textDelta({ id: "b", text: "中間" }),
      LLMEvent.textDelta({ id: "a", text: "後半" }),
      LLMEvent.textEnd({ id: "a" }),
      LLMEvent.textEnd({ id: "b" }),
    ),
  ).toBe("前半中間後半")
})

test("empty response remains empty", () => {
  expect(collect()).toBe("")
})
