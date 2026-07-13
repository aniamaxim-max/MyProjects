
--select * from pbi.v_TruckStatusDaily

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_TruckStatusDaily' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_TruckStatusDaily
GO

CREATE VIEW pbi.v_TruckStatusDaily AS
WITH TruckStatuses AS (
    SELECT 
        CONVERT(VARCHAR(MAX), ST._Fld26887_RRRef, 2) AS TruckRef,           -- Машина
        CONVERT(VARCHAR(MAX), ST._Fld26888_RRRef, 2) AS TrailerRef,         -- Причіп (якщо треба)
        CONVERT(VARCHAR(MAX), ST._Fld26884RRef, 2) AS CompanyRef,
        
        -- Дата простою (дата документа)
        IIF(ST._Date_Time >= DATEFROMPARTS(4001,1,1), 
            DATEADD(YEAR, -2000, ST._Date_Time), 
            ST._Date_Time) AS IdleDate,
        
        -- Період дії статусу
        CAST(IIF(ST._Fld26889 >= DATEFROMPARTS(4001,1,1), 
                 DATEADD(YEAR, -2000, ST._Fld26889), 
                 ST._Fld26889) AS DATE) AS IdleStart,
        
        CAST(IIF(ST._Fld26890 >= DATEFROMPARTS(4001,1,1), 
                 DATEADD(YEAR, -2000, ST._Fld26890), 
                 ST._Fld26890) AS DATE) AS IdleEnd,
        
        CONVERT(VARCHAR(MAX), ST._Fld26892RRef, 2) AS StatusRef,            -- Статус
        
        -- Для вибору найновішого документа
        ROW_NUMBER() OVER (PARTITION BY 
                            CONVERT(VARCHAR(MAX), ST._Fld26887_RRRef, 2),
                            CAST(IIF(ST._Fld26889 >= DATEFROMPARTS(4001,1,1), 
                                     DATEADD(YEAR, -2000, ST._Fld26889), 
                                     ST._Fld26889) AS DATE)
                          ORDER BY ST._Date_Time DESC) AS rn

    FROM _Document26883 ST
    WHERE ST._Fld26887_RRRef IS NOT NULL
      AND ST._Fld26889 IS NOT NULL
      AND ST._Fld26890 IS NOT NULL
),
DailyCalendar AS (
    SELECT CalDate 
    FROM pbi.v_Calendar
)
SELECT 
    c.CalDate,
    ts.TruckRef,
    ts.TrailerRef,
    ts.CompanyRef,
    ts.StatusRef,
    ts.IdleDate,
    ts.IdleStart,
    ts.IdleEnd
FROM DailyCalendar c
CROSS JOIN (
    SELECT DISTINCT TruckRef 
    FROM TruckStatuses
) t  -- всі машини, які коли-небудь мали статуси
INNER JOIN TruckStatuses ts 
    ON ts.TruckRef = t.TruckRef
   AND c.CalDate >= ts.IdleStart 
   AND c.CalDate <= ts.IdleEnd
   AND ts.rn = 1;        -- беремо тільки найновіший документ на день початку статусу