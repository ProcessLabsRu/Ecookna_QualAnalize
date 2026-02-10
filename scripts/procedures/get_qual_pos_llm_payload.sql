CREATE OR REPLACE FUNCTION public.get_qual_pos_llm_payload(p_pos_id bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  WITH p AS (
    SELECT *
    FROM public.qual_analize_pos
    WHERE id = p_pos_id
  ),
  issues AS (
    SELECT
      jsonb_agg(
        jsonb_build_object(
          'issue_code', issue_code,
          'severity', severity,
          'message', message,
          'context', COALESCE(context, '{}'::jsonb),
          'created_at', created_at
        )
        ORDER BY created_at
      ) AS arr,
      bool_or(lower(severity) = 'error')    AS has_error,
      bool_or(lower(severity) = 'warning') AS has_warning
    FROM public.qual_analize_pos_issues
    WHERE pos_id = p_pos_id
  )
  SELECT jsonb_build_object(
    'pos_id', p.id,

    -- ===== Исходные данные =====
    'source', jsonb_build_object(
      'position_formula', p.position_formula,
      'position_width', p.position_width,
      'position_hight', p.position_hight,
      'position_raskl', p.position_raskl
    ),

    -- ===== Расчёты =====
    'computed', jsonb_build_object(
      'position_width_round', p.position_width_round,
      'position_hight_round', p.position_hight_round,
      'cam_count', p.cam_count,
      'slip', jsonb_build_object(
        'marking', p.position_formula_slip,
        'f1', p.f1,
        'f2', p.f2
      )
    ),

    -- ===== Обогащённые стекла =====
    'articles', COALESCE(p.article_json::jsonb, '[]'::jsonb),

    -- ===== Итог =====
    'overall', jsonb_build_object(
      'status', COALESCE(p.overall_status, 'OK'),
      'message', COALESCE(p.overall_message, ''),
      'has_error', COALESCE(i.has_error, false),
      'has_warning', COALESCE(i.has_warning, false)
    ),

    -- ===== Нарушения =====
    'issues', COALESCE(i.arr, '[]'::jsonb),

    -- ===== Метаданные =====
    'meta', jsonb_build_object(
      'date_created', p.date_created
    )
  )
  FROM p
  LEFT JOIN issues i ON true;
$function$;