CREATE OR REPLACE FUNCTION public.parse_order_elements_full(p_formula text)
 RETURNS TABLE(ord integer, article text, element_type text, thickness integer)
 LANGUAGE sql
 IMMUTABLE
AS $function$
  WITH parts AS (
    SELECT
      row_number() OVER () AS ord,
      btrim(p) AS article
    FROM unnest(
      regexp_split_to_array(coalesce(p_formula,''), '[xх]')
    ) AS p
    WHERE btrim(p) <> ''
  )
  SELECT
    ord,
    article,
    CASE WHEN article ~* '^[HWНШ]' THEN 'frame' ELSE 'glass' END AS element_type,
    public.get_thickness(article) AS thickness
  FROM parts;
$function$;