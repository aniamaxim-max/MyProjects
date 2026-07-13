-- SELECT * from pbi.v_DimTrucks
-- SELECT * from pbi.vb_DimTrucks

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_DimTrucks' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_DimTrucks
GO

Create view pbi.v_DimTrucks AS
SELECT
    CAST(_Reference167._Marked as bit) AS 'DelMark'
    ,CONVERT(VARCHAR(MAX), _Reference167._IDRRef, 2) AS 'TruckReff'
    ,_Reference167._Code AS 'TruckID'
    ,TrucksType._Description AS 'TrucksType'
    ,_Reference286._Description AS 'TruckModel'
    ,_InfoRg23603._Fld23607 AS 'LegalNum'
    ,_InfoRg23603._Fld23629 AS 'CommentTruck'
    ,_Reference167._Description AS 'TruckName'
    ,CONVERT(VARCHAR(MAX), _Reference162._IDRRef, 2) AS 'LastTruckCompanyReff'
    ,_Reference162._Description AS 'LastTruckCompany'
    ,CONVERT(VARCHAR(MAX), UserList1._IDRRef, 2) AS 'DispetcherReff'
    ,UserList1._Description AS 'Dispetcher'
    ,_InfoRg23603._Fld23633 AS 'IssueYear'
    ,_InfoRg23603._Fld23642 AS 'Weight'
    ,_InfoRg23603._Fld27109 AS 'History'
    ,_Reference27091._Description AS 'TruckGroup'
    ,_Reference279._Description AS 'Colonna'
    ,IIF(_InfoRg23603._Fld23640 is null, NULL, _InfoRg23603._Fld23640/1000) AS 'TunkFirstWeight'
    ,IIF(_InfoRg23603._Fld26723 is null, NULL, _InfoRg23603._Fld26723/1000) AS 'TunkSecondWeight'
    ,IIF(_InfoRg23603._Fld32314 is null or _InfoRg23603._Fld32314 = 0, NULL, _InfoRg23603._Fld32314/100) AS 'MaxFillingTank%'
    ,IIF(_InfoRg23603._Fld32315 is null or _InfoRg23603._Fld32315 = 0, NULL, _InfoRg23603._Fld32315/100) AS 'MinFillingTank%'
    ,ISNULL(_InfoRg23603._Fld23642, 0) + ISNULL(_InfoRg23603._Fld23640, 0)/1000 + ISNULL(_InfoRg23603._Fld26723, 0)/1000 AS 'WeightTruckTotal'
    ,IIF(_InfoRg23603._Fld23634 > DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _InfoRg23603._Fld23634), null)  AS 'CommissioningDate1C'
    ,IIF(_InfoRg23603._Fld23643 > DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _InfoRg23603._Fld23643), null)  AS 'DecommissioningDate1C'
    ,Description4
    ,Description3
    ,Description2
    ,Description1
	,cast(case when Description1 = 'Тягачі' 
		and Description2 = 'Робочі'
		then 1
		else 0
	end as bit) as 'Active'
    --,*
    FROM work.dbo._Reference167
    LEFT JOIN work.dbo._InfoRg23603 ON _Reference167._IDRRef = _InfoRg23603._Fld23604RRef -- РегистрСведений.уатПервоначальныеСведенияТС
    LEFT JOIN work.dbo._Reference286 ON _InfoRg23603._Fld23608RRef = _Reference286._IDRRef -- Справочник.уатМоделиТС
    LEFT JOIN (SELECT * FROM work.dbo._Reference315 /*WHERE _Reference315._Code IN ('000000001', '000000002', '000000008', '000000003') AND _Reference315._ParentIDRRef = 0xB8D4899CCA59332411E686247480D326*/) AS TrucksType
    ON _Reference286._Fld3697RRef = TrucksType._IDRRef -- Типы ТС (отбор тягачей, прицепов и контейнеров)
    LEFT JOIN work.dbo._Reference208 AS UserList1 ON _InfoRg23603._Fld23644RRef = UserList1._IDRRef
    LEFT JOIN [work].dbo._Reference27091 ON _InfoRg23603._Fld27103RRef = _Reference27091._IDRRef
    -- Последнее местонахождение ТС (по регистру МестонахождениеТС):
    LEFT JOIN work.dbo._InfoRg23488 ON _Reference167._IDRRef = _InfoRg23488._Fld23489RRef
    LEFT JOIN work.dbo._Reference162 ON _InfoRg23488._Fld23490RRef = _Reference162._IDRRef -- Справочник организаций
    LEFT JOIN [work].dbo._Reference279 ON _InfoRg23488._Fld23491RRef = _Reference279._IDRRef
    LEFT Join (
    select
    _InfoRg34327.*,
    DimCriteria._Description as Description4,
    DimCriteria.Description3,
    DimCriteria.Description2,
    DimCriteria.Description1
    from _InfoRg34327
    left join
    (
    select L4.*,
    coalesce(L3._Description, L4._Description) as 'Description3',
    coalesce(L2._Description, L3._Description, L4._Description) as 'Description2',
    coalesce(L1._Description, L2._Description, L3._Description, L4._Description) as 'Description1'

    from _Reference34326 as L4
    left outer join _Reference34326 as L3 on L4._ParentIDRRef = L3._IDRRef
    left outer join _Reference34326 as L2 on L3._ParentIDRRef = L2._IDRRef
    left outer join _Reference34326 as L1 on L2._ParentIDRRef = L1._IDRRef
    ) as DimCriteria
    ON DimCriteria._IDRRef = _InfoRg34327._Fld34329RRef
inner join (
    select _Fld34328RRef as TruckId, MAX(_Period) as MaxDate
    from _InfoRg34327
    where GETDATE() > DATEADD(YEAR, -2000, _Period)
    group by _Fld34328RRef
    ) as CurrentCriteria
    ON CurrentCriteria.TruckId = _InfoRg34327._Fld34328RRef AND MaxDate = _InfoRg34327._Period
    ) as Criteria ON Criteria._Fld34328RRef = _Reference167._IDRRef
    WHERE _InfoRg23488._Period = (SELECT max( Draft._Period) FROM work.dbo._InfoRg23488 AS Draft WHERE Draft._Fld23489RRef = _InfoRg23488._Fld23489RRef)
