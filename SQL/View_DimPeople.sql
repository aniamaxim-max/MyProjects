-- SELECT * from pbi.v_DimPeople

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_DimPeople' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_DimPeople
GO

Create view pbi.v_DimPeople AS

select
    CONVERT(VARCHAR(MAX), DP._IDRRef, 2) AS PeopleRef,
	DP._Description AS Name
from _Reference254 DP
where CAST(DP._Marked as bit) = 0 and
 CAST(DP._Folder as bit) = 1