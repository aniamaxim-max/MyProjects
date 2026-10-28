;WITH CriteriaLatest AS
(
    SELECT _Fld34328RRef, _Fld34329RRef
    FROM
    (
        SELECT
            _Fld34328RRef,
            _Fld34329RRef,
            ROW_NUMBER() OVER (PARTITION BY _Fld34328RRef ORDER BY _Period DESC) AS rn
        FROM work.dbo._InfoRg34327
        WHERE _Period < DATEADD(YEAR, 2000, GETDATE())
    ) AS t
    WHERE t.rn = 1
),
CriteriaNodes AS
(
    SELECT DISTINCT _Fld34329RRef AS _IDRRef
    FROM CriteriaLatest
),
Tree AS
(
    SELECT
        r._IDRRef,
        r._ParentIDRRef,
        r._Description,
        1 AS [Level],
        r._IDRRef AS BaseRef
    FROM work.dbo._Reference34326 AS r
    INNER JOIN CriteriaNodes AS n ON n._IDRRef = r._IDRRef
    UNION ALL
    SELECT
        p._IDRRef,
        p._ParentIDRRef,
        p._Description,
        t.[Level] + 1 AS [Level],
        t.BaseRef
    FROM Tree AS t
    INNER JOIN work.dbo._Reference34326 AS p ON p._IDRRef = t._ParentIDRRef
),
TreeOrdered AS
(
    SELECT
        *,
        MAX([Level]) OVER (PARTITION BY BaseRef) - [Level] + 1 AS ReversedLevel
    FROM Tree
),
DimCriteria AS
(
    SELECT
        BaseRef AS _IDRRef,
        MAX(CASE WHEN ReversedLevel = 1 THEN _Description END) AS L1_Description,
        MAX(CASE WHEN ReversedLevel = 2 THEN _Description END) AS L2_Description,
        MAX(CASE WHEN ReversedLevel = 3 THEN _Description END) AS L3_Description,
        MAX(CASE WHEN ReversedLevel = 4 THEN _Description END) AS L4_Description
    FROM TreeOrdered
    GROUP BY BaseRef
),
Criteria AS
(
    SELECT
        cl._Fld34328RRef,
        COALESCE(dc.L4_Description, dc.L3_Description, dc.L2_Description, dc.L1_Description) AS Description4
    FROM CriteriaLatest AS cl
    LEFT JOIN DimCriteria AS dc ON dc._IDRRef = cl._Fld34329RRef
),
PlanWeights AS
(
    SELECT
        _Document650_IDRRef,
        SUM(_Fld17821) AS PlanWeight,
        CAST(MIN(CAST(_Fld34307 AS INT)) AS BIT) AS ExactWeight
    FROM work.dbo._Document650_VT17818
    GROUP BY _Document650_IDRRef
),
VehicleTypes AS
(
    SELECT VehicleRef, VehicleType
    FROM
    (
        SELECT
            r._Fld23489RRef AS VehicleRef,
            vt._Description AS VehicleType,
            ROW_NUMBER() OVER (PARTITION BY r._Fld23489RRef ORDER BY r._Period DESC) AS rn
        FROM work.dbo._InfoRg23488 AS r
        LEFT JOIN work.dbo._Reference279 AS vt ON vt._IDRRef = r._Fld23491RRef
    ) AS t
    WHERE t.rn = 1
)
SELECT
    _Document650._Number AS 'Order'
    ,CONVERT(VARCHAR(32), _Document650._IDRRef, 2) AS 'OrderRef'
    ,IIF(_Document650._Date_Time >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000,_Document650._Date_Time), null) AS 'OrderDate'
    ,CAST(IIF(_Document650._Date_Time >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000,_Document650._Date_Time), null) as date) AS 'OrderPrefDate'
    ,CAST(_Document650._Marked as bit) AS 'DeleteMark'
    ,CAST(_Document650._Posted AS bit) AS 'Posted'
    ,CONVERT(VARCHAR(32), _Document650._Fld17679RRef, 2) AS 'CompanyReff'
    ,CONVERT(VARCHAR(32), _Document650._Fld17681_RRRef, 2) AS 'ClientReff'
    ,Statments.Statment AS 'OrderStatment'
    ,CONVERT(VARCHAR(32), _Document650._Fld17686RRef, 2) AS 'ManagerReff'
    ,CONVERT(VARCHAR(32), _Document650._Fld17720RRef, 2) AS 'DispetcherReff'
    ,IIF(_Document650._Fld17682 >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000,_Document650._Fld17682), null) AS 'StartPlan'
    ,IIF(_Document650._Fld17683 >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000,_Document650._Fld17683), null) AS 'EndPlan'
    ,IIF(_Document650._Fld17716 >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000,_Document650._Fld17716), null) AS 'StartFact'
    ,IIF(_Document650._Fld27200 >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000,_Document650._Fld27200), null) AS 'EndFact'
    ,CONVERT(VARCHAR(32), _Document650._Fld17702RRef, 2) AS 'OperTypeRef'
    ,CAST(_Document650._Fld17698_RTRef as int) AS TruckTableNum
    ,CONVERT(VARCHAR(32), _Document650._Fld17698_RRRef, 2) AS 'TruckReff'
    ,_Document650._Fld17701 AS СуммаУкр
    ,CONVERT(bit, _Document650._Fld26926) AS 'Ready'
    ,_Document650._Fld17692 AS 'IncomeSum'
    ,CONVERT(VARCHAR(32), _Document650._Fld17693RRef, 2) AS 'IncomeCurrencyReff'
    ,CONVERT(VARCHAR(32), _Document650._Fld17700RRef, 2) AS 'RouteReff'
    ,CONVERT(VARCHAR(32), _Document650._Fld17704_RRRef, 2) AS 'TrailerReff'
    ,TrailerNames._Fld23607 AS 'TrailerName'
    ,VehicleTypes.VehicleType AS 'TrailerType'
    ,CONVERT(VARCHAR(32), _Document650._Fld17719_RRRef, 2) AS 'Сontainer'
    ,ContainerNames._Description AS 'СontainerName'
    ,ContainerTypes._Description AS 'СontainerType'
    ,CASE
    WHEN VehicleTypes.VehicleType IN ('Платформа', 'Спеціалізований напівпричіп контейнеровоз') THEN COALESCE(ContainerTypes._Description, VehicleTypes.VehicleType)
    ELSE VehicleTypes.VehicleType
    END AS 'OrderType'
    ,_Document650._Fld26927 AS 'WeightFact'
    ,_Document650._Fld27198 AS 'DevWeight'
    ,_Document650._Fld17768 AS 'MileageWOCargo'
    ,_Document650._Fld17770 AS 'MileageWCargo'
    ,_Document650._Fld32715 AS 'MileagePlan'
    ,_Document650._Fld32716 AS 'MileageFact'
    ,_Document650._Fld17774 AS 'MileageDeviation'
    ,CAST(_Document650._Fld32970 as bit) AS 'TechOrder'
    ,DirOrderType.OrderDirType
    ,CAST(_Fld17708 as bit) AS 'Expedition'
    ,CAST(_Document650._Fld17757 as bit) AS 'NoDeviationsOverTime'
    ,CAST(_Document650._Fld17758 as bit) AS 'NoDeviationsOverExp'
    ,CAST(_Document650._Fld17759 as bit) AS 'NoDeviationsOverMileage'
    ,Explanation._Description AS 'ExplanationOverTime'
    ,Explanation._Description AS 'ExplanationOverExp'
    ,Explanation._Description AS 'ExplanationOverMileage'
    ,CAST(_Document650._Fld17763 as bit) AS 'DocsSubmittedOnTime'
    ,CAST(_Document650._Fld17764 as bit) AS 'NoCustomerComplaints'
    ,CAST(_Document650._Fld17765 as bit) AS 'CostsProcessed'
    ,CAST(_Document650._Fld17766 as bit) AS 'QualityProcessed'
    ,CAST(_Document650._Fld34631 as bit) AS 'AddLoad'
    ,_Document650._Fld27424 AS 'ReasonByMileage'
    ,_Document650._Fld27425 AS 'ReasonByTime'
    ,_Document650._Fld27426 AS 'ReasonByExp'
    ,_Document650._Fld32210 AS 'AdditionalOnQuality'
    ,_Document650._Fld34309 AS 'MaxPlanWeight'
    ,PlanWeight.PlanWeight
    ,PlanWeight.ExactWeight
    ,ot.TripNo
    ,ot.TripType
    ,ot.TripStart
    ,ot.TripEnd
