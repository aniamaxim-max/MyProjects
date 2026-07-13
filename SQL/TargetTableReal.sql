-- select * from pbi.TargetTableReal where TargetDate >= '20260101'

IF NOT EXISTS(SELECT * FROM sys.tables t
                    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id 
                WHERE type = 'U' and t.name = 'TargetTableReal' and s.name = 'pbi')
BEGIN
    CREATE TABLE [pbi].[TargetTableReal] (    
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
        QuotaPerDay                     numeric(10,4) not null default 0.0,
		MainManagerRef					varchar(50),
		CurManagerRef				    varchar(50)
    );

END
GO