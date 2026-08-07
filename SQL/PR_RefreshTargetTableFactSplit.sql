-- exec work.pbi.RefreshTargetTableFactSplit '20260601'
-- select * from pbi.TargetTableFactSplit

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'RefreshTargetTableFactSplit' AND SCHEMA_NAME(schema_id) = 'pbi')
    DROP PROCEDURE pbi.RefreshTargetTableFactSplit;
GO

CREATE PROCEDURE [pbi].[RefreshTargetTableFactSplit]
    @StartDateParam DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#FactSplit') IS NOT NULL DROP TABLE #FactSplit;

    SELECT
        CONVERT(VARCHAR(MAX), pe.OrderRef, 2) AS OrderRef,
        SUM(CASE WHEN de.ExpensesType = 'Fuel'        THEN pe.SumManagerial ELSE 0 END) AS FuelExpTotal,
        SUM(CASE WHEN de.ExpensesType = 'AdBlue'      THEN pe.SumManagerial ELSE 0 END) AS AdBlueExpTotal,
        SUM(CASE WHEN de.ExpensesType = 'RoadTax'     THEN pe.SumManagerial ELSE 0 END) AS RoadTaxExpTotal,
        SUM(CASE WHEN de.ExpensesType = 'Washing'     THEN pe.SumManagerial ELSE 0 END) AS WashingExpTotal,
        SUM(CASE WHEN de.ExpensesType = 'CustomsDuty' THEN pe.SumManagerial ELSE 0 END) AS CustomsDutyExpTotal,
        SUM(CASE WHEN de.ExpensesType = 'Parking'     THEN pe.SumManagerial ELSE 0 END) AS ParkingExpTotal,
        SUM(CASE WHEN de.ExpensesType = 'Fine'        THEN pe.SumManagerial ELSE 0 END) AS FineExpTotal,
        SUM(CASE WHEN de.ExpensesType = 'Other' OR de.ExpensesType IS NULL
                                                  THEN pe.SumManagerial ELSE 0 END) AS OtherExpTotal,
        ISNULL(dp.DayPartSum, 0) AS DayPartSum
    INTO #FactSplit
    FROM pbi.vb_PlanExpenses pe
    LEFT JOIN pbi.vb_DimExpenses de ON de.ExpRef = pe.ExpensesItemRef
    LEFT JOIN (
        SELECT CONVERT(VARCHAR(MAX), OrderRef, 2) AS OrderRef, SUM(DayPart) AS DayPartSum
        FROM pbi.TargetTableFact
        WHERE TargetDate >= @StartDateParam
        GROUP BY CONVERT(VARCHAR(MAX), OrderRef, 2)
    ) dp ON dp.OrderRef = CONVERT(VARCHAR(MAX), pe.OrderRef, 2)
    WHERE pe.Dates >= @StartDateParam
      AND (de.ExpensesType IS NULL OR de.ExpensesType <> 'DriverSalary')
      AND pe.ExpensesItemRef NOT IN (
            0x924F02B31CC3E40111EF691DFA5EBEC0,
            0x924F02B31CC3E40111EF953A22E72470,
            0x8DE59E02FDC0F6A111EB59912A99E1F0
          )
    GROUP BY pe.OrderRef, dp.DayPartSum;

    DELETE f
    FROM pbi.TargetTableFactSplit f
    INNER JOIN #FactSplit s ON s.OrderRef = f.OrderRef;

    INSERT INTO pbi.TargetTableFactSplit
    SELECT OrderRef, FuelExpTotal, AdBlueExpTotal, RoadTaxExpTotal,
           WashingExpTotal, CustomsDutyExpTotal, ParkingExpTotal,
           FineExpTotal, OtherExpTotal, DayPartSum
    FROM #FactSplit;

    DROP TABLE #FactSplit;
END
GO
