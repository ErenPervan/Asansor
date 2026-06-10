-- ============================================================================
-- Migration: Remove webhook fallback secrets, fix Auth header inconsistency,
--            and replace <YOUR_ANON_KEY> placeholder.
-- Covers: yapilacaklar2.md Madde 2, 3, 4
-- ============================================================================

-- ── 1. notify_technician_on_assignment ──────────────────────────────────────
CREATE OR REPLACE FUNCTION notify_technician_on_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net
AS $$
DECLARE
  _edge_function_url TEXT;
  _anon_key          TEXT;
  _webhook_secret    TEXT;
  _payload           JSONB;
BEGIN
  _edge_function_url := 'https://fuwmrhahwvsouhcxycyr.supabase.co/functions/v1/send-notification';
  
  -- Madde 3: Placeholder yerine app_settings tablosundan oku; yoksa hata fırlat
  SELECT value INTO _anon_key FROM public.app_settings WHERE key = 'anon_key';
  IF _anon_key IS NULL THEN
    RAISE WARNING '[notify_technician_on_assignment] anon_key app_settings tablosunda bulunamadı. Bildirim gönderilemedi.';
    RETURN NEW;
  END IF;
  
  -- Madde 2: Fallback secret kaldırıldı; yoksa bildirim gönderilmez
  SELECT value INTO _webhook_secret FROM public.app_settings WHERE key = 'webhook_secret';
  IF _webhook_secret IS NULL THEN
    RAISE WARNING '[notify_technician_on_assignment] webhook_secret app_settings tablosunda bulunamadı. Bildirim gönderilemedi.';
    RETURN NEW;
  END IF;

  _payload := jsonb_build_object(
    'type',   'INSERT',
    'table',  TG_TABLE_NAME,
    'schema', TG_TABLE_SCHEMA,
    'record', row_to_json(NEW)::jsonb
  );

  -- Madde 4: Authorization header eklendi (tutarlı)
  PERFORM net.http_post(
    url     := _edge_function_url,
    headers := jsonb_build_object(
      'Content-Type',     'application/json',
      'Authorization',    'Bearer ' || _anon_key,
      'x-webhook-secret', _webhook_secret
    ),
    body    := _payload
  );

  RETURN NEW;
END;
$$;

-- ── 2. notify_fault_report ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_fault_report()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net
AS $$
DECLARE
  v_url            text;
  v_anon_key       text;
  v_webhook_secret text;
  v_payload        jsonb;
  v_headers        jsonb;
BEGIN
  -- Madde 3: anon_key app_settings'ten okunuyor
  SELECT value INTO v_anon_key FROM public.app_settings WHERE key = 'anon_key';
  IF v_anon_key IS NULL THEN
    RAISE WARNING '[notify_fault_report] anon_key app_settings tablosunda bulunamadı. Bildirim gönderilemedi.';
    RETURN NEW;
  END IF;

  -- Madde 2: Fallback secret kaldırıldı
  SELECT value INTO v_webhook_secret FROM public.app_settings WHERE key = 'webhook_secret';
  IF v_webhook_secret IS NULL THEN
    RAISE WARNING '[notify_fault_report] webhook_secret app_settings tablosunda bulunamadı. Bildirim gönderilemedi.';
    RETURN NEW;
  END IF;
  
  v_payload := json_build_object(
    'type', 'INSERT',
    'table', TG_TABLE_NAME,
    'schema', TG_TABLE_SCHEMA,
    'record', row_to_json(NEW),
    'old_record', null
  )::jsonb;

  v_url := 'https://fuwmrhahwvsouhcxycyr.supabase.co/functions/v1/send-notification';
  
  -- Madde 4: Authorization header eklendi (artık tutarlı)
  v_headers := jsonb_build_object(
    'Content-Type',     'application/json',
    'Authorization',    'Bearer ' || v_anon_key,
    'x-webhook-secret', v_webhook_secret
  );

  PERFORM net.http_post(
    url     := v_url,
    headers := v_headers,
    body    := v_payload
  );

  RETURN NEW;
END;
$$;
