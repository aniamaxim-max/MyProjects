-- SELECT * from pbi.v_OrderCost
-- SELECT * from pbi.vb_OrderCost

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_OrderCost' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_OrderCost
GO

Create view pbi.v_OrderCost AS
SELECT
    CONVERT(VARCHAR(MAX), CO._RecorderRRef, 2) AS RecoderReff
    ,CONVERT(VARCHAR(MAX), CO._Fld26657RRef, 2) AS OrderRef
    ,CO._Fld32910 AS SalesPlan -- áåç ÏÄÂ
    ,CO._Fld33218 AS SalesPlanVAT
    ,CO._Fld26659 AS SalesFact -- áåç ÏÄÂ
    ,CO._Fld33217 AS SalesFactVAT
	,CASE 
		WHEN ISNULL(CO._Fld26659, 0) = 0 THEN CO._Fld32910 ELSE CO._Fld26659 END AS SalesFactOrPlan
    ,CO._Fld26662 AS MileageWCargo
    ,CO._Fld26663 AS MileageWOCargo

FROM work.dbo._AccumRg26655 CO
WHERE
    CAST(CO._Active AS bit) = 1 AND
	CONVERT(int, CO._RecorderTRef) = 650
GO


IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'vb_OrderCost' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_OrderCost
GO

Create view pbi.vb_OrderCost AS
SELECT
    CO._RecorderRRef AS RecoderReff
    ,CO._Fld26657RRef AS OrderRef
    ,CO._Fld32910 AS SalesPlan -- áåç ÏÄÂ
    ,CO._Fld33218 AS SalesPlanVAT
    ,CO._Fld26659 AS SalesFact -- áåç ÏÄÂ
    ,CO._Fld33217 AS SalesFactVAT
	,CASE 
		WHEN ISNULL(CO._Fld26659, 0) = 0 THEN CO._Fld32910 ELSE CO._Fld26659 END AS SalesFactOrPlan
    ,CO._Fld26662 AS MileageWCargo
    ,CO._Fld26663 AS MileageWOCargo


FROM work.dbo._AccumRg26655 CO
WHERE
    CO._Active = 0x01 AND
	CO._RecorderTRef = 0x0000028A

