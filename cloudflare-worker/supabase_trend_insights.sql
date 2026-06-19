-- Pulse trend insight tables for Supabase/PostgreSQL.
-- MVP endpoints can compute from the existing trends table, but these tables
-- let scheduled jobs persist aggregates instead of recalculating on demand.

create table if not exists trend_keywords (
  id uuid primary key default gen_random_uuid(),
  keyword text not null,
  normalized_keyword text not null,
  category text,
  period text not null check (period in ('1h', '6h', '24h', '7d')),
  window_start timestamptz not null,
  window_end timestamptz not null,
  news_count integer not null default 0,
  rank integer,
  score numeric not null default 0,
  sentiment_temperature integer,
  created_at timestamptz not null default now()
);

create index if not exists idx_trend_keywords_period_category_rank
  on trend_keywords (period, category, rank);

create index if not exists idx_trend_keywords_keyword_window
  on trend_keywords (normalized_keyword, period, window_end desc);

create index if not exists idx_trend_keywords_window
  on trend_keywords (window_end desc);

create table if not exists keyword_news_map (
  id uuid primary key default gen_random_uuid(),
  keyword_id uuid references trend_keywords(id) on delete cascade,
  news_id bigint not null,
  keyword text not null,
  normalized_keyword text not null,
  category text,
  weight numeric not null default 1,
  created_at timestamptz not null default now()
);

create index if not exists idx_keyword_news_map_keyword
  on keyword_news_map (normalized_keyword, created_at desc);

create index if not exists idx_keyword_news_map_news
  on keyword_news_map (news_id);

create index if not exists idx_keyword_news_map_keyword_id
  on keyword_news_map (keyword_id);

create table if not exists trending_issues (
  id uuid primary key default gen_random_uuid(),
  keyword text not null,
  normalized_keyword text not null,
  category text,
  period text not null check (period in ('1h', '6h', '24h')),
  current_count integer not null default 0,
  previous_count integer not null default 0,
  growth_rate numeric not null default 0,
  score numeric not null default 0,
  representative_news_id bigint,
  representative_title text,
  window_start timestamptz not null,
  window_end timestamptz not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_trending_issues_period_category_score
  on trending_issues (period, category, score desc);

create index if not exists idx_trending_issues_keyword_window
  on trending_issues (normalized_keyword, period, window_end desc);

create table if not exists news_sentiments (
  id uuid primary key default gen_random_uuid(),
  news_id bigint not null unique,
  sentiment_label text not null check (sentiment_label in ('positive', 'neutral', 'negative')),
  sentiment_score integer not null check (sentiment_score between 0 and 100),
  confidence numeric,
  model text,
  analyzed_target text not null default 'title',
  created_at timestamptz not null default now()
);

create index if not exists idx_news_sentiments_label
  on news_sentiments (sentiment_label);

create index if not exists idx_news_sentiments_score
  on news_sentiments (sentiment_score);

create index if not exists idx_news_sentiments_created_at
  on news_sentiments (created_at desc);

create table if not exists search_logs (
  id uuid primary key default gen_random_uuid(),
  query text not null,
  category text,
  period text,
  sort text,
  result_count integer,
  user_id uuid,
  created_at timestamptz not null default now()
);

create index if not exists idx_search_logs_query
  on search_logs (query);

create index if not exists idx_search_logs_created_at
  on search_logs (created_at desc);

create table if not exists keyword_aliases (
  id uuid primary key default gen_random_uuid(),
  keyword text not null,
  normalized_keyword text not null,
  alias text not null,
  normalized_alias text not null,
  created_at timestamptz not null default now()
);

create unique index if not exists idx_keyword_aliases_alias
  on keyword_aliases (normalized_alias);