GO



IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'vb_DimTrucks' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_DimTrucks
GO

Create view pbi.vb_DimTrucks AS
WITH MaxPeriod_InfoRg23488 AS (
    -- Отримуємо лише останні зрізи для кожного ТС ОДНИМ проходом
    SELECT _Fld23489RRef, MAX(_Period) as MaxPeriod
    FROM work.dbo._InfoRg23488
    GROUP BY _Fld23489RRef
),
CurrentCriteria AS (
    -- Оптимізований пошук максимального періоду критеріїв
    SELECT _Fld34328RRef as TruckId, MAX(_Period) as MaxDate
    FROM work.dbo._InfoRg34327
    -- Замість DATEADD зміщуємо сам GETDATE на +2000 років (виконується 1 раз!)
    WHERE _Period < DATEADD(YEAR, 2000, GETDATE()) 
    GROUP BY _Fld34328RRef
),
DimCriteria_Prepared AS (
    -- Ієрархія довідника критеріїв
    SELECT L4._IDRRef,
           L4._Description as Description4,
           COALESCE(L3._Description, L4._Description) as Description3,
           COALESCE(L2._Description, L3._Description, L4._Description) as Description2,
           COALESCE(L1._Description, L2._Description, L3._Description, L4._Description) as Description1
    FROM work.dbo._Reference34326 as L4
    LEFT JOIN work.dbo._Reference34326 as L3 ON L4._ParentIDRRef = L3._IDRRef
    LEFT JOIN work.dbo._Reference34326 as L2 ON L3._ParentIDRRef = L2._IDRRef
    LEFT JOIN work.dbo._Reference34326 as L1 ON L2._ParentIDRRef = L1._IDRRef
),
Criteria_Final AS (
    -- Збираємо критерії разом
    SELECT T._Fld34328RRef, DC.Description4, DC.Description3, DC.Description2, DC.Description1
    FROM work.dbo._InfoRg34327 T
    INNER JOIN CurrentCriteria CC ON CC.TruckId = T._Fld34328RRef AND CC.MaxDate = T._Period
    LEFT JOIN DimCriteria_Prepared DC ON DC._IDRRef = T._Fld34329RRef
)

