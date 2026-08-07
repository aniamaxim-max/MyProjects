-- select * from pbi.TargetTableFactSplit

IF EXISTS(SELECT * FROM sys.tables t
                INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
            WHERE type = 'U' and t.name = 'TargetTableFactSplit' and s.name = 'pbi')
    DROP TABLE pbi.TargetTableFactSplit;
GO

CREATE TABLE [pbi].[TargetTableFactSplit] (
    OrderRef                varchar(50),
    FuelExpTotal            numeric(10,4) not null default 0.0,
    AdBlueExpTotal          numeric(10,4) not null default 0.0,
    RoadTaxExpTotal         numeric(10,4) not null default 0.0,
    WashingExpTotal         numeric(10,4) not null default 0.0,
    CustomsDutyExpTotal     numeric(10,4) not null default 0.0,
    ParkingExpTotal         numeric(10,4) not null default 0.0,
    FineExpTotal            numeric(10,4) not null default 0.0,
    OtherExpTotal           numeric(10,4) not null default 0.0,
    DayPartSum              numeric(10,4) not null default 0.0
);
GO

CREATE NONCLUSTERED INDEX TargetTableFactSplit_OrderRef ON [pbi].[TargetTableFactSplit] ([OrderRef])
GO
