 /*
 * GA4 distinct values for each dimension
 *
 * Copyright 2026, Hannes Kuhl
 */
DECLARE
  event_param_query DEFAULT "SELECT CONCAT('ep.', ep.key) event_params_key, coalesce(CAST(ep.value.string_value AS string), CAST(ep.value.int_value AS string), CAST(ep.value.float_value AS string), CAST( ep.value.double_value AS string)) event_params_value,  COUNT(DISTINCT user_pseudo_id) distinct_user_count, COUNT(*) AS distinct_value_count, RANK() OVER (ORDER BY COUNT(*) DESC) AS rank_value_count FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` LEFT JOIN UNNEST(event_params) ep WHERE _table_suffix >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)) GROUP BY all UNION ALL ";
DECLARE
  user_param_query DEFAULT "SELECT CONCAT('up.', up.key) event_params_key, COALESCE(CAST(up.value.string_value AS string), CAST(up.value.int_value AS string), CAST(up.value.float_value AS string), CAST( up.value.double_value AS string)) event_params_value,  COUNT(DISTINCT user_pseudo_id) distinct_user_count, COUNT(*) AS distinct_value_count, RANK() OVER (ORDER BY COUNT(*) DESC) AS rank_value_count FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` LEFT JOIN UNNEST(user_properties) up WHERE _table_suffix >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)) GROUP BY all UNION ALL ";
DECLARE
  item_param_query DEFAULT "SELECT CONCAT('item_param.', item_param.key) event_params_key, COALESCE(CAST(item_param.value.string_value AS string), CAST(item_param.value.int_value AS string), CAST(item_param.value.float_value AS string), CAST( item_param.value.double_value AS string)) event_params_value, COUNT(DISTINCT user_pseudo_id) distinct_user_count, COUNT(*) AS distinct_value_count, RANK() OVER (ORDER BY COUNT(*) DESC) AS rank_value_count FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` LEFT JOIN UNNEST(items) it, UNNEST(it.item_params) item_param WHERE _table_suffix >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)) GROUP BY ALL UNION ALL ";
DECLARE
  full_query STRING DEFAULT CONCAT(event_param_query, user_param_query, item_param_query);
DECLARE
  cols ARRAY < STRING >;
DECLARE
  i INT64 DEFAULT 0;
DECLARE
  item_cols ARRAY < STRING >;
DECLARE
  ii INT64 DEFAULT 0;
  -- get all the field_names from the GA4 export table
  -- except the fields that are arrays because those need a different treatment
SET
  cols = (
  SELECT
    ARRAY_AGG(DISTINCT field_path) -- field_path is for example device.category, with column_name being device
  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.INFORMATION_SCHEMA.COLUMN_FIELD_PATHS`
  WHERE
    table_name LIKE 'events_20%'
    AND NOT REGEXP_CONTAINS(data_type, r"(ARRAY|STRUCT)") -- we dont want ARRAYs because they have to be unnested before accesssing. We dont want STRUCTs because we just want the specfific paths in the STRUCT
    -- we exclude these three because they will be handled separately (because of them having values that can be customised by the user and are not filled by GA4 itself)
    AND NOT REGEXP_CONTAINS(field_path, r"event_params|user_properties|items") );
  -- go through each field_name and create a query that will get the distinct values for that field_name
WHILE
  i < ARRAY_LENGTH (cols) DO
SET
  full_query = CONCAT ( full_query, "SELECT '", cols[
  OFFSET
    (i)], "' AS event_params_key, CAST(", cols[
  OFFSET
    (i)]," as string) as event_params_value,  COUNT(DISTINCT user_pseudo_id) distinct_user_count, COUNT(*) AS distinct_value_count, RANK() OVER (ORDER BY COUNT(*) DESC) AS rank_value_count FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` WHERE _table_suffix >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)) group by all" );
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
  -- prefix the current query with a union all
SET
  full_query = CONCAT (full_query, " UNION ALL ");
  -- iterate over all fields in the items array
SET
  item_cols = (
  SELECT
    ARRAY_AGG(DISTINCT field_path) -- field_path is for example device.category, with column_name being device
  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.INFORMATION_SCHEMA.COLUMN_FIELD_PATHS`
  WHERE
    table_name LIKE 'events_20%'
    -- we exclude these three because they will be handled separately (because of them having values that can be customised by the user and are not filled by GA4 itself)
    AND REGEXP_CONTAINS(field_path, r"items.")
    AND NOT REGEXP_CONTAINS(field_path, r"items.item_params") );
  -- go through each field_name and create a query that will get the distinct values for that field_name
WHILE
  ii < ARRAY_LENGTH (item_cols) DO
SET
  full_query = CONCAT ( full_query, "SELECT '", item_cols[
  OFFSET
    (ii)], "' AS event_params_key, CAST(", item_cols[
  OFFSET
    (ii)]," as string) as event_params_value,  COUNT(DISTINCT user_pseudo_id) distinct_user_count, COUNT(*) AS distinct_value_count, RANK() OVER (ORDER BY COUNT(*) DESC) AS rank_value_count FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, unnest(items) items WHERE _table_suffix >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)) group by all" );
IF
  ii < ARRAY_LENGTH (item_cols) - 1 THEN
SET
  full_query = CONCAT (full_query, " UNION ALL ");
END IF
  ;
SET
  ii = ii + 1;
END WHILE
  ;
  -- execute the actual query
EXECUTE IMMEDIATE
  full_query