CREATE OR REPLACE FUNCTION public.trg_qual_checks_after()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- чистим прошлые нарушения
  PERFORM public.reset_pos_issues(NEW.id);

  -- проверка аргона
  PERFORM public.check_argon(NEW.id);
  PERFORM public.check_missing_glass(NEW.id);
  PERFORM public.check_slip(NEW.id);
  PERFORM public.check_slip_tempered(NEW.id);
  PERFORM public.recalc_overall(NEW.id);


  -- тут позже добавим: check_slip_structure, check_missing_glass, check_layout_rules...

  RETURN NEW;
END;
$function$;