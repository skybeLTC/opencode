type ProviderIdentity = {
  readonly id?: string
  readonly providerID?: string
  readonly baseProviderID?: string
}

type ConfigProvider = {
  readonly npm?: string
}

type CatalogProvider = {
  readonly npm?: string
}

export function baseProviderID(input: ProviderIdentity): string | undefined {
  return input.baseProviderID ?? input.providerID ?? input.id
}

export function isProvider(input: ProviderIdentity, providerID: string): boolean {
  return baseProviderID(input) === providerID
}

function canonicalProviderIDFromNpm(npm: string): string | undefined {
  const prefix = "@ai-sdk/"
  if (!npm.startsWith(prefix)) return undefined

  const providerID = npm.slice(prefix.length).split("/", 1)[0]
  return providerID || undefined
}

export function inferBaseProviderID(input: {
  providerID: string
  provider: ConfigProvider
  catalog: Record<string, CatalogProvider>
}): string | undefined {
  if (Object.hasOwn(input.catalog, input.providerID)) return undefined
  if (!input.provider.npm) return undefined

  // Prefer the canonical @ai-sdk/<provider> catalog entry when it exists.
  // Several catalog providers may intentionally reuse the same SDK package,
  // so requiring npm uniqueness alone is too strict for aliases. Matching the
  // package-derived provider ID first keeps inheritance deterministic without
  // hard-coding alias names.
  const canonical = canonicalProviderIDFromNpm(input.provider.npm)
  if (canonical && input.catalog[canonical]?.npm === input.provider.npm) return canonical

  // Non-@ai-sdk packages can still inherit when their npm package uniquely
  // identifies one built-in catalog provider.
  const matches = Object.entries(input.catalog)
    .filter(([, provider]) => provider.npm === input.provider.npm)
    .map(([providerID]) => providerID)

  if (matches.length !== 1) return undefined
  return matches[0]
}
