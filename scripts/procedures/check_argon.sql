CREATE OR REPLACE FUNCTION public.check_argon(p_pos_id bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_position_num text;
  v_formula text;

  v_frames_total int;
  v_frames_argon int;
  v_has_argon boolean;
  v_all_argon boolean;

  v_frames_with_argon text[];
  v_frames_without_argon text[];
BEGIN
  SELECT position_num, position_formula
  INTO v_position_num, v_formula
  FROM public.qual_analize_pos
  WHERE id = p_pos_id;

  IF v_formula IS NULL OR btrim(v_formula) = '' THEN
    RETURN;
  END IF;

  WITH frames AS (
    SELECT *
    FROM public.parse_order_elements(v_formula)
    WHERE element_type = 'frame'
  )
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE is_argon IS TRUE)::int,
    (COUNT(*) FILTER (WHERE is_argon IS TRUE) > 0),
    (CASE
       WHEN COUNT(*) = 0 THEN TRUE
       ELSE COUNT(*) FILTER (WHERE is_argon IS TRUE) = COUNT(*)
     END),
    array_agg(article ORDER BY ord) FILTER (WHERE is_argon IS TRUE),
    array_agg(article ORDER BY ord) FILTER (WHERE is_argon IS NOT TRUE)
  INTO
    v_frames_total,
    v_frames_argon,
    v_has_argon,
    v_all_argon,
    v_frames_with_argon,
    v_frames_without_argon
  FROM frames;

  -- если аргона нет нигде — всё ок
  IF NOT v_has_argon THEN
    RETURN;
  END IF;

  -- если аргон есть, но не во всех рамках — ошибка
  IF NOT v_all_argon THEN
    DELETE FROM public.qual_analize_pos_issues
    WHERE pos_id = p_pos_id
      AND issue_code = 'ARGON_INCOMPLETE';

    INSERT INTO public.qual_analize_pos_issues
      (pos_id, issue_code, severity, message, context)
    VALUES (
      p_pos_id,
      'ARGON_INCOMPLETE',
      'error',
      format(
        'Аргон (Ar) указан не во всех камерах. С аргоном: %s; без аргона: %s',
        coalesce(array_to_string(v_frames_with_argon, ', '), 'нет'),
        coalesce(array_to_string(v_frames_without_argon, ', '), 'нет')
      ),
      jsonb_build_object(
        'position_num', v_position_num,
        'position_formula', v_formula,
        'frames_total', v_frames_total,
        'frames_argon', v_frames_argon,
        'frames_with_argon', coalesce(to_jsonb(v_frames_with_argon), '[]'::jsonb),
        'frames_without_argon', coalesce(to_jsonb(v_frames_without_argon), '[]'::jsonb)
      )
    );
  END IF;

END;
$function$;