FROM work.dbo._Document650
INNER JOIN
(
    SELECT
        _IDRRef,
        CASE _Enum26798._EnumOrder
        WHEN 0 THEN 'Выгружено'
        WHEN 1 THEN 'Запланировано'
        WHEN 2 THEN 'Отказано клиентом'
        WHEN 3 THEN 'К исполнению'
        WHEN 4 THEN 'Загружено'
        WHEN 5 THEN 'Выполнено'
        WHEN 6 THEN 'Отказано'
        WHEN 7 THEN 'В работе'
        WHEN 8 THEN 'Создан ПЛ'
        WHEN 9 THEN 'Справка-счет'
        WHEN 10 THEN 'Справка-счет (прикреплен)'
        WHEN 11 THEN 'Справка-счет (отправлен)'
        WHEN 12 THEN 'Прикреплено CMR/ТТН'
        WHEN 13 THEN 'Выписан счет'
        WHEN 14 THEN 'Счет утвержден'
        WHEN 15 THEN 'Отправлено'
        WHEN 16 THEN 'Закрыт'
        WHEN 17 THEN 'Оплачено'
        WHEN 18 THEN 'Создан'
        WHEN 19 THEN 'Запланировано'
        WHEN 20 THEN 'Справка-счет не нужна'
        END AS 'Statment'
    FROM work.dbo._Enum26798
) AS Statments
    ON _Document650._Fld17685RRef = Statments._IDRRef
