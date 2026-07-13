
--select * from pbi.v_Calendar

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_Calendar' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_Calendar
GO

Create view pbi.v_Calendar AS
select  
	IIF(_InfoRg30060._Period >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000,_InfoRg30060._Period), _InfoRg30060._Period) AS 'CalDate'
from _InfoRg30060

go
