-- Persistent user-facing Issue Detail data.
-- Apply this migration before deploying the Worker changes.

alter table if exists issue_clusters
  add column if not exists issue_title text;

alter table if exists tracked_issues
  add column if not exists issue_title text;

create index if not exists idx_issue_clusters_issue_title
  on issue_clusters (issue_title)
  where issue_title is not null;
