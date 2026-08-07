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
    RealFuelExpPerDay       numeric(10,4) not null default 0.0,
    RealAdBlueExpPerDay     numeric(10,4) not null default 0.0,
    RealRoadTaxExpPerDay    numeric(10,4) not null default 0.0,
    RealDriverSalaryExpPerDay numeric(10,4) not null default 0.0,
    RealWashingExpPerDay    numeric(10,4) not null default 0.0,
    RealCustomsDutyExpPerDay numeric(10,4) not null default 0.0,
    RealParkingExpPerDay    numeric(10,4) not null default 0.0,
    RealFineExpPerDay       numeric(10,4) not null default 0.0,
    RealOtherExpPerDay      numeric(10,4) not null default 0.0,
    FactFuelExpPerDay       numeric(10,4) not null default 0.0,
    FactAdBlueExpPerDay     numeric(10,4) not null default 0.0,
    FactRoadTaxExpPerDay    numeric(10,4) not null default 0.0,
    FactWashingExpPerDay    numeric(10,4) not null default 0.0,
    FactCustomsDutyExpPerDay numeric(10,4) not null default 0.0,
    FactParkingExpPerDay    numeric(10,4) not null default 0.0,
    FactFineExpPerDay       numeric(10,4) not null default 0.0,
    FactOtherExpPerDay      numeric(10,4) not null default 0.0,
    FactDriverSalaryPerDay  numeric(10,4) not null default 0.0,
    MarginPerDay            numeric(10,4) not null default 0.0,
    BreakEvenPointPerDay    numeric(10,4) not null default 0.0,
    QuotaPerDay             numeric(10,4) not null default 0.0,
    MainManagerRef          varchar(50),
    CurManagerRef           varchar(50)
);
GO