SELECT
     _Reference167._Marked AS 'DelMark' -- Прибрано CAST, 1С зберігає тут 0x00/0x01, що є аналогом булево
    ,_Reference167._IDRRef AS 'TruckReff'
    ,_Reference167._Code AS 'TruckID'
    ,TrucksType._Description AS 'TrucksType'
    ,_Reference286._Description AS 'TruckModel'
    ,_InfoRg23603._Fld23607 AS 'LegalNum'
    ,_InfoRg23603._Fld23629 AS 'CommentTruck'
    ,_Reference167._Description AS 'TruckName'
    ,_Reference162._IDRRef AS 'LastTruckCompanyReff'
    ,_Reference162._Description AS 'LastTruckCompany'
    ,UserList1._IDRRef AS 'DispetcherReff'
    ,UserList1._Description AS 'Dispetcher'
    ,_InfoRg23603._Fld23633 AS 'IssueYear'
    ,_InfoRg23603._Fld23642 AS 'Weight'
    ,_InfoRg23603._Fld27109 AS 'History'
    ,_Reference27091._Description AS 'TruckGroup'
    ,_Reference279._Description AS 'Colonna'
    ,IIF(_InfoRg23603._Fld23640 IS NULL, NULL, _InfoRg23603._Fld23640/1000.0) AS 'TunkFirstWeight' -- 1000.0 запобігає цілочисельному діленню
    ,IIF(_InfoRg23603._Fld26723 IS NULL, NULL, _InfoRg23603._Fld26723/1000.0) AS 'TunkSecondWeight'
    ,IIF(_InfoRg23603._Fld32314 IS NULL OR _InfoRg23603._Fld32314 = 0, NULL, _InfoRg23603._Fld32314/100.0) AS 'MaxFillingTank%'
    ,IIF(_InfoRg23603._Fld32315 IS NULL OR _InfoRg23603._Fld32315 = 0, NULL, _InfoRg23603._Fld32315/100.0) AS 'MinFillingTank%'
    ,ISNULL(_InfoRg23603._Fld23642, 0) + ISNULL(_InfoRg23603._Fld23640, 0)/1000.0 + ISNULL(_InfoRg23603._Fld26723, 0)/1000.0 AS 'WeightTruckTotal'
    ,IIF(_InfoRg23603._Fld23634 > DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _InfoRg23603._Fld23634), NULL) AS 'CommissioningDate1C'
    ,IIF(_InfoRg23603._Fld23643 > DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _InfoRg23603._Fld23643), NULL) AS 'DecommissioningDate1C'
    ,Criteria.Description4
    ,Criteria.Description3
    ,Criteria.Description2
    ,Criteria.Description1
    ,IIF(Criteria.Description1 = 'Тягачі' AND Criteria.Description2 = 'Робочі', 1, 0) AS 'Active' -- Спрощено без CAST

FROM work.dbo._Reference167
LEFT JOIN work.dbo._InfoRg23603 ON _Reference167._IDRRef = _InfoRg23603._Fld23604RRef
LEFT JOIN work.dbo._Reference286 ON _InfoRg23603._Fld23608RRef = _Reference286._IDRRef
LEFT JOIN work.dbo._Reference315 AS TrucksType ON _Reference286._Fld3697RRef = TrucksType._IDRRef -- Прямий джоїн без підзапиту

LEFT JOIN work.dbo._Reference208 AS UserList1 ON _InfoRg23603._Fld23644RRef = UserList1._IDRRef
LEFT JOIN work.dbo._Reference27091 ON _InfoRg23603._Fld27103RRef = _Reference27091._IDRRef

-- Оптимізований зріз останніх даних по місцезнаходженню
INNER JOIN MaxPeriod_InfoRg23488 MP ON _Reference167._IDRRef = MP._Fld23489RRef
INNER JOIN work.dbo._InfoRg23488 ON _InfoRg23488._Fld23489RRef = MP._Fld23489RRef AND _InfoRg23488._Period = MP.MaxPeriod

LEFT JOIN work.dbo._Reference162 ON _InfoRg23488._Fld23490RRef = _Reference162._IDRRef
LEFT JOIN work.dbo._Reference279 ON _InfoRg23488._Fld23491RRef = _Reference279._IDRRef
LEFT JOIN Criteria_Final AS Criteria ON Criteria._Fld34328RRef = _Reference167._IDRRef

GO



