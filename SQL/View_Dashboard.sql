select O.*, ISNULL(Income.SalesOrdersVAT, 0) as SalesOrdersVAT, ISNULL(Expenses.SumManagerialNetto, 0) AS Expenses
from v_DimOrdersDirect as O
left join(
	SELECT
	CONVERT(VARCHAR(MAX), _AccumRg26655._Fld26657RRef, 2) AS 'OrderRef'
    /*CAST(_AccumRg26655._Active AS bit) AS 'Active'
    ,CONVERT(int, _AccumRg26655._RecorderTRef) AS 'RecoderTable'
    ,CONVERT(VARCHAR(MAX), _AccumRg26655._RecorderRRef, 2) AS 'RecoderReff'*/
    /*,CONVERT(bit, _Document684._Fld32554) AS 'Arrive'
    ,_AccumRg26655._Fld26660 AS 'COGS'
    ,_AccumRg26655._Fld34289 AS 'COGSVAT'*/
    /*,_AccumRg26655._Fld32910 + _AccumRg26655._Fld33218 AS 'SalesPlan'
    ,_AccumRg26655._Fld33218 AS 'SalesPlanVAT'
    ,_AccumRg26655._Fld26659 + _AccumRg26655._Fld33217 AS 'SalesFact'
    ,_AccumRg26655._Fld33217 AS 'SalesFactVAT'
	,CASE    
		WHEN (_AccumRg26655._Fld26659 + _AccumRg26655._Fld33217) > 0      
			THEN (_AccumRg26655._Fld26659 + _AccumRg26655._Fld33217)  
		WHEN (_AccumRg26655._Fld32910 + _AccumRg26655._Fld33218) <> 0        
			THEN (_AccumRg26655._Fld32910 + _AccumRg26655._Fld33218)   
		ELSE 0    
	END AS 'SalesOrders'*/
    ,CASE 
		WHEN SUM(_AccumRg26655._Fld26659) > 0 
			THEN SUM(_AccumRg26655._Fld26659)
		WHEN SUM(_AccumRg26655._Fld32910) <> 0 
			THEN SUM(_AccumRg26655._Fld32910)
		ELSE 0
	END AS 'SalesOrdersVAT' 
    /*,_Document684._Fld19472 AS 'DaysNumInside'
    ,_Document684._Fld19473 AS 'DaysNumAbroad'
    ,_AccumRg26655._Fld26662 AS 'MileageWCargo'
    ,_AccumRg26655._Fld26663 AS 'MileageWOCargo'
    --,**/
    FROM work.dbo._AccumRg26655
    /*LEFT JOIN work.dbo._Document650 ON _AccumRg26655._Fld26657RRef = _Document650._IDRRef -- Заказы на ТС
    INNER JOIN (SELECT * FROM work.dbo._Enum26798 /*WHERE NOT(_Enum26798._EnumOrder IN (2, 6))*/) AS OrderState ON _Document650._Fld17685RRef = OrderState._IDRRef -- Исключение отказных заявок на использование ТС
    LEFT JOIN work.dbo._Document684 ON _AccumRg26655._RecorderRRef = _Document684._IDRRef -- Регистратор Расчет нормативных затрат*/
    WHERE
    CAST(_AccumRg26655._Active AS bit) = 1 AND
	CONVERT(VARCHAR(MAX), _AccumRg26655._Fld26657RRef, 2) IN
		(Select CONVERT(VARCHAR(MAX), _Document650._IDRRef, 2) 
		FROM _Document650
		WHERE IIF(_Document650._Date_Time >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000,_Document650._Date_Time), null) >= DATEADD(MONTH, -2, getdate()))
	GROUP BY CONVERT(VARCHAR(MAX), _AccumRg26655._Fld26657RRef, 2)

) as Income on O.OrderRef = Income.OrderRef

