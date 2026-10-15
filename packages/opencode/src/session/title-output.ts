import { LLMEvent } from "@opencode-ai/llm"

export function titleOutput() {
  const blocks = new Map<string, { text: string; phase?: string }>()
  let legacy = ""

  return {
    accept(event: LLMEvent) {
      if (!LLMEvent.is.textStart(event) && !LLMEvent.is.textDelta(event) && !LLMEvent.is.textEnd(event)) return

      const block = blocks.get(event.id) ?? {
        text: "",
        phase: undefined as string | undefined,
      }

      const phase = event.providerMetadata?.openai?.phase
      if (typeof phase === "string") block.phase = phase
      if (LLMEvent.is.textDelta(event)) {
        block.text += event.text
        legacy += event.text
      }

      blocks.set(event.id, block)
    },

    value() {
      const parts = [...blocks.values()]
      const final = parts.filter((part) => part.phase === "final_answer")
      if (final.length) return final.map((part) => part.text).join("")
      if (parts.some((part) => part.phase !== undefined)) return ""
      return legacy
    },
  }
}
