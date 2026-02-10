CREATE OR REPLACE FUNCTION public.collect_file_issues_message(p_file_id bigint)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  result text := '';
  block text;

  p record;

  issues_cnt int;
  has_slip boolean;

  f1 text;
  f2 text;

  -- slip mismatch
  ctx_mismatch jsonb;
  use_side text;
  order_th int[];
  req_th int[];
  bad_idx int[];

  -- tempered
  ctx_temper jsonb;
  missing_tempered text[];
  glass_articles text[];

  lines text[] := ARRAY[]::text[];

  i int;
  idx int;
  fact int;
  reqv int;

  glass_no int;
  frame_no int;
  ord_word text;

  other_issues text;
  agg_text text;

  common_head text;

  -- for bad_pairs parsing "k: a < b"
  pair_txt text;
  pair_idx int;
  pair_fact int;
  pair_req int;
  m text[];

  sev_icon text;
BEGIN
  FOR p IN
    SELECT *
    FROM public.qual_analize_pos
    WHERE file_id = p_file_id
    ORDER BY position_num
  LOOP
    block := '';
    lines := ARRAY[]::text[];

    -- Если по позиции нет ошибок/предупреждений — не выводим
    SELECT COUNT(*)
    INTO issues_cnt
    FROM public.qual_analize_pos_issues ii
    WHERE ii.pos_id = p.id;

    IF issues_cnt = 0 THEN
      CONTINUE;
    END IF;

    f1 := p.f1;
    f2 := p.f2;

    -- Единая "шапка"
    common_head :=
      format('Позиция №%s', coalesce(p.position_num, p.id::text))
      || E'\n\n'
      || format(
           'Размер: %s × %s (%s × %s)',
           coalesce(p.position_width, 0),
           coalesce(p.position_hight, 0),
           coalesce(p.position_width_round, 0),
           coalesce(p.position_hight_round, 0)
         )
      || E'\n'
      || format('Исходная формула: %s', coalesce(p.position_formula, '—'));

    -- Есть ли slip-ошибки
    SELECT EXISTS (
      SELECT 1
      FROM public.qual_analize_pos_issues ii
      WHERE ii.pos_id = p.id
        AND ii.issue_code IN ('SLIP_FORMULA_MISSING','SLIP_MISMATCH','SLIP_TEMPER_REQUIRED')
    )
    INTO has_slip;

    -- =========================
    -- SLIP: по шаблону заказчика
    -- =========================
    IF has_slip THEN
      block := common_head
        || E'\n\n'
        || 'Допустимые формулы по таблице слипаемости: '
        || CASE
             WHEN f1 IS NULL AND f2 IS NULL THEN 'не найдены для округленного размера'
             WHEN f1 IS NOT NULL AND f2 IS NOT NULL THEN f1 || ' / ' || f2
             WHEN f1 IS NOT NULL THEN f1
             ELSE f2
           END
        || E'\n\n'
        || 'Выявленные несоответствия:'
        || E'\n';

      -- -------------------------------------------------
      -- 1) SLIP_MISMATCH
      -- context пример:
      -- f1_bad_pairs: ["1: 4 < 6", ...]
      -- f1_bad_indexes: [1,2,3...]
      -- order_thickness: [4,10,4...]
      -- f1_req: [6,12,6...]
      -- -------------------------------------------------
      SELECT ii.context
      INTO ctx_mismatch
      FROM public.qual_analize_pos_issues ii
      WHERE ii.pos_id = p.id
        AND ii.issue_code = 'SLIP_MISMATCH'
      ORDER BY ii.created_at DESC
      LIMIT 1;

      IF ctx_mismatch IS NOT NULL THEN
        -- выбираем сторону: если массив f1_bad_indexes есть -> f1; иначе f2
        IF jsonb_typeof(ctx_mismatch->'f1_bad_indexes') = 'array' THEN
          use_side := 'f1';
        ELSIF jsonb_typeof(ctx_mismatch->'f2_bad_indexes') = 'array' THEN
          use_side := 'f2';
        ELSE
          use_side := NULL;
        END IF;

        -- 1a) Если есть bad_pairs — распарсим и сделаем "первое стекло/первая рамка"
        IF use_side = 'f1' AND jsonb_typeof(ctx_mismatch->'f1_bad_pairs') = 'array' THEN
          FOR pair_txt IN
            SELECT x
            FROM jsonb_array_elements_text(ctx_mismatch->'f1_bad_pairs') t(x)
          LOOP
            -- ожидаем "k: a < b" (k индекс, a факт, b треб)
            m := regexp_match(pair_txt, '^\s*(\d+)\s*:\s*([0-9]+)\s*<\s*([0-9]+)\s*$');

            IF m IS NULL THEN
              -- если формат неожиданный — выводим как есть
              lines := lines || ('— ' || pair_txt);
            ELSE
              pair_idx  := m[1]::int;
              pair_fact := m[2]::int;
              pair_req  := m[3]::int;

              IF pair_idx % 2 = 1 THEN
                glass_no := (pair_idx + 1) / 2;
                ord_word := CASE glass_no
                  WHEN 1 THEN 'первое'
                  WHEN 2 THEN 'второе'
                  WHEN 3 THEN 'третье'
                  WHEN 4 THEN 'четвертое'
                  ELSE glass_no::text || '-е'
                END;

                lines := lines || format(
                  '— %s стекло: толщина %s мм, допустимая — %s мм',
                  ord_word, pair_fact, pair_req
                );
              ELSE
                frame_no := pair_idx / 2;
                ord_word := CASE frame_no
                  WHEN 1 THEN 'первая'
                  WHEN 2 THEN 'вторая'
                  WHEN 3 THEN 'третья'
                  WHEN 4 THEN 'четвертая'
                  ELSE frame_no::text || '-я'
                END;

                lines := lines || format(
                  '— %s рамка: толщина %s мм, допустимая — %s мм',
                  ord_word, pair_fact, pair_req
                );
              END IF;
            END IF;
          END LOOP;

        ELSIF use_side = 'f2' AND jsonb_typeof(ctx_mismatch->'f2_bad_pairs') = 'array' THEN
          FOR pair_txt IN
            SELECT x
            FROM jsonb_array_elements_text(ctx_mismatch->'f2_bad_pairs') t(x)
          LOOP
            m := regexp_match(pair_txt, '^\s*(\d+)\s*:\s*([0-9]+)\s*<\s*([0-9]+)\s*$');

            IF m IS NULL THEN
              lines := lines || ('— ' || pair_txt);
            ELSE
              pair_idx  := m[1]::int;
              pair_fact := m[2]::int;
              pair_req  := m[3]::int;

              IF pair_idx % 2 = 1 THEN
                glass_no := (pair_idx + 1) / 2;
                ord_word := CASE glass_no
                  WHEN 1 THEN 'первое'
                  WHEN 2 THEN 'второе'
                  WHEN 3 THEN 'третье'
                  WHEN 4 THEN 'четвертое'
                  ELSE glass_no::text || '-е'
                END;

                lines := lines || format(
                  '— %s стекло: толщина %s мм, допустимая — %s мм',
                  ord_word, pair_fact, pair_req
                );
              ELSE
                frame_no := pair_idx / 2;
                ord_word := CASE frame_no
                  WHEN 1 THEN 'первая'
                  WHEN 2 THEN 'вторая'
                  WHEN 3 THEN 'третья'
                  WHEN 4 THEN 'четвертая'
                  ELSE frame_no::text || '-я'
                END;

                lines := lines || format(
                  '— %s рамка: толщина %s мм, допустимая — %s мм',
                  ord_word, pair_fact, pair_req
                );
              END IF;
            END IF;
          END LOOP;

        ELSE
          -- 1b) fallback: индексная детализация (на случай, если bad_pairs нет)
          order_th := ARRAY(
            SELECT x::int
            FROM jsonb_array_elements_text(
              CASE WHEN jsonb_typeof(ctx_mismatch->'order_thickness') = 'array'
                   THEN ctx_mismatch->'order_thickness'
                   ELSE '[]'::jsonb
              END
            ) t(x)
          );

          IF use_side = 'f1' THEN
            req_th := ARRAY(
              SELECT x::int
              FROM jsonb_array_elements_text(
                CASE WHEN jsonb_typeof(ctx_mismatch->'f1_req')='array'
                     THEN ctx_mismatch->'f1_req'
                     ELSE '[]'::jsonb
                END
              ) t(x)
            );
            bad_idx := ARRAY(
              SELECT x::int
              FROM jsonb_array_elements_text(
                CASE WHEN jsonb_typeof(ctx_mismatch->'f1_bad_indexes')='array'
                     THEN ctx_mismatch->'f1_bad_indexes'
                     ELSE '[]'::jsonb
                END
              ) t(x)
            );
          ELSIF use_side = 'f2' THEN
            req_th := ARRAY(
              SELECT x::int
              FROM jsonb_array_elements_text(
                CASE WHEN jsonb_typeof(ctx_mismatch->'f2_req')='array'
                     THEN ctx_mismatch->'f2_req'
                     ELSE '[]'::jsonb
                END
              ) t(x)
            );
            bad_idx := ARRAY(
              SELECT x::int
              FROM jsonb_array_elements_text(
                CASE WHEN jsonb_typeof(ctx_mismatch->'f2_bad_indexes')='array'
                     THEN ctx_mismatch->'f2_bad_indexes'
                     ELSE '[]'::jsonb
                END
              ) t(x)
            );
          ELSE
            bad_idx := NULL;
          END IF;

          IF bad_idx IS NOT NULL AND array_length(bad_idx,1) IS NOT NULL THEN
            FOREACH idx IN ARRAY bad_idx LOOP
              fact := NULL;
              reqv := NULL;

              IF order_th IS NOT NULL AND array_length(order_th,1) >= idx THEN
                fact := order_th[idx];
              END IF;
              IF req_th IS NOT NULL AND array_length(req_th,1) >= idx THEN
                reqv := req_th[idx];
              END IF;

              IF idx % 2 = 1 THEN
                glass_no := (idx + 1) / 2;
                ord_word := CASE glass_no
                  WHEN 1 THEN 'первое'
                  WHEN 2 THEN 'второе'
                  WHEN 3 THEN 'третье'
                  WHEN 4 THEN 'четвертое'
                  ELSE glass_no::text || '-е'
                END;
                lines := lines || format(
                  '— %s стекло: толщина %s мм, допустимая — %s мм',
                  ord_word,
                  coalesce(fact::text,'—'),
                  coalesce(reqv::text,'—')
                );
              ELSE
                frame_no := idx / 2;
                ord_word := CASE frame_no
                  WHEN 1 THEN 'первая'
                  WHEN 2 THEN 'вторая'
                  WHEN 3 THEN 'третья'
                  WHEN 4 THEN 'четвертая'
                  ELSE frame_no::text || '-я'
                END;
                lines := lines || format(
                  '— %s рамка: толщина %s мм, допустимая — %s мм',
                  ord_word,
                  coalesce(fact::text,'—'),
                  coalesce(reqv::text,'—')
                );
              END IF;
            END LOOP;
          END IF;
        END IF;
      END IF;

      -- -------------------------------------------------
      -- 2) SLIP_TEMPER_REQUIRED (нужна закалка)
      -- context: missing_tempered_glasses: [ ... ]
      -- -------------------------------------------------
      SELECT ii.context
      INTO ctx_temper
      FROM public.qual_analize_pos_issues ii
      WHERE ii.pos_id = p.id
        AND ii.issue_code = 'SLIP_TEMPER_REQUIRED'
      ORDER BY ii.created_at DESC
      LIMIT 1;

      IF ctx_temper IS NOT NULL THEN
        missing_tempered := ARRAY(
          SELECT x
          FROM jsonb_array_elements_text(
            CASE WHEN jsonb_typeof(ctx_temper->'missing_tempered_glasses')='array'
                 THEN ctx_temper->'missing_tempered_glasses'
                 ELSE '[]'::jsonb
            END
          ) t(x)
        );

        SELECT array_agg(e.article ORDER BY e.ord)
        INTO glass_articles
        FROM public.parse_order_elements(p.position_formula) e
        WHERE e.element_type = 'glass';

        IF missing_tempered IS NOT NULL AND array_length(missing_tempered,1) IS NOT NULL THEN
          FOREACH ord_word IN ARRAY missing_tempered LOOP
            glass_no := NULL;

            IF glass_articles IS NOT NULL THEN
              FOR i IN 1..array_length(glass_articles,1) LOOP
                IF glass_articles[i] = ord_word THEN
                  glass_no := i;
                  EXIT;
                END IF;
              END LOOP;
            END IF;

            lines := lines || format(
              '— %s стекло: в заказе используется сырое стекло, по таблице требуется закалённое',
              CASE coalesce(glass_no, 0)
                WHEN 1 THEN 'первое'
                WHEN 2 THEN 'второе'
                WHEN 3 THEN 'третье'
                WHEN 4 THEN 'четвертое'
                WHEN 0 THEN 'это'
                ELSE glass_no::text || '-е'
              END
            );
          END LOOP;
        END IF;
      END IF;

      -- -------------------------------------------------
      -- 3) SLIP_FORMULA_MISSING
      -- -------------------------------------------------
      SELECT count(*)
      INTO i
      FROM public.qual_analize_pos_issues ii
      WHERE ii.pos_id = p.id
        AND ii.issue_code = 'SLIP_FORMULA_MISSING';

      IF i > 0 THEN
        lines := lines || '— Отсутствует формула в таблице слипания (не найдены f1 и f2)';
      END IF;

      IF lines IS NULL OR array_length(lines,1) IS NULL THEN
        lines := ARRAY['— Несоответствие формулы требованиям таблицы слипаемости (детализация недоступна)'];
      END IF;

      block := block
        || array_to_string(lines, E'\n')
        || E'\n\n'
        || 'Требуется согласование с Технической поддержкой Фототех.';

      -- Прочие ошибки/предупреждения (кроме slip) — иконка + message
      SELECT string_agg(
               (CASE
                  WHEN ii.severity = 'error' THEN '⛔️ '
                  WHEN ii.severity IN ('warning','warn') THEN '⚠️ '
                  ELSE 'ℹ️ '
                END) || ii.message,
               E'\n'
               ORDER BY
                 CASE ii.severity WHEN 'error' THEN 1 WHEN 'warning' THEN 2 WHEN 'warn' THEN 2 ELSE 3 END,
                 ii.issue_code
             )
      INTO other_issues
      FROM public.qual_analize_pos_issues ii
      WHERE ii.pos_id = p.id
        AND ii.issue_code NOT IN ('SLIP_FORMULA_MISSING','SLIP_MISMATCH','SLIP_TEMPER_REQUIRED');

      IF other_issues IS NOT NULL AND btrim(other_issues) <> '' THEN
        block := block || E'\n\n' || other_issues;
      END IF;

    ELSE
      -- =========================
      -- НЕ-SLIP: "шапка" + список сообщений с иконками
      -- =========================
      SELECT string_agg(
               (CASE
                  WHEN ii.severity = 'error' THEN '⛔️ '
                  WHEN ii.severity IN ('warning','warn') THEN '⚠️ '
                  ELSE 'ℹ️ '
                END) || ii.message,
               E'\n'
               ORDER BY
                 CASE ii.severity WHEN 'error' THEN 1 WHEN 'warning' THEN 2 WHEN 'warn' THEN 2 ELSE 3 END,
                 ii.issue_code
             )
      INTO agg_text
      FROM public.qual_analize_pos_issues ii
      WHERE ii.pos_id = p.id;

      IF agg_text IS NULL OR btrim(agg_text) = '' THEN
        CONTINUE;
      END IF;

      block := common_head || E'\n\n' || agg_text;
    END IF;

    IF block IS NOT NULL AND btrim(block) <> '' THEN
      IF result <> '' THEN
        result := result || E'\n\n';
      END IF;
      result := result || block;
    END IF;

  END LOOP;

  RETURN NULLIF(result, '');
END;
$function$;