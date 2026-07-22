// Supabase Edge Function: issue-certificate
//
// Completes M8. Given an enrollment, it:
//   1. verifies the caller is an admin (via their JWT),
//   2. computes a fresh completion evaluation (evaluate_completion),
//   3. issues the certificate — which atomically allocates the next gapless
//      number and reserves the pdf_url (issue_certificate),
//   4. renders the numbered PDF and uploads it to the `certificates` bucket,
//   5. writes the resolved storage path back onto certificates.pdf_url.
//
// The number allocation and eligibility gate live in the DB function, so this
// function cannot mint a certificate for an ineligible student or skip a
// number — it only renders and stores the artifact.
//
// Deploy: supabase functions deploy issue-certificate
// Invoke: POST { enrollment_id }  with an admin user's bearer token.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { PDFDocument, StandardFonts, rgb } from 'https://esm.sh/pdf-lib@1.17.1';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const BUCKET = 'certificates';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method not allowed' }, 405);

  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ')) return json({ error: 'missing bearer token' }, 401);

  let enrollmentId: string;
  try {
    ({ enrollment_id: enrollmentId } = await req.json());
  } catch {
    return json({ error: 'invalid JSON body' }, 400);
  }
  if (!enrollmentId) return json({ error: 'enrollment_id is required' }, 400);

  // Caller-scoped client: resolve identity + role from their JWT (RLS applies).
  const asCaller = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const { data: userRes } = await asCaller.auth.getUser();
  const uid = userRes.user?.id;
  if (!uid) return json({ error: 'invalid token' }, 401);

  const { data: role } = await asCaller.rpc('current_app_role');
  if (role !== 'admin') return json({ error: 'admin role required' }, 403);

  // Privileged client for the issuance + storage write.
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });

  // 2. Compute completion. 3. Issue (allocates number, rejects non-eligible).
  const { data: evalId, error: evalErr } = await admin.rpc('evaluate_completion', {
    p_enrollment_id: enrollmentId,
  });
  if (evalErr) return json({ error: `evaluate_completion: ${evalErr.message}` }, 400);

  const { data: certId, error: issueErr } = await admin.rpc('issue_certificate', {
    p_completion_evaluation_id: evalId,
    p_issued_by: uid,
  });
  if (issueErr) return json({ error: `issue_certificate: ${issueErr.message}` }, 400);

  // Fetch the issued row (number + reserved path) plus context for the render.
  const { data: cert, error: certErr } = await admin
    .from('certificates')
    .select('id, certificate_number, pdf_url, enrollment_id, completion_evaluation_id')
    .eq('id', certId)
    .single();
  if (certErr || !cert) return json({ error: 'certificate row not found after issue' }, 500);

  const { data: ev } = await admin
    .from('completion_evaluations')
    .select('outcome, clock_hours_earned, final_exam_score')
    .eq('id', cert.completion_evaluation_id)
    .single();

  const { data: enr } = await admin
    .from('enrollments')
    .select('students(first_name, last_name), cohorts(name, programs(name, version))')
    .eq('id', cert.enrollment_id)
    .single();

  // deno-lint-ignore no-explicit-any
  const e = enr as any;
  const studentName =
    `${e?.students?.first_name ?? ''} ${e?.students?.last_name ?? ''}`.trim() || 'Graduate';
  const programName = e?.cohorts?.programs?.name ?? 'Program';
  const cohortName = e?.cohorts?.name ?? '';
  const distinction = ev?.outcome === 'completed_with_distinction';

  // 4. Render the PDF.
  const pdfBytes = await renderCertificate({
    studentName,
    programName,
    cohortName,
    certificateNumber: cert.certificate_number,
    distinction,
    clockHours: ev?.clock_hours_earned ?? 0,
  });

  const path = cert.pdf_url ?? `${cert.certificate_number}.pdf`;
  const objectPath = path.startsWith('certificates/') ? path.slice('certificates/'.length) : path;

  const { error: upErr } = await admin.storage
    .from(BUCKET)
    .upload(objectPath, pdfBytes, { contentType: 'application/pdf', upsert: true });
  if (upErr) return json({ error: `storage upload: ${upErr.message}` }, 500);

  // 5. Persist the resolved storage path.
  const storedPath = `${BUCKET}/${objectPath}`;
  await admin.from('certificates').update({ pdf_url: storedPath }).eq('id', cert.id);

  return json({
    certificate_id: cert.id,
    certificate_number: cert.certificate_number,
    outcome: ev?.outcome,
    pdf_url: storedPath,
  });
});

interface RenderArgs {
  studentName: string;
  programName: string;
  cohortName: string;
  certificateNumber: string;
  distinction: boolean;
  clockHours: number;
}

async function renderCertificate(a: RenderArgs): Promise<Uint8Array> {
  const doc = await PDFDocument.create();
  const page = doc.addPage([792, 612]); // US Letter landscape
  const { width, height } = page.getSize();
  const serif = await doc.embedFont(StandardFonts.TimesRoman);
  const serifBold = await doc.embedFont(StandardFonts.TimesRomanBold);

  const felt = rgb(0.043, 0.239, 0.18);
  const brass = rgb(0.78, 0.627, 0.267);
  const ink = rgb(0.08, 0.13, 0.11);

  // Border
  page.drawRectangle({ x: 24, y: 24, width: width - 48, height: height - 48, borderColor: brass, borderWidth: 3 });
  page.drawRectangle({ x: 32, y: 32, width: width - 64, height: height - 64, borderColor: felt, borderWidth: 1 });

  const center = (text: string, y: number, size: number, font = serif, color = ink) => {
    const w = font.widthOfTextAtSize(text, size);
    page.drawText(text, { x: (width - w) / 2, y, size, font, color });
  };

  center('TEXAS GAMING INSTITUTE', height - 110, 26, serifBold, felt);
  center('Certificate of Completion', height - 150, 18, serif, ink);
  center('This certifies that', height - 210, 14, serif, ink);
  center(a.studentName, height - 250, 32, serifBold, felt);
  center('has successfully completed the', height - 296, 14, serif, ink);
  center(a.programName, height - 328, 20, serifBold, ink);

  if (a.distinction) {
    center('— WITH DISTINCTION —', height - 360, 15, serifBold, brass);
  }

  center(
    `${a.clockHours.toFixed(2)} clock hours${a.cohortName ? ` · Cohort ${a.cohortName}` : ''}`,
    height - 396, 12, serif, ink,
  );

  // Footer: certificate number (gapless) + issue date.
  page.drawText(`Certificate No. ${a.certificateNumber}`, { x: 60, y: 60, size: 11, font: serifBold, color: felt });
  const dateStr = new Date().toISOString().slice(0, 10);
  const dw = serif.widthOfTextAtSize(`Issued ${dateStr}`, 11);
  page.drawText(`Issued ${dateStr}`, { x: width - 60 - dw, y: 60, size: 11, font: serif, color: ink });

  return await doc.save();
}
