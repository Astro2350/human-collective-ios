import {
  corsHeaders,
  isInstallationID,
  isUUID,
  jsonResponse,
  privateHash,
  serviceClient,
} from "../_shared/community.ts";

type CancellationRequest = {
  installation_id?: unknown;
  submission_id?: unknown;
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  let payload: CancellationRequest;
  try {
    payload = await request.json();
  } catch {
    return jsonResponse({ error: "invalid_request" }, 400);
  }

  const installationID = typeof payload.installation_id === "string"
    ? payload.installation_id.trim().toLowerCase()
    : "";
  const submissionID = typeof payload.submission_id === "string"
    ? payload.submission_id.trim().toLowerCase()
    : "";

  if (!isInstallationID(installationID) || !isUUID(submissionID)) {
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
      "Community cancellation contributor lookup failed",
      contributorError.code,
    );
    return jsonResponse({ error: "cancellation_failed" }, 500);
  }

  if (!contributor) {
    return jsonResponse({ error: "submission_not_cancellable" }, 409);
  }

  const { data: cancelled, error: cancellationError } = await client
    .from("community_submissions")
    .delete()
    .eq("id", submissionID)
    .eq("contributor_id", contributor.id)
    .eq("status", "pending")
    .select("image_path")
    .maybeSingle();

  if (cancellationError) {
    console.error("Community cancellation failed", cancellationError.code);
    return jsonResponse({ error: "cancellation_failed" }, 500);
  }

  if (!cancelled) {
    return jsonResponse({ error: "submission_not_cancellable" }, 409);
  }

  const { error: storageError } = await client.storage
    .from("community-submissions")
    .remove([cancelled.image_path]);

  if (storageError) {
    console.error(
      "Cancelled submission image cleanup failed",
      storageError.message,
    );
  }

  return jsonResponse({ cancelled: true });
});
