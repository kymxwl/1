import { supabase } from '@/lib/supabase';
import type { Certificate } from '@/types/database';

/**
 * M8 client surface. Certificate issuance runs in the `issue-certificate` edge
 * function (privileged: evaluate → issue → render PDF → store). The client only
 * triggers it and reads the result; it can neither allocate a number nor
 * override eligibility.
 */

export interface IssueResult {
  certificate_id: string;
  certificate_number: string;
  outcome: string;
  pdf_url: string;
}

/** Issue a certificate for an enrollment (admin only; enforced server-side). */
export async function issueCertificate(enrollmentId: string): Promise<IssueResult> {
  const { data, error } = await supabase.functions.invoke<IssueResult>('issue-certificate', {
    body: { enrollment_id: enrollmentId },
  });
  if (error) throw error;
  if (!data) throw new Error('No response from issue-certificate');
  return data;
}

/** The certificate for an enrollment, if one has been issued. */
export async function getCertificate(enrollmentId: string): Promise<Certificate | null> {
  const { data, error } = await supabase
    .from('certificates')
    .select('*')
    .eq('enrollment_id', enrollmentId)
    .maybeSingle();
  if (error) throw error;
  return data;
}

/**
 * A short-lived signed URL to view/download a certificate PDF from the private
 * bucket. `pdf_url` is stored as "certificates/<file>"; strip the bucket prefix.
 */
export async function signedCertificateUrl(
  pdfUrl: string,
  expiresInSeconds = 300,
): Promise<string> {
  const objectPath = pdfUrl.replace(/^certificates\//, '');
  const { data, error } = await supabase.storage
    .from('certificates')
    .createSignedUrl(objectPath, expiresInSeconds);
  if (error) throw error;
  return data.signedUrl;
}
