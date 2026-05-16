alter table fault_reports
  add column if not exists fault_type text,
  add column if not exists priority text;
