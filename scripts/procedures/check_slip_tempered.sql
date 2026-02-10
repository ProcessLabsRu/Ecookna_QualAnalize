CREATE OR REPLACE FUNCTION public.check_slip_tempered(p_pos_id bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_slip text;
  v_articles jsonb;

  v_missing text[];
BEGIN
  -- 1) Забираем данные позиции
  SELECT
    p.position_formula_slip,
    p.article_json::jsonb
  INTO
    v_slip,
    v_articles
  FROM public.qual_analize_pos p
  WHERE p.id = p_pos_id;

  IF v_slip IS NULL OR v_articles IS NULL THEN
    RETURN;
  END IF;

  -- 2) slip требует закалку? (в формуле есть "4з", "6з" и т.п.)
  IF NOT (v_slip ~ '\d+\s*з') THEN
    RETURN;
  END IF;

  -- 3) НОРМАЛИЗАЦИЯ article_json:
  --    иногда он приходит как JSON-строка: "[{...},{...}]"
  IF jsonb_typeof(v_articles) = 'string' THEN
    BEGIN
      v_articles := (v_articles #>> '{}')::jsonb;
    EXCEPTION WHEN others THEN
      -- не удалось распаковать строку в json
      RETURN;
    END;
  END IF;

  -- если после распаковки это всё равно не массив — выходим
  IF jsonb_typeof(v_articles) <> 'array' THEN
    RETURN;
  END IF;

  -- 4) Собираем стекла, которые НЕ выглядят закаленными
  SELECT array_agg(a.article ORDER BY a.ord)
  INTO v_missing
  FROM (
    SELECT
      e->>'Артикул' AS article,
      coalesce(e->>'Обработка','') AS obr,
      COALESCE(NULLIF(e->>'Порядок','')::int, 9999) AS ord
    FROM jsonb_array_elements(v_articles) e
    WHERE coalesce(e->>'Артикул','') <> ''
  ) a
  WHERE
    -- откидываем рамки типа W14 / Н14
    a.article !~* '^(w|н)\s*\d+'
    -- нет "4з"/"6з" в артикуле
    AND NOT (a.article ~ '\d+\s*з')
    -- и обработка не говорит о закалке
    AND a.obr !~* '(закал|tempe|esg|harden|toughen)';

  IF v_missing IS NULL OR array_length(v_missing, 1) IS NULL THEN
    RETURN;
  END IF;

  -- 5) Антидубли
  DELETE FROM public.qual_analize_pos_issues
  WHERE pos_id = p_pos_id
    AND issue_code = 'SLIP_TEMPER_REQUIRED';

  -- 6) Пишем ошибку (без номера позиции + с формулой слипания)
  INSERT INTO public.qual_analize_pos_issues
    (pos_id, issue_code, severity, message, context)
  VALUES
    (
      p_pos_id,
      'SLIP_TEMPER_REQUIRED',
      'error',
      format(
        'Формула слипания %s требует закалку ("з"), но в формуле позиции нет закалки у стекол: %s',
        coalesce(v_slip, 'не указана'),
        array_to_string(v_missing, ', ')
      ),
      jsonb_build_object(
        'position_formula_slip', v_slip,
        'missing_tempered_glasses', v_missing,
        'source', 'article_json'
      )
    );

END;
$function$;