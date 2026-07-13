-- SELECT * from pbi.v_DimOrders 
-- SELECT * from pbi.vb_DimOrders 


IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_DimOrders' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_DimOrders
GO

Create view pbi.v_DimOrders AS
/*WITH cte AS
    (
    SELECT r._IDRRef, r._ParentIDRRef, r._Description, 1 AS [Level], r._IDRRef As BaseRef
    FROM _Reference34326 r
    UNION ALL
    SELECT p._IDRRef, p._ParentIDRRef, p._Description, c.[Level] + 1 AS [Level], c.BaseRef
    FROM _Reference34326 p
    INNER JOIN cte c ON c._ParentIDRRef = p._IDRRef
    ),
    cte_Ordered AS (
    SELECT *, (SELECT Max(C2.[Level]) FROM cte C2 WHERE C1.BaseRef = C2.BaseRef) - C1.[Level] + 1 AS ReversedLevel
    FROM cte C1
    ),
    cte_DimCriteria AS (
    SELECT
    R._IDRRef,
    R._Description,
    L1._Description AS L1_Description,
    COALESCE(L2._Description, L1._Description) AS L2_Description,
    COALESCE(L3._Description, L2._Description, L1._Description) AS L3_Description,
    COALESCE(L4._Description, L3._Description, L2._Description, L1._Description) AS L4_Description
    FROM _Reference34326 R
    LEFT JOIN cte_Ordered L1 ON R._IDRRef = L1.BaseRef AND L1.ReversedLevel = 1
    LEFT JOIN cte_Ordered L2 ON R._IDRRef = L2.BaseRef AND L2.ReversedLevel = 2
    LEFT JOIN cte_Ordered L3 ON R._IDRRef = L3.BaseRef AND L3.ReversedLevel = 3
    LEFT JOIN cte_Ordered L4 ON R._IDRRef = L4.BaseRef AND L4.ReversedLevel = 4
    )*/
    SELECT
    _Document650._Number AS 'Order'
    ,CONVERT(VARCHAR(MAX), _Document650._IDRRef, 2) AS 'OrderRef'
    ,IIF(_Document650._Date_Time >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000,_Document650._Date_Time), null) AS 'OrderDate'
    ,CAST(IIF(_Document650._Date_Time >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000,_Document650._Date_Time), null) as date) AS 'OrderPrefDate'
    ,CAST(_Document650._Marked as bit) AS 'DeleteMark'
    ,CAST(_Document650._Posted AS bit) AS 'Posted'
    --,CONVERT(VARCHAR(MAX), _Document650._Fld17679RRef, 2) AS 'CompanyReff'
    ,CONVERT(VARCHAR(MAX), _Document650._Fld17681_RRRef, 2) AS 'ClientReff'
    ,Statments.Statment AS 'OrderStatment'
    --,Statments.UsePlan
    ,CONVERT(VARCHAR(MAX), _Document650._Fld17686RRef, 2) AS 'ManagerReff'
    --,CONVERT(VARCHAR(MAX), _Document650._Fld17720RRef, 2) AS 'DispetcherReff'
    ,IIF(_Document650._Fld17682 >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000,_Document650._Fld17682), null) AS 'StartPlan'
    ,IIF(_Document650._Fld17683 >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000,_Document650._Fld17683), null) AS 'EndPlan'
    ,IIF(_Document650._Fld17716 > DATEFROMPARTS(4001,1,1),DATEADD(YEAR, -2000,_Document650._Fld17716), null) AS 'StartFact'
    ,IIF(_Document650._Fld27200 > DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000,_Document650._Fld27200), null) AS 'EndFact'
    ,CONVERT(VARCHAR(MAX), _Document650._Fld17702RRef, 2) AS 'OperTypeRef'
    --,CAST(_Document650._Fld17698_RTRef as int) AS TruckTableNum
    ,CONVERT(VARCHAR(MAX), _Document650._Fld17698_RRRef, 2) AS 'TruckReff'
	,CONVERT(VARCHAR(MAX), _Document650._Fld17710_RRRef, 2) AS 'DriverReff'
    --,_Document650._Fld17701 AS СуммаУкр
    --,CONVERT(bit, _Document650._Fld26926) AS 'Ready'
    --,_Document650._Fld17692 AS 'IncomeSum'
    --,CONVERT(VARCHAR(MAX), _Document650._Fld17693RRef, 2) AS 'IncomeCurrencyReff'
    ,CONVERT(VARCHAR(MAX), _Document650._Fld17700RRef, 2) AS 'RouteReff'
    --,CONVERT(VARCHAR(MAX), _Document650._Fld17679RRef, 2) AS 'CompanyReff'
    --,CONVERT(VARCHAR(MAX), _Document650._Fld17704_RRRef, 2) AS 'TrailerReff'
    --,TrailerNames._Fld23607 AS 'TrailerName'
    --,Criteria.Description4 AS 'TrailerType'
    ,CONVERT(VARCHAR(MAX), _Document650._Fld17719_RRRef, 2) AS 'Сontainer'
    --,ContainerNames._Description AS 'СontainerName'
    --,ContainerTypes._Description AS 'СontainerType'
    /*,CASE
    WHEN Criteria.Description4 = 'платформа' THEN ContainerTypes._Description
    ELSE Criteria.Description4
    END AS 'OrderType'*/
    --,_Document650._Fld26927 AS 'WeightFact'
    --,_Document650._Fld27198 AS 'DevWeight'
    --,_Document650._Fld17768 AS 'MileageWOCargo'
    --,_Document650._Fld17770 AS 'MileageWCargo'
    --,_Document650._Fld32715 AS 'MileagePlan'
    --,_Document650._Fld32716 AS 'MileageFact'
    --,_Document650._Fld17774 AS 'MileageDeviation'
    ,CAST(_Document650._Fld32970 as bit) AS 'TechOrder'
    --,DirOrderType.OrderDirType
    ,CAST(_Fld17708 as bit) AS 'Expedition'
    ,CAST(CASE 
            WHEN 
                CAST(_Document650._Fld32970 as bit) = 0 
                AND 
                CAST(_Fld17708 as bit) = 0 
                AND 
                _Document650._Fld17685RRef NOT IN (0xA0C10503CE54D6E848C4F4190A4E05BC, 0xB7CC74CE4579F3A7446ED6CC7227830A) 
				AND
				CAST(_Document650._Marked as bit) = 0
				THEN 1 
            ELSE 0 END AS BIT) AS 'Active' 
	--,_Document650._Fld17685RRef
    --,CAST(_Document650._Fld17757 as bit) AS 'NoDeviationsOverTime'
    --,CAST(_Document650._Fld17758 as bit) AS 'NoDeviationsOverExp'
    --,CAST(_Document650._Fld17759 as bit) AS 'NoDeviationsOverMileage'
    --,ExplanationOverTime._Description AS 'ExplanationOverTime'
    --,ExplanationOverExp._Description AS 'ExplanationOverExp'
    --,ExplanationOverMileage._Description AS 'ExplanationOverMileage'
    --,CAST(_Document650._Fld17763 as bit) AS 'DocsSubmittedOnTime'
    --,CAST(_Document650._Fld17764 as bit) AS 'NoCustomerComplaints'
    --,CAST(_Document650._Fld17765 as bit) AS 'CostsProcessed'
    --,CAST(_Document650._Fld17766 as bit) AS 'QualityProcessed'
    --,_Document650._Fld27424 AS 'ReasonByMileage'
    --,_Document650._Fld27425 AS 'ReasonByTime'
    --,_Document650._Fld27426 AS 'ReasonByExp'
    --,_Document650._Fld32210 AS 'AdditionalOnQuality'
    --,_Document650._Fld34309 AS 'MaxPlanWeight'
    --,PlanWeight.PlanWeight
    --,PlanWeight.ExactWeight
    FROM work.dbo._Document650
    INNER JOIN
    (
		SELECT
		*,
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
		END AS 'Statment',
		CAST(
			CASE
				WHEN _Enum26798._EnumOrder IN (5, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 20) THEN 0
				ELSE 1
			END	AS BIT) AS 'UsePlan'
		FROM work.dbo._Enum26798
    WHERE
    	NOT(_Enum26798._EnumOrder IN (2, 6))
    ) AS Statments ON _Document650._Fld17685RRef = Statments._IDRRef
    /*LEFT JOIN work.dbo._Reference162 ON _Document650._Fld17679RRef = _Reference162._IDRRef
    LEFT JOIN (SELECT *, CASE _Enum1144._EnumOrder WHEN 0 THEN 'Перевозки собственным транспортом'	WHEN 1 THEN 'Экспедирование' END AS 'OperatType' FROM work.dbo._Enum1144/* WHERE _EnumOrder = 0*/) as OperTypes ON _Document650._Fld17702RRef = OperTypes._IDRRef
    LEFT JOIN work.dbo._Reference289 AS ContainerNames ON _Document650._Fld17719_RRRef = ContainerNames._IDRRef
    LEFT JOIN work.dbo._Reference289 AS ContainerTypes ON ContainerNames._ParentIDRRef = ContainerTypes._IDRRef
    LEFT JOIN work.dbo._InfoRg23603 AS TrailerNames ON _Document650._Fld17704_RRRef = TrailerNames._Fld23604RRef
    LEFT JOIN (
    SELECT
    _InfoRg34327._Fld34328RRef,
    DimCriteria.L4_Description AS Description4
    FROM _InfoRg34327
    LEFT JOIN cte_DimCriteria AS DimCriteria ON DimCriteria._IDRRef = _InfoRg34327._Fld34329RRef
    INNER JOIN (
    SELECT
    _Fld34328RRef,
    MAX(_Period) AS MaxDate
    FROM _InfoRg34327
    WHERE GETDATE() > DATEADD(YEAR, -2000, _Period)
    GROUP BY _Fld34328RRef
    ) AS CurrentCriteria
    ON CurrentCriteria._Fld34328RRef = _InfoRg34327._Fld34328RRef
    AND CurrentCriteria.MaxDate = _InfoRg34327._Period
    ) AS Criteria
    ON Criteria._Fld34328RRef = _Document650._Fld17704_RRRef
    LEFT JOIN
    (SELECT
    *
    ,CASE _EnumOrder
    WHEN 0 then 'На экспорт'
    WHEN 1 then 'На импорт'
    WHEN 2 then 'Внутренний Украина'
    WHEN 3 then 'Внутренний Европа'
    END AS 'OrderDirType'
    FROM [work].dbo._Enum1191) AS DirOrderType
    ON _Document650._Fld17687RRef = DirOrderType._IDRRef
    LEFT JOIN [work].dbo._Reference331 ExplanationOverTime ON _Document650._Fld17760RRef = ExplanationOverTime._IDRRef
    LEFT JOIN [work].dbo._Reference331 ExplanationOverExp ON _Document650._Fld17760RRef = ExplanationOverExp._IDRRef
    LEFT JOIN [work].dbo._Reference331 ExplanationOverMileage ON _Document650._Fld17760RRef = ExplanationOverMileage._IDRRef
    LEFT JOIN (
    SELECT
    CONVERT(VARCHAR(MAX), _Document650_IDRRef, 2) AS 'Заказ',
    SUM(_Fld17821) AS 'PlanWeight',
    CAST(MIN(CAST(_Fld34307 AS INT)) AS BIT) AS 'ExactWeight'
    FROM _Document650_VT17818
    GROUP BY _Document650_IDRRef
    ) PlanWeight ON PlanWeight.[Заказ] = CONVERT(VARCHAR(MAX), _Document650._IDRRef, 2)*/
	WHERE _Document650._Posted = 0x01
