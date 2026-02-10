CREATE OR REPLACE FUNCTION public.split_marking_formula_simple()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    cleaned_marking TEXT;
    f1 TEXT; f2 TEXT;
    tokens TEXT[];
    i INT;
    sum_1_1k NUMERIC := 0;
    sum_1_2k NUMERIC := 0;
    sum_2_1k NUMERIC := 0;
    sum_2_2k NUMERIC := 0;
BEGIN
    -- 1. Нормализуем строку: убираем лишние пробелы
    cleaned_marking = REGEXP_REPLACE(TRIM(NEW.marking), '\s{2,}', ' ');

    -- 2. Если строка пуста — обнуляем все поля
    IF cleaned_marking = '' THEN
        NEW.formula_1 = NULL;
        NEW.formula_2 = NULL;
        NEW.formula_1_1k = NULL;
        NEW.formula_1_2k = NULL;
        NEW.formula_2_1k = NULL;
        NEW.formula_2_2k = NULL;
        NEW.total_thickness_1_1k = NULL;
        NEW.total_thickness_1_2k = NULL;
        NEW.total_thickness_2_1k = NULL;
        NEW.total_thickness_2_2k = NULL;
        RETURN NEW;
    END IF;

    -- 3. Если первый символ не цифра — всё в formula_1, остальные NULL
    IF SUBSTRING(cleaned_marking FOR 1) !~ '^[0-9]' THEN
        NEW.formula_1 = cleaned_marking;
        NEW.formula_2 = NULL;
        NEW.formula_1_1k = NULL;
        NEW.formula_1_2k = NULL;
        NEW.formula_2_1k = NULL;
        NEW.formula_2_2k = NULL;
        NEW.total_thickness_1_1k = NULL;
        NEW.total_thickness_1_2k = NULL;
        NEW.total_thickness_2_1k = NULL;
        NEW.total_thickness_2_2k = NULL;
        RETURN NEW;
    END IF;

    -- 4. Разделяем marking на formula_1 и formula_2 (по первому пробелу)
    f1 = split_part(cleaned_marking, ' ', 1);
    f2 = NULLIF(split_part(cleaned_marking, ' ', 2), '');

    NEW.formula_1 = f1;
    NEW.formula_2 = f2;

    -- 5. Обрабатываем formula_1 → formula_1_1k и formula_1_2k
    NEW.formula_1_1k =
        CASE
            WHEN f1 LIKE '%(%' THEN SUBSTRING(f1 FROM '^(.*?)\(')
            ELSE f1
        END;

    NEW.formula_1_2k =
        CASE
            WHEN f1 LIKE '%(%' THEN REGEXP_REPLACE(f1, '[\(\)]', '', 'g')
            ELSE NULL
        END;

    -- 6. Обрабатываем formula_2 → formula_2_1k и formula_2_2k
    IF f2 IS NOT NULL THEN
        NEW.formula_2_1k =
            CASE
                WHEN f2 LIKE '%(%' THEN SUBSTRING(f2 FROM '^(.*?)\(')
                ELSE f2
            END;

        NEW.formula_2_2k =
            CASE
                WHEN f2 LIKE '%(%' THEN REGEXP_REPLACE(f2, '[\(\)]', '', 'g')
                ELSE NULL
            END;
    ELSE
        NEW.formula_2_1k = NULL;
        NEW.formula_2_2k = NULL;
    END IF;

    -- 7. Рассчитываем суммарную толщину для каждой формулы
    -- 7.1. Для formula_1_1k
    IF NEW.formula_1_1k IS NOT NULL THEN
        tokens = REGEXP_SPLIT_TO_ARRAY(
            REGEXP_REPLACE(NEW.formula_1_1k, '[^0-9-]', '', 'g'), '-');
        sum_1_1k = 0;
        FOR i IN 1..array_length(tokens, 1) LOOP
            IF i % 2 = 1 AND tokens[i] ~ '^[0-9]+$' THEN  -- нечётная позиция и цифра
                sum_1_1k = sum_1_1k + tokens[i]::NUMERIC;
            END IF;
        END LOOP;
        NEW.total_thickness_1_1k = sum_1_1k;
    ELSE
        NEW.total_thickness_1_1k = NULL;
    END IF;

    -- 7.2. Для formula_1_2k
    IF NEW.formula_1_2k IS NOT NULL THEN
        tokens = REGEXP_SPLIT_TO_ARRAY(
            REGEXP_REPLACE(NEW.formula_1_2k, '[^0-9-]', '', 'g'), '-');
        sum_1_2k = 0;
        FOR i IN 1..array_length(tokens, 1) LOOP
            IF i % 2 = 1 AND tokens[i] ~ '^[0-9]+$' THEN
                sum_1_2k = sum_1_2k + tokens[i]::NUMERIC;
            END IF;
        END LOOP;
        NEW.total_thickness_1_2k = sum_1_2k;
    ELSE
        NEW.total_thickness_1_2k = NULL;
    END IF;

    -- 7.3. Для formula_2_1k
    IF NEW.formula_2_1k IS NOT NULL THEN
        tokens = REGEXP_SPLIT_TO_ARRAY(
            REGEXP_REPLACE(NEW.formula_2_1k, '[^0-9-]', '', 'g'), '-');
        sum_2_1k = 0;
        FOR i IN 1..array_length(tokens, 1) LOOP
            IF i % 2 = 1 AND tokens[i] ~ '^[0-9]+$' THEN
                sum_2_1k = sum_2_1k + tokens[i]::NUMERIC;
            END IF;
        END LOOP;
        NEW.total_thickness_2_1k = sum_2_1k;
    ELSE
        NEW.total_thickness_2_1k = NULL;
    END IF;

    -- 7.4. Для formula_2_2k
    IF NEW.formula_2_2k IS NOT NULL THEN
        tokens = REGEXP_SPLIT_TO_ARRAY(
            REGEXP_REPLACE(NEW.formula_2_2k, '[^0-9-]', '', 'g'), '-');
        sum_2_2k = 0;
        FOR i IN 1..array_length(tokens, 1) LOOP
            IF i % 2 = 1 AND tokens[i] ~ '^[0-9]+$' THEN
                sum_2_2k = sum_2_2k + tokens[i]::NUMERIC;
            END IF;
        END LOOP;
        NEW.total_thickness_2_2k = sum_2_2k;
    ELSE
        NEW.total_thickness_2_2k = NULL;
    END IF;

    RETURN NEW;  -- обязательный возврат изменённой строки
END;
$function$;