LEFT JOIN work.dbo._Reference289 AS ContainerNames ON _Document650._Fld17719_RRRef = ContainerNames._IDRRef
LEFT JOIN work.dbo._Reference289 AS ContainerTypes ON ContainerNames._ParentIDRRef = ContainerTypes._IDRRef
LEFT JOIN work.dbo._InfoRg23603 AS TrailerNames ON _Document650._Fld17704_RRRef = TrailerNames._Fld23604RRef
LEFT JOIN VehicleTypes AS VehicleTypes ON VehicleTypes.VehicleRef = _Document650._Fld17704_RRRef
LEFT JOIN Criteria AS Criteria ON Criteria._Fld34328RRef = _Document650._Fld17704_RRRef
LEFT JOIN
(
    SELECT
        _IDRRef,
        CASE _EnumOrder
        WHEN 0 then 'На экспорт'
        WHEN 1 then 'На импорт'
        WHEN 2 then 'Внутренний Украина'
        WHEN 3 then 'Внутренний Европа'
        END AS 'OrderDirType'
    FROM work.dbo._Enum1191
) AS DirOrderType
    ON _Document650._Fld17687RRef = DirOrderType._IDRRef
LEFT JOIN work.dbo._Reference331 AS Explanation ON _Document650._Fld17760RRef = Explanation._IDRRef
LEFT JOIN PlanWeights AS PlanWeight ON PlanWeight._Document650_IDRRef = _Document650._IDRRef
LEFT JOIN pbi.OrderTrip AS ot ON ot.OrderRef = CONVERT(VARCHAR(32), _Document650._IDRRef, 2)
