-- SELECT * from pbi.v_DriverTax 
-- SELECT * from pbi.vb_DriverTax 

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_DriverTax' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_DriverTax
GO

Create view pbi.v_DriverTax AS

SELECT TaxName, Num, TaxSum, PeriodStart
FROM (VALUES
    (N'МесячнаяСуммаНалоговВодителя',        1,  9856.50, CAST('2023-01-01' AS DATE)),
    (N'МесячнаяСуммаНалоговВодителяТримекс', 2,   958.20, CAST('2023-01-01' AS DATE)),
    (N'МесячнаяСуммаНалоговВодителя',        1, 12203.29, CAST('2026-07-01' AS DATE)),
    (N'МесячнаяСуммаНалоговВодителяТримекс', 2,   958.20, CAST('2026-07-01' AS DATE))
) AS t(TaxName, Num, TaxSum, PeriodStart)
go




IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'vb_DriverTax' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_DriverTax
GO

Create view pbi.vb_DriverTax AS

SELECT TaxName, Num, TaxSum, PeriodStart
FROM (VALUES
    (N'МесячнаяСуммаНалоговВодителя',        1,  9856.50, CAST('2023-01-01' AS DATE)),
    (N'МесячнаяСуммаНалоговВодителяТримекс', 2,   958.20, CAST('2023-01-01' AS DATE)),
    (N'МесячнаяСуммаНалоговВодителя',        1, 12203.29, CAST('2026-07-01' AS DATE)),
    (N'МесячнаяСуммаНалоговВодителяТримекс', 2,   958.20, CAST('2026-07-01' AS DATE))
) AS t(TaxName, Num, TaxSum, PeriodStart)
go
