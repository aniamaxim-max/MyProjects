-- SELECT * from pbi.v_DimRates

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_DimRates' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_DimRates
GO

Create view pbi.v_DimRates AS

SELECT
    Draft._Fld20831RRef AS 'CurrencyRef'
    ,DATEADD(YEAR, -2000, Draft._Period) AS 'Dates'
    ,Draft._Fld20832/Draft._Fld20833 AS 'Rate'
    ,(EUR._Fld20832/EUR._Fld20833)/(Draft._Fld20832/Draft._Fld20833) AS 'EURRate'
    FROM
    (SELECT * FROM [work].dbo._InfoRg20830
    UNION ALL
    SELECT
    _InfoRg20830._Period
    ,0x86F7D6671738F3EC11E653118C548396 AS '_Fld20831RRef'
    ,1 AS '_Fld20832'
    ,1 AS '_Fld20833'
    FROM [work].dbo._InfoRg20830
    GROUP BY _InfoRg20830._Period) AS Draft
    LEFT JOIN (SELECT * FROM [work].dbo._InfoRg20830 WHERE _Fld20831RRef = 0x86F7D6671738F3EC11E653118C548398) AS EUR ON EUR._Period = Draft._Period
    WHERE Draft._Period >= DATEFROMPARTS(4020,4,1)
