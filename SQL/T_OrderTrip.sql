-- =============================================================================
-- Таблица pbi.OrderTrip — результат распределения заказов по кругорейсам
-- (1 рядок = 1 заказ). Заполняется процедурой pbi.RefreshOrderTrip.
-- =============================================================================

IF NOT EXISTS(SELECT * FROM sys.tables t
                    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
                WHERE t.type = 'U' and t.name = 'OrderTrip' and s.name = 'pbi')
BEGIN
    CREATE TABLE pbi.OrderTrip
    (
        OrderRef       varchar(32)   NOT NULL,
        TripNo         int           NULL,
        TripType       nvarchar(20)  NULL,
        TrailerRef     varchar(32)   NOT NULL,
        TrailerName    nvarchar(50)  NULL,
        TrailerCompany nvarchar(100) NULL,
        TripStart      datetime2(0)  NULL,
        TripEnd        datetime2(0)  NULL,
        CalculatedAt   datetime2(0)  NOT NULL CONSTRAINT DF_OrderTrip_CalculatedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_OrderTrip PRIMARY KEY (OrderRef)
    );
END
GO
