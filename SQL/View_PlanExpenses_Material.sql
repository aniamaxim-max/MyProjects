-- SELECT * from pbi.v_PlanExpensesMaterial

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_PlanExpensesMaterial' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_PlanExpensesMaterial
GO

Create view pbi.v_PlanExpensesMaterial AS

SELECT
    OrderRef,
    SUM(SumManagerial) AS SumMaterial
FROM pbi.v_PlanExpenses
WHERE NomenclatureRef NOT IN ('9438B52C1CA5BDB511E67F083B490E5A', '9438B52C1CA5BDB511E67F083B490E5A')
GROUP BY
    OrderRef;