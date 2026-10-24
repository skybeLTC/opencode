import { test, expect, describe } from "bun:test"
import { credentialStorageProviderID, resolveLoginAuthHook, resolvePluginProviders } from "../../src/cli/cmd/providers"
import type { Hooks } from "@opencode-ai/plugin"

function hookWithAuth(provider: string): Hooks {
  return {
    auth: {
      provider,
      methods: [],
    },
  }
}

function hookWithoutAuth(): Hooks {
  return {}
}

describe("resolvePluginProviders", () => {
  test("returns plugin providers not in models.dev", () => {
    const result = resolvePluginProviders({
      hooks: [hookWithAuth("portkey")],
      existingProviders: {},
      disabled: new Set(),
      providerNames: {},
    })
    expect(result).toEqual([{ id: "portkey", name: "portkey" }])
  })

  test("skips providers already in models.dev", () => {
    const result = resolvePluginProviders({
      hooks: [hookWithAuth("anthropic")],
      existingProviders: { anthropic: {} },
      disabled: new Set(),
      providerNames: {},
    })
    expect(result).toEqual([])
  })

  test("deduplicates across plugins", () => {
    const result = resolvePluginProviders({
      hooks: [hookWithAuth("portkey"), hookWithAuth("portkey")],
      existingProviders: {},
      disabled: new Set(),
      providerNames: {},
    })
    expect(result).toEqual([{ id: "portkey", name: "portkey" }])
  })

  test("respects disabled_providers", () => {
    const result = resolvePluginProviders({
      hooks: [hookWithAuth("portkey")],
      existingProviders: {},
      disabled: new Set(["portkey"]),
      providerNames: {},
    })
    expect(result).toEqual([])
  })

  test("respects enabled_providers when provider is absent", () => {
    const result = resolvePluginProviders({
      hooks: [hookWithAuth("portkey")],
      existingProviders: {},
      disabled: new Set(),
      enabled: new Set(["anthropic"]),
      providerNames: {},
    })
    expect(result).toEqual([])
  })

  test("includes provider when in enabled set", () => {
    const result = resolvePluginProviders({
      hooks: [hookWithAuth("portkey")],
      existingProviders: {},
      disabled: new Set(),
      enabled: new Set(["portkey"]),
      providerNames: {},
    })
    expect(result).toEqual([{ id: "portkey", name: "portkey" }])
  })

  test("resolves name from providerNames", () => {
    const result = resolvePluginProviders({
      hooks: [hookWithAuth("portkey")],
      existingProviders: {},
      disabled: new Set(),
      providerNames: { portkey: "Portkey AI" },
    })
    expect(result).toEqual([{ id: "portkey", name: "Portkey AI" }])
  })

  test("falls back to id when no name configured", () => {
    const result = resolvePluginProviders({
      hooks: [hookWithAuth("portkey")],
      existingProviders: {},
      disabled: new Set(),
      providerNames: {},
    })
    expect(result).toEqual([{ id: "portkey", name: "portkey" }])
  })

  test("skips hooks without auth", () => {
    const result = resolvePluginProviders({
      hooks: [hookWithoutAuth(), hookWithAuth("portkey"), hookWithoutAuth()],
      existingProviders: {},
      disabled: new Set(),
      providerNames: {},
    })
    expect(result).toEqual([{ id: "portkey", name: "portkey" }])
  })

  test("includes configured aliases for inherited plugin auth", () => {
    const result = resolvePluginProviders({
      hooks: [hookWithAuth("openai")],
      existingProviders: { openai: {} },
      configuredProviders: { "openai-alias": { npm: "@ai-sdk/openai", name: "OpenAI Alias" } },
      catalogProviders: { openai: { npm: "@ai-sdk/openai" } },
      disabled: new Set(),
      providerNames: { "openai-alias": "OpenAI Alias" },
    })
    expect(result).toEqual([{ id: "openai-alias", name: "OpenAI Alias" }])
  })

  test("returns empty for no hooks", () => {
    const result = resolvePluginProviders({
      hooks: [],
      existingProviders: {},
      disabled: new Set(),
      providerNames: {},
    })
    expect(result).toEqual([])
  })
})


describe("inherited plugin authentication identity", () => {
  test("alias stays in its own auth namespace even when hook redirects", () => {
    expect(credentialStorageProviderID("custom-alias", "digitalocean", "digitalocean")).toBe("custom-alias")
    expect(credentialStorageProviderID("custom-alias", "openai", undefined)).toBe("custom-alias")
  })

  test("built-in plugin credential redirect behavior stays unchanged", () => {
    expect(credentialStorageProviderID("digitalocean", "digitalocean", "target-provider")).toBe("target-provider")
    expect(credentialStorageProviderID("digitalocean", "digitalocean", undefined)).toBe("digitalocean")
  })

  test("exact auth hook wins and hook-less plugins cannot shadow inherited auth", () => {
    const exact = hookWithAuth("custom-alias")
    const base = hookWithAuth("openai")
    const hooks = [exact, base, hookWithoutAuth()]
    expect(resolveLoginAuthHook(hooks, "custom-alias", "openai")).toBe(exact)
    expect(resolveLoginAuthHook([base, hookWithoutAuth()], "custom-alias", "openai")).toBe(base)
    expect(resolveLoginAuthHook([base, hookWithoutAuth()], "unrelated")).toBeUndefined()
  })
})
