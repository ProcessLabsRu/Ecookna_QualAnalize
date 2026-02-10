CREATE OR REPLACE FUNCTION public.check_missing_glass(p_pos_id bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_missing text[];
BEGIN
  WITH pos AS (
    SELECT id, position_formula, COALESCE(article_json, '[]'::json) AS article_json
    FROM public.qual_analize_pos
    WHERE id = p_pos_id
  ),

  -- стекла из формулы: ПОРЯДОК СТЕКОЛ, а не элементов
  formula_glass AS (
    SELECT
      row_number() OVER (ORDER BY e.ord) AS glass_ord,
      e.article
    FROM pos p
    JOIN LATERAL public.parse_order_elements(p.position_formula) e ON true
    WHERE e.element_type = 'glass'
  ),

  -- стекла из article_json
  json_glass AS (
    SELECT
      NULLIF(regexp_replace(coalesce(elem->>'Порядок',''), '[^0-9]+', '', 'g'), '')::int AS glass_ord,
      NULLIF(btrim(elem->>'Артикул'), '') AS article,
      NULLIF(btrim(elem->>'Вид_стекла'), '') AS glass_type
    FROM pos p
    JOIN LATERAL json_array_elements(p.article_json) elem ON true
  ),

  missing AS (
    SELECT
      fg.article
    FROM formula_glass fg
    LEFT JOIN json_glass jg
      ON jg.glass_ord = fg.glass_ord
    WHERE
      jg.glass_ord IS NULL
      OR jg.article IS NULL
      OR jg.glass_type IS NULL
  )

  SELECT array_agg(DISTINCT article)
  INTO v_missing
  FROM missing;

  IF v_missing IS NOT NULL THEN
    DELETE FROM public.qual_analize_pos_issues
    WHERE pos_id = p_pos_id
      AND issue_code = 'GLASS_NOT_FOUND';

    INSERT INTO public.qual_analize_pos_issues
      (pos_id, issue_code, severity, message, context)
    VALUES (
      p_pos_id,
      'GLASS_NOT_FOUND',
      'error',
      'Не найдены артикулы стекол в справочнике',
      jsonb_build_object(
        'missing_articles', v_missing,
        'source', 'position_formula + article_json'
      )
    );
  END IF;
END;
$function$;