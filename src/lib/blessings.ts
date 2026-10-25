export type Blessing = {
  id: string;
  name: string;
  message: string;
  created_at: string | null;
};

export type NewBlessing = {
  name: string;
  message: string;
};

export class BlessingsUnavailableError extends Error {
  status?: number;
  code?: string;

  constructor(
    message = "Blessings are temporarily unavailable.",
    details: { status?: number; code?: string } = {},
  ) {
    super(message);
    this.name = "BlessingsUnavailableError";
    this.status = details.status;
    this.code = details.code;
  }
}

function getSupabaseConfig() {
  // Use direct env references so Vite can statically inject them into the
  // client bundle (dynamic/bracket access may remain undefined in production).
  const url = import.meta.env.VITE_SUPABASE_URL?.trim().replace(/\/$/, "");
  const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY?.trim();
  if (!url || !anonKey) return null;
  return { url, anonKey };
}

export function isBlessingsConfigured() {
  return getSupabaseConfig() !== null;
}

async function supabaseRequest(path: string, init?: RequestInit) {
  const config = getSupabaseConfig();
  if (!config) {
    throw new BlessingsUnavailableError("Blessings database is not configured.");
  }

  const headers = new Headers(init?.headers);
  headers.set("apikey", config.anonKey);
  // Legacy anon keys are JWTs and can also be used as the bearer token.
  // New sb_publishable_* keys are not JWTs: sending one as Authorization
  // makes Supabase reject an otherwise valid API-key request as an invalid JWT.
  if (config.anonKey.startsWith("eyJ")) {
    headers.set("Authorization", `Bearer ${config.anonKey}`);
  } else {
    headers.delete("Authorization");
  }
  if (init?.body) headers.set("Content-Type", "application/json");

  let response: Response;
  try {
    response = await fetch(`${config.url}/rest/v1/${path}`, { ...init, headers });
  } catch (error) {
    throw new BlessingsUnavailableError(
      error instanceof Error ? error.message : "Network request failed.",
    );
  }

  if (!response.ok) {
    if (response.status === 429) {
      throw new BlessingsUnavailableError("Too many submissions. Please try again later.");
    }
    const body = (await response.json().catch(() => ({}))) as { message?: string; code?: string };
    throw new BlessingsUnavailableError(
      body.message ?? "The blessings service could not complete the request.",
      {
        status: response.status,
        code: body.code,
      },
    );
  }

  return response;
}

export async function getApprovedBlessings(): Promise<Blessing[]> {
  const query =
    "blessings?select=id,name,message,created_at&is_approved=eq.true&order=created_at.desc,id.desc";
  const rows: Blessing[] = [];
  const pageSize = 500;
  for (let offset = 0; ; offset += pageSize) {
    const response = await supabaseRequest(`${query}&limit=${pageSize}&offset=${offset}`, {
      cache: "no-store",
    });
    const page = (await response.json()) as Blessing[];
    rows.push(...page);
    if (page.length < pageSize) {
      const uniqueById = new Map(rows.map((row) => [row.id, row]));
      return [...uniqueById.values()];
    }
  }
}

export async function submitBlessing(blessing: NewBlessing): Promise<Blessing> {
  const response = await supabaseRequest("blessings?select=id,name,message,created_at", {
    method: "POST",
    headers: { Prefer: "return=representation" },
    body: JSON.stringify(blessing),
  });
  const [savedBlessing] = (await response.json()) as Blessing[];
  if (!savedBlessing) {
    throw new BlessingsUnavailableError("Supabase did not return the saved blessing.");
  }
  return savedBlessing;
}
