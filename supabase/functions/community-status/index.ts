import {
  corsHeaders,
  isInstallationID,
  isUUID,
  jsonResponse,
  privateHash,
  serviceClient,
} from "../_shared/community.ts";

type StatusRequest = {
  installation_id?: unknown;
  ids?: unknown;
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  let payload: StatusRequest;
  try {
    payload = await request.json();
  } catch {
    return jsonResponse({ error: "invalid_request" }, 400);
  }

  const installationID = typeof payload.installation_id === "string"
    ? payload.installation_id.trim().toLowerCase()
    : "";
  const ids = Array.isArray(payload.ids)
    ? Array.from(
      new Set(payload.ids.filter((value): value is string =>
        typeof value === "string" && isUUID(value)
      )),
    ).slice(0, 20)
    : [];

  if (!isInstallationID(installationID) || ids.length === 0) {
    return jsonResponse({ error: "invalid_request" }, 400);
  }

  const installationHash = await privateHash(installationID);
  const client = serviceClient();
  const { data: contributor, error: contributorError } = await client
    .from("community_contributors")
    .select("id")
    .eq("installation_hash", installationHash)
    .maybeSingle();

  if (contributorError) {
    console.error(
      "Community status contributor lookup failed",
      contributorError.code,
    );
    return jsonResponse({ error: "status_lookup_failed" }, 500);
  }

  if (!contributor) {
    return jsonResponse({ submissions: [] });
  }

  const { data: submissions, error: submissionsError } = await client
    .from("community_submissions")
    .select("id,status,reviewed_at")
    .eq("contributor_id", contributor.id)
    .in("id", ids)
    .order("created_at", { ascending: false });

  if (submissionsError) {
    console.error("Community status lookup failed", submissionsError.code);
    return jsonResponse({ error: "status_lookup_failed" }, 500);
  }

  return jsonResponse({ submissions: submissions ?? [] });
});
