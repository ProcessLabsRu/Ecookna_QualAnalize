CREATE OR REPLACE FUNCTION public.recalc_overall(p_pos_id bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_has_error boolean;
  v_has_warn boolean;
  v_msg text;
BEGIN
  SELECT
    bool_or(lower(severity) = 'error'),
    bool_or(lower(severity) = 'warning')
  INTO v_has_error, v_has_warn
  FROM public.qual_analize_pos_issues
  WHERE pos_id = p_pos_id;

  SELECT string_agg(message, ' | ' ORDER BY created_at)
  INTO v_msg
  FROM public.qual_analize_pos_issues
  WHERE pos_id = p_pos_id;

  UPDATE public.qual_analize_pos
  SET
    overall_status =
      CASE
        WHEN COALESCE(v_has_error,false) THEN 'ERROR'
        WHEN COALESCE(v_has_warn,false) THEN 'WARN'
        ELSE 'OK'
      END,
    overall_message = COALESCE(v_msg, ''),
    updated_at = now()
  WHERE id = p_pos_id;
END;
$function$;