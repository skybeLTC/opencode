import { describe, expect, test } from "bun:test"
import * as ProviderInheritance from "../../src/provider/inheritance"

describe("provider inheritance", () => {
  test("baseProviderID prefers inherited identity and falls back to runtime identity", () => {
    expect(ProviderInheritance.baseProviderID({ id: "alias", baseProviderID: "openai" })).toBe("openai")
    expect(ProviderInheritance.baseProviderID({ providerID: "anthropic" })).toBe("anthropic")
    expect(ProviderInheritance.baseProviderID({ id: "xai" })).toBe("xai")
  })

  test("canonical @ai-sdk package inherits its matching catalog provider", () => {
    expect(
      ProviderInheritance.inferBaseProviderID({
        providerID: "openai-alias",
        provider: { npm: "@ai-sdk/openai" },
        catalog: {
          openai: { npm: "@ai-sdk/openai" },
          other: { npm: "@ai-sdk/openai" },
        },
      }),
    ).toBe("openai")
  })

  test("non-canonical package inherits only when npm mapping is unique", () => {
    expect(
      ProviderInheritance.inferBaseProviderID({
        providerID: "unique-alias",
        provider: { npm: "vendor-provider" },
        catalog: {
          first: { npm: "vendor-provider" },
          second: { npm: "other-provider" },
        },
      }),
    ).toBe("first")

    expect(
      ProviderInheritance.inferBaseProviderID({
        providerID: "ambiguous-alias",
        provider: { npm: "vendor-provider" },
        catalog: {
          first: { npm: "vendor-provider" },
          second: { npm: "vendor-provider" },
        },
      }),
    ).toBeUndefined()
  })

  test("built-in provider IDs do not create an inheritance relationship", () => {
    expect(
      ProviderInheritance.inferBaseProviderID({
        providerID: "openai",
        provider: { npm: "@ai-sdk/openai" },
        catalog: { openai: { npm: "@ai-sdk/openai" } },
      }),
    ).toBeUndefined()
  })
})