left join(
SELECT
    CONVERT(VARCHAR(MAX), _AccumRg26553._Fld26554_RRRef, 2) AS 'OrderRef',
	/*DATEADD(YEAR, -2000, _AccumRg26553._Period) AS 'Dates',
    CAST(_AccumRg26553._RecorderTRef as int) AS 'RegTableNum',
    CONVERT(VARCHAR(MAX), _AccumRg26553._RecorderRRef, 2) AS 'RegRef',
    CAST(_AccumRg26553._Active as bit) AS 'Active',
    CASE
    WHEN CONVERT(VARCHAR(32), _AccumRg26553._Fld26555RRef, 2) = '93E78FEF853B0AA111EB6256B4F85879'
    THEN '983902B31CC3E40111EC7F3FD376A4F0'
    ELSE CONVERT(VARCHAR(MAX), _AccumRg26553._Fld26555RRef, 2)
    END AS 'ExpensesArticleRef',
    CAST(_AccumRg26553._Fld26556_RTRef as int) AS 'NomenclatureTableNum',
    CONVERT(VARCHAR(MAX), _AccumRg26553._Fld26556_RRRef, 2) AS 'NomenclatureRef',
    SUM(
    CASE
    WHEN CONVERT(VARCHAR(MAX), _AccumRg26553._Fld26556_RRRef, 2) = '9438B52C1CA5BDB511E67F079576A5AA'
    THEN (_Document684._Fld19466 + _Document684._Fld19467 + _Document684._Fld19468)
    ELSE 0
    END
    ) AS 'FuelPlan',
    CONVERT(VARCHAR(MAX), _AccumRg26553._Fld26557RRef, 2) AS 'CompanyRef',
    CONVERT(VARCHAR(MAX), _AccumRg26553._Fld26558RRef, 2) AS 'ClientRef',
    CONVERT(VARCHAR(MAX), _AccumRg26553._Fld26559_RRRef, 2) AS 'SubdivisionRef',
    CAST(_AccumRg26553._Fld26560_RTRef as int) AS 'TruckTableNum',
    CONVERT(VARCHAR(MAX), _AccumRg26553._Fld26560_RRRef, 2) AS 'TruckRef',
    CONVERT(VARCHAR(MAX), _AccumRg26553._Fld26561_RRRef, 2) AS 'PivotRouteRef',
    CONVERT(VARCHAR(MAX), _Document684._Fld19480RRef, 2) AS 'DriverRef',
    OperType.OperTypeCNE,
    CAST(_Document684._Fld32554 as bit) AS 'ArriveCost',
    SUM(_AccumRg26553._Fld26562) AS 'Mount',
    SUM(_AccumRg26553._Fld26563) AS 'SumFact',
    SUM(_AccumRg26553._Fld26564) AS 'VAT',*/
    SUM(_AccumRg26553._Fld26565) - SUM(_AccumRg26553._Fld26566) AS 'SumManagerialNetto'
    /*SUM(_AccumRg26553._Fld26566) AS 'VATManagerial'*/
    FROM [work].dbo._AccumRg26553
    /*LEFT JOIN work.dbo._Document684
    ON _AccumRg26553._RecorderRRef = _Document684._IDRRef -- Документ - регистратор нормативных затрат (Расчет нормативных зтрат)
    LEFT JOIN
    (
    SELECT
    *,
    CASE _EnumOrder
    WHEN 0 THEN 'Шаблон'
    WHEN 1 THEN 'Расчет нормативных затрат'
    WHEN 2 THEN 'Оперативные затраты'
    END AS 'OperTypeCNE'
    FROM [work].dbo._Enum1201
    ) AS OperType
    ON _AccumRg26553._Fld32407RRef = OperType._IDRRef*/
    WHERE
    CAST(_AccumRg26553._Active AS bit) = 1
    AND _AccumRg26553._Fld26565 <> 0
	GROUP BY
    _AccumRg26553._Fld26554_RRRef
    /*OperType.OperTypeCNE,
    _Document684._Fld32554,
    _Document684._Fld19480RRef*/
	) 
		as Expenses on O.OrderRef = Expenses.OrderRef
		where OrderDate >= DATEADD(MONTH, -2, getdate())