--IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'FreeCar' AND SCHEMA_NAME(schema_id) = 'pbi')
--    DROP PROCEDURE pbi.FreeCar;
--GO
--select * from [pbi].[FreeCars]

IF NOT EXISTS(SELECT * FROM sys.tables t
                    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id 
                WHERE type = 'U' and t.name = 'FreeCars' and s.name = 'pbi')
BEGIN
    CREATE TABLE [pbi].[FreeCars] (    
		TruckReff   VARCHAR(MAX),
        LegalNum    VARCHAR(MAX),
        Manager     VARCHAR(MAX),
		[Counter]   INT,
        [Status]    VARCHAR(MAX),
		QuotaIsDone NUMERIC(10,2),
		GeoZone     VARCHAR(MAX)
    );
    

END
GO

IF NOT EXISTS (SELECT * 
                FROM sys.columns c
                    INNER JOIN sys.objects o ON c.object_Id = o.object_Id
					INNER JOIN sys.schemas s ON o.schema_id = s.schema_id 
                WHERE c.name = 'CounterRemont' and o.name = 'FreeCars' and s.name = 'pbi')
    ALTER TABLE [pbi].[FreeCars] ADD
        CounterRemont    INT
GO 

IF NOT EXISTS (SELECT * 
                FROM sys.columns c
                    INNER JOIN sys.objects o ON c.object_Id = o.object_Id
					INNER JOIN sys.schemas s ON o.schema_id = s.schema_id 
                WHERE c.name = 'CounterWork' and o.name = 'FreeCars' and s.name = 'pbi')
    ALTER TABLE [pbi].[FreeCars] ADD
        CounterWork    INT
GO 
