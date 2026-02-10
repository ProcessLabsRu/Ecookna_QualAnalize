CREATE OR REPLACE FUNCTION public.parse_slip_formula(p_formula text)
 RETURNS integer[]
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT CASE
    WHEN p_formula IS NULL OR btrim(p_formula) = '' THEN NULL
    ELSE (
      SELECT array_agg(public.get_thickness(part) ORDER BY ord)
      FROM unnest(string_to_array(p_formula, '-')) WITH ORDINALITY AS t(part, ord)
    )
  END;
$function$;