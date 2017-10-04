-- File: fs_forecast.sql
-- Description: OEM Filesystem Forecast
-- Author: Raul Ibanez (raul @ dbajunior.com)
 
WITH rl AS (
  SELECT
--     G.COMPOSITE_TARGET_NAME,
--   CASE G.COMPOSITE_TARGET_NAME
--      WHEN 'prod_group' THEN '80'
--      WHEN 'nonprod_group' THEN '90'
--      ELSE '90'
--   END THRESHOLD,
     T.TARGET_NAME,
     M1.KEY_VALUE,
     REGR_SLOPE(M1.VALUE_AVERAGE - M2.VALUE_AVERAGE,
       ((M1.ROLLUP_TIMESTAMP - to_date('1970-01-01 00:00:00','YYYY-MM-DD HH24:MI:SS')) * 86400)) SLOPE,
     REGR_INTERCEPT(M1.VALUE_AVERAGE - M2.VALUE_AVERAGE,
       ((M1.ROLLUP_TIMESTAMP - to_date('1970-01-01 00:00:00','YYYY-MM-DD HH24:MI:SS')) * 86400)) YINTERCEPT,
     M1.METRIC_GUID,
     M1.TARGET_GUID,
     (100-C.VALUE) CURRENT_PERC
  FROM
    MGMT_METRICS_1DAY M1,
    MGMT_METRICS_1DAY M2,
    MGMT_TARGETS T,
--    MGMT$GROUP_FLAT_MEMBERSHIPS G,
    MGMT_CURRENT_METRICS C
  WHERE
    -- Metric 162045AD9191652427CAC47D8BA40671 => Filesystem Size (MB) / Collected every week
    -- Metric E8838C71E687BF0A9E02FFACC0C9AC80 => Available (MB) / Collected every week
    M1.METRIC_GUID = HEXTORAW('162045AD9191652427CAC47D8BA40671') AND
    M2.METRIC_GUID = HEXTORAW('E8838C71E687BF0A9E02FFACC0C9AC80') AND
    -- Metric 6E65075DA52ACA744B4B8C3FCB018289 => Filesystem Space Available (%)
    C.METRIC_GUID = HEXTORAW('6E65075DA52ACA744B4B8C3FCB018289') AND
    M1.ROLLUP_TIMESTAMP = M2.ROLLUP_TIMESTAMP AND
    M1.KEY_VALUE = C.KEY_VALUE AND
    M2.KEY_VALUE = C.KEY_VALUE AND
    M1.ROLLUP_TIMESTAMP >= SYSDATE-60 AND
    M2.ROLLUP_TIMESTAMP >= SYSDATE-60 AND
    M1.TARGET_GUID = T.TARGET_GUID AND
    M2.TARGET_GUID = T.TARGET_GUID AND
    T.TARGET_GUID = C.TARGET_GUID AND
--    G.MEMBER_TARGET_GUID = M1.TARGET_GUID AND
--    G.MEMBER_TARGET_GUID = M2.TARGET_GUID AND
--    G.COMPOSITE_TARGET_NAME = 'prod_group' AND -- Filter any OEM Group
--    G.COMPOSITE_TARGET_TYPE = 'composite'
  GROUP BY
--    G.COMPOSITE_TARGET_NAME,
    T.TARGET_NAME, M1.KEY_VALUE, M1.METRIC_GUID, M1.TARGET_GUID, C.VALUE
)
SELECT
  TARGET_NAME,
  KEY_VALUE,
  THRESHOLD "THRESHOLD %",
  -- SLOPE,
  -- YINTERCEPT,
  ROUND(CURRENT_PERC,2) "CURR%",
  ROUND(((((((SYSDATE+31) - to_date('1970-01-01 00:00:00','YYYY-MM-DD HH24:MI:SS')) * 86400) * SLOPE + YINTERCEPT)* CURRENT_PERC) /
   ((((SYSDATE) - to_date('1970-01-01 00:00:00','YYYY-MM-DD HH24:MI:SS')) * 86400) * SLOPE + YINTERCEPT)),2) "NEXT1M%",
  ROUND(((((((SYSDATE+138) - to_date('1970-01-01 00:00:00','YYYY-MM-DD HH24:MI:SS')) * 86400) * SLOPE + YINTERCEPT)* CURRENT_PERC) /
   ((((SYSDATE) - to_date('1970-01-01 00:00:00','YYYY-MM-DD HH24:MI:SS')) * 86400) * SLOPE + YINTERCEPT)),2) "NEXT6M%",
  ROUND(((((((SYSDATE+365) - to_date('1970-01-01 00:00:00','YYYY-MM-DD HH24:MI:SS')) * 86400) * SLOPE + YINTERCEPT)* CURRENT_PERC) /
   ((((SYSDATE) - to_date('1970-01-01 00:00:00','YYYY-MM-DD HH24:MI:SS')) * 86400) * SLOPE + YINTERCEPT)),2) "NEXT12M%",
  ROUND((((SYSDATE) - to_date('1970-01-01 00:00:00','YYYY-MM-DD HH24:MI:SS')) * 86400) * SLOPE + YINTERCEPT) "CURR(MB)",
  ROUND((((SYSDATE+31) - to_date('1970-01-01 00:00:00','YYYY-MM-DD HH24:MI:SS')) * 86400) * SLOPE + YINTERCEPT) "NEXT1M(MB)",
  ROUND((((SYSDATE+138) - to_date('1970-01-01 00:00:00','YYYY-MM-DD HH24:MI:SS')) * 86400) * SLOPE + YINTERCEPT) "NEXT6M(MB)",
  ROUND((((SYSDATE+365) - to_date('1970-01-01 00:00:00','YYYY-MM-DD HH24:MI:SS')) * 86400) * SLOPE + YINTERCEPT) "NEXT12M(MB)",
  '+' || TO_CHAR(ROUND(((100*((((SYSDATE+365) - to_date('1970-01-01 00:00:00','YYYY-MM-DD HH24:MI:SS')) * 86400) * SLOPE + YINTERCEPT)/(THRESHOLD-10))-
  (100*((((SYSDATE) - to_date('1970-01-01 00:00:00','YYYY-MM-DD HH24:MI:SS')) * 86400) * SLOPE + YINTERCEPT)/CURRENT_PERC))/1024))||'GB' "REQ 12M"
FROM rl
WHERE
  SLOPE > 0 AND
  ROUND(((((((SYSDATE+365) - to_date('1970-01-01 00:00:00','YYYY-MM-DD HH24:MI:SS')) * 86400) * SLOPE + YINTERCEPT)* CURRENT_PERC) /
   ((((SYSDATE) - to_date('1970-01-01 00:00:00','YYYY-MM-DD HH24:MI:SS')) * 86400) * SLOPE + YINTERCEPT)),2) > THRESHOLD
ORDER BY
  ROUND(((100*((((SYSDATE+365) - to_date('1970-01-01 00:00:00','YYYY-MM-DD HH24:MI:SS')) * 86400) * SLOPE + YINTERCEPT)/(THRESHOLD-10))-
  (100*((((SYSDATE) - to_date('1970-01-01 00:00:00','YYYY-MM-DD HH24:MI:SS')) * 86400) * SLOPE + YINTERCEPT)/CURRENT_PERC))/1024) DESC;