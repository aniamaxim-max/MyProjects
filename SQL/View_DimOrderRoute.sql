-- SELECT * from pbi.v_DimOrderRoute
-- SELECT * from pbi.vb_DimOrderRoute

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_DimOrderRoute' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_DimOrderRoute
GO

Create view pbi.v_DimOrderRoute AS
SELECT
    _Document650_VT17775._LineNo17776 AS 'Line'
    ,CONVERT(VARCHAR(MAX), _Document650_VT17775._Fld17777RRef, 2) AS 'SubRuoteRef'
    ,_Document650_VT17775._Fld17786 AS 'RouteID'
    ,CAST(_Document650_VT17775._Fld17790 as bit) AS 'EmptyRoute'
    ,CONVERT(VARCHAR(MAX), _Document650_VT17775._Document650_IDRRef, 2) AS 'OrderRef'
    ,CAST(_Document650_VT17775._KeyField as int) AS 'KeyField'
    FROM _Document650_VT17775
GO


IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'vb_DimOrderRoute' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_DimOrderRoute
GO

Create view pbi.vb_DimOrderRoute AS
SELECT
    _Document650_VT17775._LineNo17776 AS 'Line'
    ,_Document650_VT17775._Fld17777RRef AS 'SubRuoteRef'
    ,_Document650_VT17775._Fld17786 AS 'RouteID'
    ,CAST(_Document650_VT17775._Fld17790 as bit) AS 'EmptyRoute'
    ,_Document650_VT17775._Document650_IDRRef AS 'OrderRef'
    ,CAST(_Document650_VT17775._KeyField as int) AS 'KeyField'
    FROM _Document650_VT17775

