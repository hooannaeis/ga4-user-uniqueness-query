DECLARE
  event_param_query DEFAULT "SELECT CONCAT('ep.', ep.key) event_params_key, CAST(ep.value.int_value AS string), CAST(ep.value.float_value AS string), CAST( ep.value.double_value AS string)) event_params_value,  COUNT(DISTINCT user_pseudo_id) distinct_user_count, COUNT(*) AS distinct_value_count, RANK() OVER (ORDER BY COUNT(*) DESC) AS rank_value_count FROM `{{project-id}}.{{dataset_id}}.events_*` LEFT JOIN UNNEST(event_params) ep WHERE _table_suffix >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)) GROUP BY all UNION ALL ";
DECLARE
  user_param_query DEFAULT "SELECT CONCAT('up.', up.key) event_params_key, COALESCE(up.value.string_value, CAST(up.value.int_value AS string), CAST(up.value.float_value AS string), CAST( up.value.double_value AS string)) event_params_value,  COUNT(DISTINCT user_pseudo_id) distinct_user_count, COUNT(*) AS distinct_value_count, RANK() OVER (ORDER BY COUNT(*) DESC) AS rank_value_count FROM `{{project-id}}.{{dataset_id}}.events_*` LEFT JOIN UNNEST(user_properties) up WHERE _table_suffix >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)) GROUP BY all UNION ALL ";
DECLARE
  full_query STRING DEFAULT CONCAT(event_param_query, user_param_query);
DECLARE
  cols ARRAY < STRING >;
DECLARE
  i INT64 DEFAULT 0;
  -- get all the field_names from the GA4 export table
SET
  cols = (
  SELECT
    ARRAY_AGG(DISTINCT field_path) -- field_path is for example device.category, with column_name being device
  FROM
    `{{project-id}}.{{dataset_id}}.INFORMATION_SCHEMA.COLUMN_FIELD_PATHS`
  WHERE
    table_name LIKE 'events_20%'
    AND NOT REGEXP_CONTAINS(data_type, r"(ARRAY|STRUCT)") -- we dont want ARRAYs because they have to be unnested before accesssing. We dont want STRUCTs because we just want the specfific paths in the STRUCT
    AND column_name NOT IN (
      -- we exclude these three because they will be handled separately (because of them having values that can be customised by the user and are not filled by GA4 itself)
      'event_params',
      'user_properties',
      'items') );
  -- go through each field_name and create a query that will get the distinct values for that field_name
WHILE
  i < ARRAY_LENGTH (cols) DO
SET
  full_query = CONCAT ( full_query, "SELECT '", cols[
  OFFSET
    (i)], "' AS event_params_key, CAST(", cols[
  OFFSET
    (i)]," as string) as event_params_value,  COUNT(DISTINCT user_pseudo_id) distinct_user_count, COUNT(*) AS distinct_value_count, RANK() OVER (ORDER BY COUNT(*) DESC) AS rank_value_count FROM `{{project-id}}.{{dataset_id}}.events_*` WHERE _table_suffix >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)) group by all" );
IF
  i < ARRAY_LENGTH (cols) - 1 THEN
SET
  full_query = CONCAT (full_query, " UNION ALL ");
END IF
  ;
SET
  i = i + 1;
END WHILE
  ;
  -- execute the actual query
EXECUTE IMMEDIATE
  full_query
