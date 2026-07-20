-- select * from pbi.vb_Expenses

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'vb_Expenses' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_Expenses
GO

Create view pbi.vb_Expenses AS

SELECT
    IIF(_AccumRg26319._Period > DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _AccumRg26319._Period), null) AS 'Date'
    ,CONVERT(int, _AccumRg26319._RecorderTRef) AS 'RegReffTable'
    ,_AccumRg26319._RecorderRRef AS 'RegReff'
    ,_AccumRg26319._Fld26320_RRRef AS 'TruckOrderRef'
    ,_AccumRg26319._Fld26320_RRRef AS 'OrderRef'
    ,_AccumRg26319._Fld26321RRef AS 'ExpensesRef'
    ,_Reference219._Description AS 'ExpencesItem'
    ,CONVERT(int, _AccumRg26319._Fld26322_RTRef) AS 'NomReffTable'
    ,_Reference152._Description AS 'NomItem'
    ,_AccumRg26319._Fld26322_RRRef AS 'NomReff'
    ,_AccumRg26319._Fld26323RRef AS 'CompanyReff'
    ,_AccumRg26319._Fld26324RRef AS 'ClientReff'
    ,_AccumRg26319._Fld26325_RRRef AS 'CFRRef'
    ,_AccumRg26319._Fld26326_RRRef as 'TruckReff'
    --,_Reference167._Code AS 'TruckID'
    ,_AccumRg26319._Fld26327_RRRef AS 'PivotRouteRef'
    ,_AccumRg26319._Fld26329 AS 'PlanSumm'
    ,_AccumRg26319._Fld26330 AS 'FactSum'
    ,_AccumRg26319._Fld26332 AS 'Sum'
    ,_AccumRg26319._Fld26333 AS 'NDS'
    ,_AccumRg26319._Fld34333 AS 'DriverWork'
    FROM work.dbo._AccumRg26319
   -- LEFT JOIN _Document650 AS TruckOrder ON _AccumRg26319._Fld26320_RRRef = TruckOrder._IDRRef -- Заказ на использование ТС (с отбором по факт по?)
   /* LEFT JOIN
    (SELECT
        *
        ,CASE _Enum1144._EnumOrder
            WHEN 0 THEN 'Перевозки собственным транспортом'
            WHEN 1 THEN 'Экспедирование'
        END AS 'OperatType'
    FROM work.dbo._Enum1144 /*WHERE _EnumOrder = 0*/) as OperTypes
    ON TruckOrder._Fld17702RRef = OperTypes._IDRRef*/
    LEFT JOIN work.dbo._Reference219 ON _AccumRg26319._Fld26321RRef = _Reference219._IDRRef -- Справочник статей затрат
    LEFT JOIN work.dbo._Reference152 ON _AccumRg26319._Fld26322_RRRef = _Reference152._IDRRef -- Справочник Номенклатуры
  --  LEFT JOIN work.dbo._Reference167 ON TruckOrder._Fld17698_RRRef = _Reference167._IDRRef -- Справочник Основных средств
    WHERE
    _AccumRg26319._Active = 0x01 AND
    _AccumRg26319._Period >= '40230101'