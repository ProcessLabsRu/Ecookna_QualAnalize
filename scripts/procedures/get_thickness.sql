CREATE OR REPLACE FUNCTION public.get_thickness(p text)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT COALESCE( (regexp_match(coalesce(p,''), '\d+'))[1]::int, 0 );
$function$;