-- =============================================================================
-- 20260101002000_resource_body.sql
-- Let a resource carry inline reference text (not just an external URL), so the
-- manual's presentational sections (the TGI Standard, codes/oaths, instructor
-- forms) can be loaded as resources and read in-app. `url` becomes optional; a
-- resource has a `url` (link out) OR a `body` (inline text) — or both.
-- =============================================================================

alter table resources alter column url drop not null;
alter table resources add column if not exists body text;
alter table resources drop constraint if exists resources_url_or_body;
alter table resources add constraint resources_url_or_body
  check (url is not null or body is not null);