GO

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'vb_DimOrders' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_DimOrders
GO

Create view pbi.vb_DimOrders AS

    SELECT
    _Document650._Number AS 'Order'
    ,_Document650._IDRRef AS 'OrderRef'
    ,IIF(_Document650._Date_Time >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000,_Document650._Date_Time), null) AS 'OrderDate'
	,_Document650._Date_Time AS 'OrderDateRaw'
    ,CAST(IIF(_Document650._Date_Time >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000,_Document650._Date_Time), null) as date) AS 'OrderPrefDate'
    ,CAST(_Document650._Marked as bit) AS 'DeleteMark'
    ,CAST(_Document650._Posted AS bit) AS 'Posted'
    ,_Document650._Fld17681_RRRef AS 'ClientReff'
    ,_Document650._Fld17686RRef AS 'ManagerReff'
    ,IIF(_Document650._Fld17682 >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000,_Document650._Fld17682), null) AS 'StartPlan'
    ,IIF(_Document650._Fld17683 >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000,_Document650._Fld17683), null) AS 'EndPlan'
    ,IIF(_Document650._Fld17716 > DATEFROMPARTS(4001,1,1),DATEADD(YEAR, -2000,_Document650._Fld17716), null) AS 'StartFact'
    ,IIF(_Document650._Fld27200 > DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000,_Document650._Fld27200), null) AS 'EndFact'
    ,_Document650._Fld17702RRef AS 'OperTypeRef'
    ,_Document650._Fld17698_RRRef AS 'TruckReff'
	,_Document650._Fld17710_RRRef AS 'DriverReff'
    ,_Document650._Fld17700RRef AS 'RouteReff'
    ,_Document650._Fld17719_RRRef AS 'Сontainer'
    ,CAST(_Document650._Fld32970 as bit) AS 'TechOrder'
    ,CAST(_Fld17708 as bit) AS 'Expedition'
    ,CAST(CASE 
            WHEN 
                CAST(_Document650._Fld32970 as bit) = 0 
                AND 
                CAST(_Fld17708 as bit) = 0 
                AND 
                _Document650._Fld17685RRef NOT IN (0xA0C10503CE54D6E848C4F4190A4E05BC, 0xB7CC74CE4579F3A7446ED6CC7227830A) 
				AND
				CAST(_Document650._Marked as bit) = 0
				THEN 1 
            ELSE 0 END AS BIT) AS 'Active' 
    FROM work.dbo._Document650
 	WHERE _Document650._Posted = 0x01 AND
	   _Document650._Fld17685RRef NOT IN (0xA0C10503CE54D6E848C4F4190A4E05BC, 0xB7CC74CE4579F3A7446ED6CC7227830A)
	  AND  _Fld17708 = 0x00
	  AND _Fld32970 = 0x00
	  AND _Marked = 0x00
GO
