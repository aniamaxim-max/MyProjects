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
    FuelExpPerDaySource     varchar(1) null,
    AdBlueExpPerDay         numeric(10,4) not null default 0.0,
    AdBlueExpPerDaySource   varchar(1) null,
    RoadTaxExpPerDay        numeric(10,4) not null default 0.0,
    RoadTaxExpPerDaySource  varchar(1) null,
    DriverSalaryExpPerDay   numeric(10,4) not null default 0.0,
    DriverSalaryExpPerDaySource varchar(1) null,
    WashingExpPerDay        numeric(10,4) not null default 0.0,
    WashingExpPerDaySource  varchar(1) null,
    CustomsDutyExpPerDay    numeric(10,4) not null default 0.0,
    CustomsDutyExpPerDaySource varchar(1) null,
    ParkingExpPerDay        numeric(10,4) not null default 0.0,
    ParkingExpPerDaySource  varchar(1) null,
    FineExpPerDay           numeric(10,4) not null default 0.0,
    FineExpPerDaySource     varchar(1) null,
    OtherExpPerDay          numeric(10,4) not null default 0.0,
    OtherExpPerDaySource    varchar(1) null,
    ExpensesPerDay          numeric(10,4) not null default 0.0,
    MarginPerDay            numeric(10,4) not null default 0.0,
    BreakEvenPointPerDay    numeric(10,4) not null default 0.0,
    QuotaPerDay             numeric(10,4) not null default 0.0,
    MainManagerRef          varchar(50),
    CurManagerRef           varchar(50)
);
GO
