CREATE OR REPLACE FUNCTION public.split_marking_formula()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  cleaned_marking TEXT;
  f1 TEXT; f2 TEXT;
  parts_count INT;
  last_spacer TEXT;
  last_glass TEXT;
BEGIN
  -- 1. Нормализуем строку
  cleaned_marking = REGEXP_REPLACE(TRIM(NEW.marking), '\s{2,}', ' ');

  -- 2. Если строка пуста
  IF cleaned_marking = '' THEN
    NEW.formula_1 = NULL; NEW.formula_2 = NULL;
    NEW.formula_1_1k = NULL; NEW.formula_1_2k = NULL; NEW.formula_1_3k = NULL;
    NEW.formula_2_1k = NULL; NEW.formula_2_2k = NULL; NEW.formula_2_3k = NULL;
    RETURN NEW;
  END IF;

  -- 3. Если первый символ не цифра — считаем текстовым описанием
  IF SUBSTRING(cleaned_marking FOR 1) !~ '^[0-9]' THEN
    NEW.formula_1 = cleaned_marking;
    NEW.formula_2 = NULL;
    NEW.formula_1_1k = NULL; NEW.formula_1_2k = NULL; NEW.formula_1_3k = NULL;
    NEW.formula_2_1k = NULL; NEW.formula_2_2k = NULL; NEW.formula_2_3k = NULL;
    RETURN NEW;
  END IF;

  -- 4. Разделяем на formula_1 и formula_2
  f1 = split_part(cleaned_marking, ' ', 1);
  f2 = NULLIF(split_part(cleaned_marking, ' ', 2), '');

  NEW.formula_1 = f1;
  NEW.formula_2 = f2;

  -- ==========================================
  -- 5. ЛОГИКА ДЛЯ FORMULA 1
  -- ==========================================
  IF f1 LIKE '%(%' THEN
    -- Со скобками: извлекаем базовую часть и содержимое скобок
    NEW.formula_1_1k = SUBSTRING(f1 FROM '^(.*?)\(');
    NEW.formula_1_2k = REGEXP_REPLACE(f1, '[\(\)]', '', 'g');
    
    -- Расчёт 3K из 2K
    parts_count = array_length(REGEXP_SPLIT_TO_ARRAY(NEW.formula_1_2k, '-'), 1);
    IF parts_count >= 5 THEN
      last_spacer = split_part(NEW.formula_1_2k, '-', parts_count - 1);
      last_glass = split_part(NEW.formula_1_2k, '-', parts_count);
      NEW.formula_1_3k = NEW.formula_1_2k || '-' || last_spacer || '-' || last_glass;
    ELSE
      NEW.formula_1_3k = NULL;
    END IF;
  ELSE
    -- Без скобок: разбиваем по дефисам
    parts_count = array_length(REGEXP_SPLIT_TO_ARRAY(f1, '-'), 1);
    
    IF parts_count >= 7 THEN
      -- 7+ частей → считаем 3K (уже готовая формула)
      NEW.formula_1_1k = NULL;
      NEW.formula_1_2k = NULL;
      NEW.formula_1_3k = f1;
    ELSIF parts_count >= 5 THEN
      -- 5-6 частей → 2K
      NEW.formula_1_1k = NULL;
      NEW.formula_1_2k = f1;
      -- Формируем 3K
      last_spacer = split_part(f1, '-', parts_count - 1);
      last_glass = split_part(f1, '-', parts_count);
      NEW.formula_1_3k = f1 || '-' || last_spacer || '-' || last_glass;
    ELSE
      -- 3-4 части → 1K
      NEW.formula_1_1k = f1;
      NEW.formula_1_2k = NULL;
      NEW.formula_1_3k = NULL;
    END IF;
  END IF;

  -- ==========================================
  -- 6. ЛОГИКА ДЛЯ FORMULA 2
  -- ==========================================
  IF f2 IS NOT NULL THEN
    IF f2 LIKE '%(%' THEN
      NEW.formula_2_1k = SUBSTRING(f2 FROM '^(.*?)\(');
      NEW.formula_2_2k = REGEXP_REPLACE(f2, '[\(\)]', '', 'g');
      
      parts_count = array_length(REGEXP_SPLIT_TO_ARRAY(NEW.formula_2_2k, '-'), 1);
      IF parts_count >= 5 THEN
        last_spacer = split_part(NEW.formula_2_2k, '-', parts_count - 1);
        last_glass = split_part(NEW.formula_2_2k, '-', parts_count);
        NEW.formula_2_3k = NEW.formula_2_2k || '-' || last_spacer || '-' || last_glass;
      ELSE
        NEW.formula_2_3k = NULL;
      END IF;
    ELSE
      parts_count = array_length(REGEXP_SPLIT_TO_ARRAY(f2, '-'), 1);
      
      IF parts_count >= 7 THEN
        NEW.formula_2_1k = NULL;
        NEW.formula_2_2k = NULL;
        NEW.formula_2_3k = f2;
      ELSIF parts_count >= 5 THEN
        NEW.formula_2_1k = NULL;
        NEW.formula_2_2k = f2;
        last_spacer = split_part(f2, '-', parts_count - 1);
        last_glass = split_part(f2, '-', parts_count);
        NEW.formula_2_3k = f2 || '-' || last_spacer || '-' || last_glass;
      ELSE
        NEW.formula_2_1k = f2;
        NEW.formula_2_2k = NULL;
        NEW.formula_2_3k = NULL;
      END IF;
    END IF;
  ELSE
    NEW.formula_2_1k = NULL;
    NEW.formula_2_2k = NULL;
    NEW.formula_2_3k = NULL;
  END IF;

  RETURN NEW;
END;
$function$;