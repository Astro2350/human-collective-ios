import {
  corsHeaders,
  isInstallationID,
  jpegDimensions,
  jsonResponse,
  normalizedText,
  privateHash,
  requestIPAddress,
  serviceClient,
} from "../_shared/community.ts";

const maximumImageBytes = 5 * 1024 * 1024;
const maximumRequestBytes = maximumImageBytes + 64 * 1024;
const termsVersion = "2026-07-14";
const allowedCategories = new Set(["art", "craft", "photography", "design", "writing", "other"]);

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const contentLength = Number(request.headers.get("content-length") ?? "0");
  if (contentLength > maximumRequestBytes) {
    return jsonResponse({ error: "image_too_large" }, 413);
  }

  let form: FormData;
  try {
    form = await request.formData();
  } catch {
    return jsonResponse({ error: "invalid_submission" }, 400);
  }

  const creatorName = normalizedText(form.get("creator_name"));
  const significance = normalizedText(form.get("significance"));
  const category = normalizedText(form.get("category")) || "other";
  const installationID = normalizedText(form.get("installation_id"));
  const acceptedRights = normalizedText(form.get("rights_confirmed")) === "true";
  const image = form.get("image");

  if (
    creatorName.length < 2 ||
    creatorName.length > 60 ||
    significance.length < 40 ||
    significance.length > 600 ||
    !allowedCategories.has(category) ||
    !isInstallationID(installationID) ||
    !acceptedRights ||
    !(image instanceof File) ||
    image.size === 0 ||
    image.size > maximumImageBytes ||
    image.type !== "image/jpeg"
  ) {
    return jsonResponse({ error: "invalid_submission" }, 400);
  }

  const imageBytes = new Uint8Array(await image.arrayBuffer());
  const dimensions = jpegDimensions(imageBytes);
  if (
    !dimensions ||
    Math.min(dimensions.width, dimensions.height) < 700 ||
    dimensions.width * dimensions.height < 1_000_000 ||
    imageBytes[imageBytes.length - 2] !== 0xff ||
    imageBytes[imageBytes.length - 1] !== 0xd9
  ) {
    return jsonResponse({ error: "invalid_image" }, 400);
  }

  const client = serviceClient();
  const submissionID = crypto.randomUUID();
  const imagePath = `pending/${submissionID}.jpg`;
  const installationHash = await privateHash(installationID.toLowerCase());
  const ipAddress = requestIPAddress(request);
  const ipHash = ipAddress ? await privateHash(ipAddress) : null;

  const { error: reservationError } = await client.rpc("create_community_submission", {
    p_submission_id: submissionID,
    p_installation_hash: installationHash,
    p_submitter_ip_hash: ipHash,
    p_creator_name: creatorName,
    p_significance: significance,
    p_image_path: imagePath,
    p_terms_version: termsVersion,
    p_category: category,
  });

  if (reservationError) {
    if (reservationError.message.includes("community_rate_limited")) {
      return jsonResponse({ error: "rate_limited" }, 429);
    }

    if (reservationError.message.includes("community_blocked")) {
      return jsonResponse({ error: "submissions_unavailable" }, 403);
    }

    console.error("Community submission reservation failed", reservationError.code);
    return jsonResponse({ error: "submission_failed" }, 500);
  }

  const { error: uploadError } = await client.storage
    .from("community-submissions")
    .upload(imagePath, imageBytes, {
      contentType: "image/jpeg",
      upsert: false,
    });

  if (uploadError) {
    console.error("Community submission upload failed", uploadError.message);
    await client.from("community_submissions").delete().eq("id", submissionID);
    return jsonResponse({ error: "submission_failed" }, 500);
  }

  return jsonResponse({ id: submissionID, status: "pending" }, 201);
});
