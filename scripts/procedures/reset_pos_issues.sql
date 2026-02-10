CREATE OR REPLACE FUNCTION public.reset_pos_issues(p_pos_id bigint)
 RETURNS void
 LANGUAGE sql
AS $function$
  DELETE FROM public.qual_analize_pos_issues WHERE pos_id = p_pos_id;
$function$;