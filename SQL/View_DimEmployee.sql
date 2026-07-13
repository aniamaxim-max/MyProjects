-- SELECT * from pbi.v_DimEmployee

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_DimEmployee' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_DimEmployee
GO

Create view pbi.v_DimEmployee AS
SELECT
    CONVERT(VARCHAR(MAX), _IDRRef, 2) AS 'EmployeeReff'
    ,_Description AS 'Employee'
    ,CONVERT(VARCHAR(MAX), _Fld2923RRef, 2) AS 'PositionReff'
    ,_Fld2938
    FROM work.dbo._Reference208