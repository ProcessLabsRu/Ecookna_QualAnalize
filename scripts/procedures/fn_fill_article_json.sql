CREATE OR REPLACE FUNCTION public.fn_fill_article_json()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    parts text[];
    raw text := NEW.position_formula;
    part text;
    glasses text[] := ARRAY[]::text[];
    result jsonb := '[]'::jsonb;
    g record;
    seq int := 1;
BEGIN
    IF raw IS NULL OR trim(raw) = '' THEN
        NEW.article_json := NULL;
        RETURN NEW;
    END IF;

    -- Нормализуем: гарантируем, что разделителем будет символ 'x' (без учета регистра)
    -- и убираем пробелы вокруг
    raw := replace(trim(raw), ' ', '');

    -- Разбиваем по 'x' (регистр не важен, но тут уже все без пробелов)
    parts := string_to_array(raw, 'x');

    -- Берём элементы 1,3,5... (в SQL: 1..n, индексы 1-based)
    FOR idx IN 1..array_length(parts,1) LOOP
        IF (idx % 2 = 1) THEN
            part := parts[idx];

            -- Ищем артикула в art_rules
            SELECT glass_article,
                   glass_type,
                   type_of_glass,
                   type_of_processing,
                   surface,
                   note,
                   analog_list
            INTO g
            FROM public.art_rules
            WHERE glass_article = part
            LIMIT 1;

            IF FOUND THEN
                result := result || jsonb_build_object(
                    'Артикул', g.glass_article,
                    'Расчет_по_СО', g.glass_type,
                    'Вид_стекла', g.type_of_glass,
                    'Обработка', g.type_of_processing,
                    'Поверхность', g.surface,
                    'Примечание', g.note,
                    'Аналоги', g.analog_list,
                    'Порядок', seq
                );
            ELSE
                result := result || jsonb_build_object(
                    'Артикул', part,
                    'Ошибка', 'Артикул не найден в art_rules',
                    'Порядок', seq
                );
            END IF;

            seq := seq + 1;
        END IF;
    END LOOP;

    NEW.article_json := result;
    RETURN NEW;
END;
$function$;