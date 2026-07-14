import {
  corsHeaders,
  isInstallationID,
  isUUID,
  jsonResponse,
  privateHash,
  serviceClient,
} from "../_shared/community.ts";

const allowedReasons = new Set(["inappropriate", "stolen", "harassment", "spam", "other"]);

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await request.json();
  } catch {
    return jsonResponse({ error: "invalid_report" }, 400);
  }

  const artworkID = typeof payload.artwork_id === "string" ? payload.artwork_id : "";
  const installationID = typeof payload.installation_id === "string" ? payload.installation_id : "";
  const reason = typeof payload.reason === "string" ? payload.reason : "";
  const details = typeof payload.details === "string" ? payload.details.trim() : "";

  if (
    !isUUID(artworkID) ||
    !isInstallationID(installationID) ||
    !allowedReasons.has(reason) ||
    details.length > 500
  ) {
    return jsonResponse({ error: "invalid_report" }, 400);
  }

  const reporterHash = await privateHash(installationID.toLowerCase());
  const client = serviceClient();
  const { error } = await client.rpc("create_community_report", {
    p_artwork_id: artworkID,
    p_reporter_hash: reporterHash,
    p_reason: reason,
    p_details: details,
  });

  if (error) {
    if (error.message.includes("community_rate_limited")) {
      return jsonResponse({ error: "rate_limited" }, 429);
    }

    if (error.message.includes("community_artwork_unavailable")) {
      return jsonResponse({ error: "artwork_unavailable" }, 404);
    }

    console.error("Community report failed", error.code);
    return jsonResponse({ error: "report_failed" }, 500);
  }

  return jsonResponse({ status: "received" }, 202);
});
