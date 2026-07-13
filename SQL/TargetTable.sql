-- select COUNT(*) from pbi.TargetTableFact where TargetDate >= '20260101' and OrderRef is not NULl

-- select COUNT(*) from pbi.TargetTablePlan where TargetDate >= '20260101' and OrderRef is not NULl

IF NOT EXISTS(SELECT * FROM sys.tables t
                    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id 
                WHERE type = 'U' and t.name = 'TargetTablePlan' and s.name = 'pbi')
BEGIN
    CREATE TABLE [pbi].[TargetTablePlan] (    
        TruckRef                        varchar(50),
        TargetDate                      datetime,
        OrderRef                        varchar(50),
        DriverRef                       varchar(50),
        StatementRef                    varchar(50),
        IsPaidStatement                 bit not null default 1,
        DurationStatement               bit not null default 1,
        DayPart                         numeric(10,2) not null default 0.0,
        IncomePerDay                    numeric(10,4) not null default 0.0,
        ExpensesPerDayWithoutSalary     numeric(10,4) not null default 0.0,
        DriverSalaryPerDay              numeric(10,2) not null default 0.0,
        MarginPerDay                    numeric(10,4) not null default 0.0,
        BreakEvenPointPerDay            numeric(10,4) not null default 0.0,
        QuotaPerDay                     numeric(10,4) not null default 0.0
    );
    
    CREATE NONCLUSTERED INDEX TargetTablePlan_TargetDate_TruckRef ON [pbi].[TargetTablePlan] ([TargetDate], [TruckRef])
END
GO

IF NOT EXISTS(SELECT * FROM sys.tables t
                    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id 
                WHERE type = 'U' and t.name = 'TargetTableFact' and s.name = 'pbi')
BEGIN
    CREATE TABLE [pbi].[TargetTableFact] (    
        TruckRef                        varchar(50),
        TargetDate                      datetime,
        OrderRef                        varchar(50),
        DriverRef                       varchar(50),
        StatementRef                    varchar(50),
        IsPaidStatement                 bit not null default 1,
        DurationStatement               bit not null default 1,
        DayPart                         numeric(10,2) not null default 0.0,
        IncomePerDay                    numeric(10,4) not null default 0.0,
        ExpensesPerDayWithoutSalary     numeric(10,4) not null default 0.0,
        DriverSalaryPerDay              numeric(10,2) not null default 0.0,
        MarginPerDay                    numeric(10,4) not null default 0.0,
        BreakEvenPointPerDay            numeric(10,4) not null default 0.0,
        QuotaPerDay                     numeric(10,4) not null default 0.0
    );
    
    CREATE NONCLUSTERED INDEX TargetTableFact_TargetDate_TruckRef ON [pbi].[TargetTableFact] ([TargetDate], [TruckRef])
END
GO

IF NOT EXISTS (SELECT * 
                FROM sys.columns c
                    INNER JOIN sys.objects o ON c.object_Id = o.object_Id
					INNER JOIN sys.schemas s ON o.schema_id = s.schema_id 
                WHERE c.name = 'MainManagerRef' and o.name = 'TargetTablePlan' and s.name = 'pbi')
    ALTER TABLE [pbi].[TargetTablePlan] ADD
        MainManagerRef    varchar(50)
GO 

IF NOT EXISTS (SELECT * 
                FROM sys.columns c
                    INNER JOIN sys.objects o ON c.object_Id = o.object_Id
					INNER JOIN sys.schemas s ON o.schema_id = s.schema_id 
                WHERE c.name = 'CurManagerRef' and o.name = 'TargetTablePlan' and s.name = 'pbi')
    ALTER TABLE [pbi].[TargetTablePlan] ADD
        CurManagerRef    varchar(50)
GO 

IF NOT EXISTS (SELECT * 
                FROM sys.columns c
                    INNER JOIN sys.objects o ON c.object_Id = o.object_Id
					INNER JOIN sys.schemas s ON o.schema_id = s.schema_id 
                WHERE c.name = 'MainManagerRef' and o.name = 'TargetTableFact' and s.name = 'pbi')
    ALTER TABLE [pbi].[TargetTableFact] ADD
        MainManagerRef    varchar(50)
GO 

IF NOT EXISTS (SELECT * 
                FROM sys.columns c
                    INNER JOIN sys.objects o ON c.object_Id = o.object_Id
					INNER JOIN sys.schemas s ON o.schema_id = s.schema_id 
                WHERE c.name = 'CurManagerRef' and o.name = 'TargetTableFact' and s.name = 'pbi')
    ALTER TABLE [pbi].[TargetTableFact] ADD
        CurManagerRef    varchar(50)
GO 
