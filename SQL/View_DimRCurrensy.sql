-- SELECT * from pbi.v_DimCurrensy 

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_DimCurrensy' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_DimCurrensy
GO

Create view pbi.v_DimCurrensy AS
SELECT
    CONVERT(VARCHAR(MAX), _IDRRef, 2) AS 'CurrencyRef'
    ,CAST(_Code as int) AS 'CurrencyID'
    ,_Description AS 'CurrencyName'
    ,_Fld1711 AS 'CurrencyFullName'
    FROM [work].dbo._Reference38