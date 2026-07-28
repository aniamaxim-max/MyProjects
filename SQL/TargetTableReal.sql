-- select * from pbi.TargetTableReal where TargetDate >= '20260101'

IF EXISTS(SELECT * FROM sys.tables t
                INNER JOIN sys.schemas s ON t.schema_id = s.schema_id 
            WHERE type = 'U' and t.name = 'TargetTableReal' and s.name = 'pbi')
    DROP TABLE pbi.TargetTableReal;
GO

CREATE TABLE [pbi].[TargetTableReal] (    
    TruckRef                varchar(50),
    TargetDate              datetime,
    OrderRef                varchar(50),
    DriverRef               varchar(50),
    StatementRef            varchar(50),
    IsPaidStatement         bit not null default 1,
    DurationStatement       bit not null default 1,
    DayPart                 numeric(10,2) not null default 0.0,
    IncomePerDay            numeric(10,4) not null default 0.0,
    FuelExpPerDay           numeric(10,4) not null default 0.0,
    AdBlueExpPerDay         numeric(10,4) not null default 0.0,
    RoadTaxExpPerDay        numeric(10,4) not null default 0.0,
    DriverSalaryExpPerDay   numeric(10,4) not null default 0.0,
    WashingExpPerDay        numeric(10,4) not null default 0.0,
    CustomsDutyExpPerDay    numeric(10,4) not null default 0.0,
    ParkingExpPerDay        numeric(10,4) not null default 0.0,
    FineExpPerDay           numeric(10,4) not null default 0.0,
    OtherExpPerDay          numeric(10,4) not null default 0.0,
    MarginPerDay            numeric(10,4) not null default 0.0,
    BreakEvenPointPerDay    numeric(10,4) not null default 0.0,
    QuotaPerDay             numeric(10,4) not null default 0.0,
    MainManagerRef          varchar(50),
    CurManagerRef           varchar(50)
);
GO