-- =============================================================================
-- 20260101001200_storage.sql
-- Certificate PDF storage (M8). The `certificates` bucket is PRIVATE — PDFs are
-- served via short-lived signed URLs, never public. Uploads happen only from the
-- issue-certificate edge function (service role); clients read their own.
--
-- Guarded so this migration is a NO-OP on a bare Postgres (e.g. CI), where the
-- Supabase `storage` schema does not exist. On a real Supabase project the
-- storage schema is present and the bucket + policies are created.
-- =============================================================================

do $$
begin
  if not exists (select 1 from information_schema.schemata where schema_name = 'storage') then
    raise notice 'storage schema absent (bare Postgres) — skipping certificate bucket setup';
    return;
  end if;

  -- Private bucket for certificate PDFs.
  insert into storage.buckets (id, name, public)
  values ('certificates', 'certificates', false)
  on conflict (id) do nothing;

  -- Admins may read any certificate object (issuance/upload uses service role,
  -- which bypasses RLS, so no INSERT policy is needed for the edge function).
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'certificates_admin_read'
  ) then
    execute $p$
      create policy certificates_admin_read on storage.objects
        for select to authenticated
        using (bucket_id = 'certificates' and current_app_role() = 'admin')
    $p$;
  end if;

  -- A student may read the certificate object that belongs to their own
  -- enrollment. The object name is "<certificate_number>.pdf"; join back through
  -- the certificates table to check ownership.
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'certificates_owner_read'
  ) then
    execute $p$
      create policy certificates_owner_read on storage.objects
        for select to authenticated
        using (
          bucket_id = 'certificates'
          and exists (
            select 1
            from certificates c
            join enrollments e on e.id = c.enrollment_id
            join students s on s.id = e.student_id
            where s.profile_id = auth.uid()
              and c.pdf_url = 'certificates/' || storage.objects.name
          )
        )
    $p$;
  end if;
end$$;
