SELECT
    CAST(_Document668._Posted as bit) AS 'Posted'
    ,CAST(_Document668._Marked as bit) AS 'DeleteMark'
    ,CAST(_Document668._Fld27346 as bit) AS 'ManagementAccounting'
    ,CONVERT(VARCHAR(MAX), _Document668_VT18528._Document668_IDRRef, 2) AS 'RouteSheetRef'
    ,_Document668._Number AS 'RouteSheetNumber'
    ,IIF(_Document668._Date_Time >=  DATEFROMPARTS(4001,1,1),CAST(DATEADD(YEAR, -2000, _Document668._Date_Time) as date), null) AS 'RouteSheetDate'
    ,CONVERT(VARCHAR(MAX), _Fld18535RRef, 2) AS 'RouteReff'
    ,CAST(_Document668_VT18528._Fld18530 as bit) AS 'IsDone'
    ,CONVERT(VARCHAR(MAX), _Fld18557_RRRef, 2) AS 'OrderReff'
    ,CONVERT(VARCHAR(MAX), _Fld18558RRef, 2) AS 'PivotRouteReff'
    ,CONVERT(VARCHAR(MAX), _Document668._Fld18468RRef, 2) AS 'TruckRef'
    ,_Fld18559 AS 'DistanceFact'
    ,CAST(_Fld18560 as bit) AS 'EnptyDistance'
    ,_Fld18564 AS 'DistancePlan'
    ,_Fld18565 AS'DistanceCorrection'
    ,_Fld18566 AS 'DistanceDeviation'
    ,_Fld26807 AS 'DistanceComment'
    ,CONVERT(VARCHAR(MAX), _Document668._Fld18498RRef, 2) AS 'RouteSheetDispetcherRef'
    ,IIF(Orders._Fld17716 >= DATEFROMPARTS(4001,1,1),DATEADD(YEAR, -2000, Orders._Fld17716), null) AS 'StartFact'
    ,IIF(Orders._Fld27200 >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, - 2000, Orders._Fld27200), null) AS 'EndDayFact'
    ,IIF(_Document668_VT18528._Fld18538 >= DATEFROMPARTS(4001,1,1),DATEADD(YEAR, -2000, _Document668_VT18528._Fld18538), null) AS 'StartFact_RShT'
    ,IIF(_Document668_VT18528._Fld18539 >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, - 2000, _Document668_VT18528._Fld18539), null) AS 'EndDayFact_RShT'
    ,IIF(Orders._Fld17682 >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, Orders._Fld17682), null) AS 'StartPlan'
    ,IIF(Orders._Fld17683 >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, - 2000, Orders._Fld17683), null) AS 'EndDayPlan'
    ,_Document668_VT18528._Fld18561 AS 'CargoCode'
    ,CONVERT(VARCHAR(MAX), _Document668_VT18616._Fld18629RRef, 2) AS 'PointUpLoaded'
    ,CONVERT(VARCHAR(MAX), _Document668_VT18616._Fld18630RRef, 2) AS 'PointUnLoaded'
    ,CONVERT(VARCHAR(MAX), _Document668_VT18616._Fld18618RRef, 2) AS 'CargoRef'
    ,SUM(_Document668_VT18616._Fld18619) AS 'CargoWeight'
    ,CAST(_Document668._Fld18522 as bit) AS 'RShIsClosed'
    ,CAST(_Document668._Fld18466 as bit) AS 'RShIsCalculated'
    ,MIN(IIF(_Document668_VT18616._Fld18631 >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Document668_VT18616._Fld18631), NULL)) AS 'DateUpLoaded'
    ,MAX(IIF(_Document668_VT18616._Fld18632 >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Document668_VT18616._Fld18632), NULL)) AS 'DateUnLoaded'
    ,_Document668_VT18528._LineNo18529 AS 'Line№'
    ,CAST(Orders._Marked as bit) AS 'DeleteMarkOrder'
    ,CAST(Orders._Posted AS bit) AS 'PostedOrder'
    ,CAST(Orders._Fld32970 as bit) AS 'TechOrder'
    ,CONVERT(VARCHAR(MAX), Orders._Fld17681_RRRef, 2) AS 'ClientReff'
    ,Statments.Statment AS 'OrderStatment'
    ,OperTypes.OperatType AS 'OperTypeOrder'
    FROM work.dbo._Document668_VT18528
    LEFT JOIN work.dbo._Document668 ON _Document668_VT18528._Document668_IDRRef = _Document668._IDRRef
    INNER JOIN  work.dbo._Document650 Orders ON _Document668_VT18528._Fld18557_RRRef = Orders._IDRRef
    INNER JOIN
    (SELECT
    *,
    CASE _Enum26798._EnumOrder
    WHEN 0 THEN 'Выгружено'
    WHEN 1 THEN 'Запланировано'
    WHEN 2 THEN 'Отказано клиентом'
    WHEN 3 THEN 'К исполнению'
    WHEN 4 THEN 'Загружено'
    WHEN 5 THEN 'Выполнено'
    WHEN 6 THEN 'Отказано'
    END AS 'Statment'
    FROM work.dbo._Enum26798) AS Statments
    ON Orders._Fld17685RRef = Statments._IDRRef
    LEFT JOIN (
    SELECT
    *,
    CASE _Enum1144._EnumOrder
    WHEN 0 THEN 'Перевозки собственным транспортом'
    WHEN 1 THEN 'Экспедирование'
    END AS 'OperatType'
    FROM work.dbo._Enum1144) as OperTypes
    ON Orders._Fld17702RRef = OperTypes._IDRRef
    -- Документ.уатПутевойЛист.Грузы:
    LEFT JOIN [work].dbo._Document668_VT18616 ON _Document668_VT18528._Document668_IDRRef = _Document668_VT18616._Document668_IDRRef AND _Document668_VT18528._Fld18561 = _Document668_VT18616._Fld18627
    WHERE
    CAST(_Document668._Posted as int) = 1
    AND CAST(_Document668._Marked as int) = 0
    AND CAST(_Document668._Fld27346 as int) = 1
    GROUP BY
    _Document668._Posted
    ,_Document668._Marked
    ,_Document668._Fld27346
    ,_Fld18535RRef
    ,_Fld18557_RRRef
    ,_Fld18558RRef
    ,_Document668_VT18528._Document668_IDRRef
    ,_Document668._Number
    ,_Fld18559
    ,_Fld18560
    ,_Fld18564
    ,_Fld18565
    ,_Fld18566
    ,_Fld26807
    ,_Document668._Fld18498RRef
    ,Orders._Fld17716
    ,Orders._Fld27200
    ,Orders._Fld17682
    ,Orders._Fld17683
    ,_Document668_VT18528._Fld18561
    ,_Document668_VT18528._Fld18539
    ,_Document668_VT18528._Fld18538
    ,_Document668._Fld18522
    ,_Document668._Fld18466
    ,_Document668._Fld18468RRef
    ,_Document668_VT18616._Fld18618RRef
    ,_Document668_VT18528._Fld18530
    ,_Document668_VT18528._LineNo18529
    ,_Document668._Date_Time
    ,_Document668_VT18616._Fld18629RRef
    ,_Document668_VT18616._Fld18630RRef
    ,Orders._Marked
    ,Orders._Posted
    ,Orders._Fld32970
    ,Orders._Fld17681_RRRef
    ,Statments.Statment
    ,OperTypes.OperatType