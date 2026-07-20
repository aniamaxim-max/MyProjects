-- SELECT * from pbi.v_DimUsers
-- SELECT * from pbi.vb_DimUsers

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_DimUsers' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_DimUsers
GO

Create view pbi.v_DimUsers AS

SELECT
    CONVERT(VARCHAR(MAX), _Reference177._IDRRef, 2) AS 'UserReff'
    ,_Reference177._Description AS 'User'
FROM work.dbo._Reference177
GO

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'vb_DimUsers' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_DimUsers
GO

CREATE VIEW pbi.vb_DimUsers AS
SELECT
    _IDRRef        AS UserReff,
    _Description   AS [User]
FROM work.dbo._Reference177