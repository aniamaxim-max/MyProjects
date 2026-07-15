-- exec pbi.GetRouteSheetIssues

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'GetRouteSheetIssues' AND SCHEMA_NAME(schema_id) = 'pbi')
    DROP PROCEDURE pbi.GetRouteSheetIssues;
GO

CREATE PROCEDURE pbi.GetRouteSheetIssues
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        rs.RouteSheetNumber,
        rs.RouteSheetDate,
        rs.TruckRef,
        rs.DriverRef,
        rs.DateRouteStart,
        rs.DateRouteEnd,
        t.RouteSheetRef,
        t.[LineNo],
        t.StartFact_RShT,
        t.EndFact_RShT,
        dt.LegalNum,
        dr.RouteName,
        COALESCE(e._Description, p._Description) AS DriverName
    INTO #base
    FROM pbi.vb_RouteSheet rs
    INNER JOIN pbi.vb_RouteSheetTask t
        ON t.RouteSheetRef = rs.RouteSheetRef
    INNER JOIN pbi.vb_DimTrucks dt
        ON dt.TruckReff = rs.TruckRef
        AND dt.Description1 = N'Тягачі'
    LEFT JOIN pbi.vb_DimRoute dr
        ON dr.RouteRef = t.RouteRef
    LEFT JOIN work.dbo._Reference208 e
        ON e._IDRRef = rs.DriverRef
    LEFT JOIN work.dbo._Reference254 p
        ON p._IDRRef = rs.DriverRef
    WHERE rs.RouteSheetDate >= DATEADD(MONTH, -4, CAST(GETDATE() AS DATE))
      AND rs.RouteSheetDate <= DATEADD(DAY, -5, CAST(GETDATE() AS DATE));

    CREATE INDEX IX_base_TruckRef ON #base(TruckRef)
        INCLUDE (RouteSheetRef, StartFact_RShT, EndFact_RShT);

    ----------------------------------------------------------------------
    -- 1. Тривалість > 20 днів
    ----------------------------------------------------------------------
    SELECT
        RouteSheetNumber     AS [№ ПЛ],
        LegalNum             AS [Держ номер авто],
        DriverName AS [Водій],
        FORMAT(RouteSheetDate, 'dd.MM.yyyy HH:mm') AS [Дата ПЛ],
        [LineNo]               AS [№ стрічки],
        RouteName            AS [Маршрут в стрічці завдання],
        FORMAT(StartFact_RShT, 'dd.MM.yyyy') AS [Дата початку],
        FORMAT(EndFact_RShT, 'dd.MM.yyyy') AS [Дата завершення],
        'Тривалість > 20 днів' AS [Причина]
    FROM #base
    WHERE StartFact_RShT IS NOT NULL
      AND EndFact_RShT IS NOT NULL
      AND DATEDIFF(DAY, StartFact_RShT, EndFact_RShT) > 20

    UNION ALL

    ----------------------------------------------------------------------
    -- 2. Тривалість мінусова
    ----------------------------------------------------------------------
    SELECT
        RouteSheetNumber,
        LegalNum,
        DriverName,
        FORMAT(RouteSheetDate, 'dd.MM.yyyy HH:mm'),
        [LineNo],
        RouteName,
        FORMAT(StartFact_RShT, 'dd.MM.yyyy'),
        FORMAT(EndFact_RShT, 'dd.MM.yyyy'),
        'Тривалість мінусова'
    FROM #base
    WHERE StartFact_RShT IS NOT NULL
      AND EndFact_RShT IS NOT NULL
      AND StartFact_RShT > EndFact_RShT

    UNION ALL

    ----------------------------------------------------------------------
    -- 3. Не вказано дату
    ----------------------------------------------------------------------
    SELECT
        RouteSheetNumber,
        LegalNum,
        DriverName,
        FORMAT(RouteSheetDate, 'dd.MM.yyyy HH:mm'),
        [LineNo],
        RouteName,
        FORMAT(StartFact_RShT, 'dd.MM.yyyy'),
        FORMAT(EndFact_RShT, 'dd.MM.yyyy'),
        'Не вказано дату'
    FROM #base
    WHERE StartFact_RShT IS NULL
       OR EndFact_RShT IS NULL

    UNION ALL

    ----------------------------------------------------------------------
    -- 4. Поза діапазоном ПЛ
    ----------------------------------------------------------------------
    SELECT
        RouteSheetNumber,
        LegalNum,
        DriverName,
        FORMAT(RouteSheetDate, 'dd.MM.yyyy HH:mm'),
        [LineNo],
        RouteName,
        FORMAT(StartFact_RShT, 'dd.MM.yyyy'),
        FORMAT(EndFact_RShT, 'dd.MM.yyyy'),
        'Поза діапазоном ПЛ'
    FROM #base
    WHERE (StartFact_RShT IS NOT NULL
           AND (CAST(StartFact_RShT AS DATE) < CAST(DateRouteStart AS DATE) OR CAST(StartFact_RShT AS DATE) > CAST(DateRouteEnd AS DATE)))
       OR (EndFact_RShT IS NOT NULL
           AND (CAST(EndFact_RShT AS DATE) < CAST(DateRouteStart AS DATE) OR CAST(EndFact_RShT AS DATE) > CAST(DateRouteEnd AS DATE)))

    UNION ALL

    ----------------------------------------------------------------------
    -- 5. Перекриття авто > 2 днів (self-JOIN #base, без подзапроса)
    ----------------------------------------------------------------------
    SELECT
        b1.RouteSheetNumber,
        b1.LegalNum,
        b1.DriverName,
        FORMAT(b1.RouteSheetDate, 'dd.MM.yyyy HH:mm'),
        b1.[LineNo],
        b1.RouteName,
        FORMAT(b1.StartFact_RShT, 'dd.MM.yyyy'),
        FORMAT(b1.EndFact_RShT, 'dd.MM.yyyy'),
        'Перекриття авто > 2 днів'
    FROM #base b1
    INNER JOIN #base b2
        ON b2.TruckRef = b1.TruckRef
        AND b2.RouteSheetRef <> b1.RouteSheetRef
        AND b2.StartFact_RShT IS NOT NULL
        AND b2.EndFact_RShT IS NOT NULL
        AND b1.StartFact_RShT IS NOT NULL
        AND b1.EndFact_RShT IS NOT NULL
        AND b2.StartFact_RShT < b1.EndFact_RShT
        AND b2.EndFact_RShT > b1.StartFact_RShT
        AND DATEDIFF(
                DAY,
                CASE WHEN b1.StartFact_RShT > b2.StartFact_RShT THEN b1.StartFact_RShT ELSE b2.StartFact_RShT END,
                CASE WHEN b1.EndFact_RShT < b2.EndFact_RShT THEN b1.EndFact_RShT ELSE b2.EndFact_RShT END
            ) >= 1
    ORDER BY [Причина], [Держ номер авто];

    DROP TABLE #base;
END
GO
