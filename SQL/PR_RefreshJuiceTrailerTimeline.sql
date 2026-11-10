-- exec pbi.usp_RefreshJuiceTrailerTimeline
-- select * from pbi.t_JuiceTrailerTimeline
-- =============================================================================
-- Оновлює знімок pbi.t_JuiceTrailerTimeline (TRUNCATE + INSERT).
-- В'юха pbi.v_JuiceTrailerSummary будується поверх цієї таблиці
-- і окремого оновлення не потребує.
-- =============================================================================

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'usp_RefreshJuiceTrailerTimeline' AND SCHEMA_NAME(schema_id) = 'pbi')
    DROP PROCEDURE pbi.usp_RefreshJuiceTrailerTimeline;
GO

CREATE PROCEDURE pbi.usp_RefreshJuiceTrailerTimeline
    @DateFrom date = NULL,
    @DateTo   date = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @DateFrom = ISNULL(@DateFrom, '2026-01-01');
    SET @DateTo   = ISNULL(@DateTo, CAST(GETDATE() AS date));

    DECLARE @RawFrom datetime = DATEADD(YEAR, 2000, @DateFrom);
    DECLARE @RawTo   datetime = DATEADD(YEAR, 2000, @DateTo);

    IF OBJECT_ID('tempdb..#JuiceTrailers') IS NOT NULL DROP TABLE #JuiceTrailers;
    IF OBJECT_ID('tempdb..#Orders')         IS NOT NULL DROP TABLE #Orders;
    IF OBJECT_ID('tempdb..#Base')           IS NOT NULL DROP TABLE #Base;

    BEGIN TRY
        BEGIN TRAN;

        ------------------------------------------------------------
        -- 1. Прицепы, у которых был сок в периоде
        ------------------------------------------------------------
        SELECT DISTINCT d._Fld17704_RRRef AS TrailerRef
        INTO #JuiceTrailers
        FROM work.dbo._Document650 AS d WITH (NOLOCK)
        INNER JOIN work.dbo._Reference271 AS cg WITH (NOLOCK)
            ON cg._IDRRef = d._Fld17728RRef
        WHERE LTRIM(RTRIM(cg._Description)) = N'Сік/концентрат/аромати'
          AND d._Posted = 0x01
          AND d._Marked = 0x00
          AND d._Fld32970 = 0x00
          AND d._Fld17708 = 0x00
          AND d._Fld27200 >= @RawFrom
          AND d._Fld27200 <  @RawTo
          AND d._Fld17685RRef NOT IN (
                0xA0C10503CE54D6E848C4F4190A4E05BC,
                0xB7CC74CE4579F3A7446ED6CC7227830A
              )
          AND d._Fld17704_RRRef <> 0x00000000000000000000000000000000
        OPTION (RECOMPILE);

        CREATE UNIQUE CLUSTERED INDEX IX_JuiceTrailers
            ON #JuiceTrailers (TrailerRef);

        ------------------------------------------------------------
        -- 2. Все рейсы этих прицепов за период
        ------------------------------------------------------------
        SELECT
            d._IDRRef                    AS OrderRef,
            LTRIM(RTRIM(d._Number))      AS OrderNo,
            IIF(d._Date_Time >= DATEFROMPARTS(4001,1,1),
                DATEADD(YEAR, -2000, d._Date_Time), NULL) AS OrderDate,
            IIF(d._Fld17682 >= DATEFROMPARTS(4001,1,1),
                DATEADD(YEAR, -2000, d._Fld17682), NULL)  AS StartPlan,
            IIF(d._Fld17683 >= DATEFROMPARTS(4001,1,1),
                DATEADD(YEAR, -2000, d._Fld17683), NULL)  AS EndPlan,
            IIF(d._Fld17716 > DATEFROMPARTS(4001,1,1),
                DATEADD(YEAR, -2000, d._Fld17716), NULL)  AS StartFact,
            IIF(d._Fld27200 > DATEFROMPARTS(4001,1,1),
                DATEADD(YEAR, -2000, d._Fld27200), NULL)  AS EndFact,
            d._Fld17704_RRRef            AS TrailerRef,
            d._Fld17698_RRRef            AS TruckRef,
            d._Fld17681_RRRef            AS ClientRef,
            d._Fld17679RRef              AS CompanyRef,
            d._Fld17700RRef              AS RouteRef,
            d._Fld17728RRef              AS CargoGroupRef
        INTO #Orders
        FROM work.dbo._Document650 AS d WITH (NOLOCK)
        WHERE d._Posted = 0x01
          AND d._Marked = 0x00
          AND d._Fld32970 = 0x00
          AND d._Fld17708 = 0x00
          AND d._Fld27200 >= @RawFrom
          AND d._Fld27200 <  @RawTo
          AND d._Fld17685RRef NOT IN (
                0xA0C10503CE54D6E848C4F4190A4E05BC,
                0xB7CC74CE4579F3A7446ED6CC7227830A
              )
          AND d._Fld17704_RRRef IN (SELECT TrailerRef FROM #JuiceTrailers)
        OPTION (RECOMPILE);

        ------------------------------------------------------------
        -- 3. Размерности
        ------------------------------------------------------------
        SELECT
            CONVERT(VARCHAR(32), o.OrderRef, 2) AS OrderRef,
            o.OrderNo,
            o.OrderDate,
            o.StartPlan,
            o.EndPlan,
            o.StartFact,
            o.EndFact,
            CONVERT(VARCHAR(32), o.TrailerRef, 2) AS TrailerReff,
            LTRIM(RTRIM(tn._Fld23607))            AS TrailerName,
            CONVERT(VARCHAR(32), o.TruckRef, 2)   AS TruckReff,
            LTRIM(RTRIM(tt._Fld23607))            AS TractorName,
            cl._Description                       AS ClientName,
            org._Description                      AS CompanyName,
            CONVERT(VARCHAR(32), o.RouteRef, 2)   AS RouteReff,
            pr._Description                       AS RouteName,
            cg._Description                       AS CargoGroupName
        INTO #Base
        FROM #Orders AS o
        LEFT JOIN work.dbo._InfoRg23603 AS tn WITH (NOLOCK)
            ON tn._Fld23604RRef = o.TrailerRef
        LEFT JOIN work.dbo._InfoRg23603 AS tt WITH (NOLOCK)
            ON tt._Fld23604RRef = o.TruckRef
        LEFT JOIN work.dbo._Reference123 AS cl WITH (NOLOCK)
            ON cl._IDRRef = o.ClientRef
        LEFT JOIN work.dbo._Reference162 AS org WITH (NOLOCK)
            ON org._IDRRef = o.CompanyRef
        LEFT JOIN work.dbo._Reference304 AS pr WITH (NOLOCK)
            ON pr._IDRRef = o.RouteRef
        LEFT JOIN work.dbo._Reference271 AS cg WITH (NOLOCK)
            ON cg._IDRRef = o.CargoGroupRef;

        ------------------------------------------------------------
        -- 4. Очищаем снимок и заливаем новый
        ------------------------------------------------------------
        TRUNCATE TABLE pbi.t_JuiceTrailerTimeline;

        ;WITH dedup AS (
            SELECT *,
                ROW_NUMBER() OVER (
                    PARTITION BY
                        TrailerReff,
                        COALESCE(StartPlan, StartFact, OrderDate),
                        COALESCE(EndFact, EndPlan, OrderDate),
                        RouteReff
                    ORDER BY
                        CASE WHEN OrderNo LIKE N'БО%' OR OrderNo LIKE N'BO%' THEN 2 ELSE 1 END,
                        OrderDate,
                        OrderNo
                ) AS DedupRn
            FROM #Base
        ),
        seq AS (
            SELECT *,
                ROW_NUMBER() OVER (
                    PARTITION BY TrailerReff
                    ORDER BY EndFact, StartFact, OrderNo
                ) AS Seq
            FROM dedup
            WHERE DedupRn = 1
        ),
        flags AS (
            SELECT *,
                CASE WHEN CargoGroupName = N'Сік/концентрат/аромати' THEN 1 ELSE 0 END AS IsJuice,
                CASE WHEN CargoGroupName IN (N'Інші харчові', N'Олія/олійні продукти/жири')
                     THEN 1 ELSE 0 END AS IsYellow,
                CASE
                    WHEN CargoGroupName IS NULL OR CargoGroupName = N'' THEN 1
                    WHEN CargoGroupName NOT IN (
                        N'Сік/концентрат/аромати',
                        N'Патока/Меляса/Глюкоза',
                        N'Вино/виноматеріали',
                        N'Молочна група'
                    ) THEN 1
                    ELSE 0
                END AS IsRed
            FROM seq
        ),
        windowed AS (
            SELECT *,
                MAX(IsJuice) OVER (
                    PARTITION BY TrailerReff
                    ORDER BY Seq
                    ROWS BETWEEN 3 PRECEDING AND 3 FOLLOWING
                ) AS HasJuiceWithin3,
                MAX(IsJuice) OVER (
                    PARTITION BY TrailerReff
                    ORDER BY Seq
                    ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
                ) AS IsJuiceNeighbor,
                SUM(IsJuice) OVER (PARTITION BY TrailerReff) AS JuiceCount
            FROM flags
        )
        INSERT INTO pbi.t_JuiceTrailerTimeline (
            TrailerReff, TrailerName, TractorName, Seq, DisplaySeq,
            OrderNo, OrderDate, StartPlan, EndPlan, StartFact, EndFact,
            PeriodStart, PeriodEnd, ClientName, CompanyName, RouteName,
            CargoGroupName, IsJuice, ColorFlag, JuiceCount
        )
        SELECT
            TrailerReff,
            TrailerName,
            TractorName,
            Seq,
            ROW_NUMBER() OVER (PARTITION BY TrailerReff ORDER BY Seq) AS DisplaySeq,
            OrderNo,
            OrderDate,
            StartPlan,
            EndPlan,
            StartFact,
            EndFact,
            COALESCE(StartFact, StartPlan) AS PeriodStart,
            EndFact                        AS PeriodEnd,
            ClientName,
            CompanyName,
            RouteName,
            CargoGroupName,
            IsJuice,
            CASE
                WHEN IsJuice = 1 THEN N'green'
                WHEN IsJuiceNeighbor = 1 AND IsYellow = 1 THEN N'yellow'
                WHEN IsJuiceNeighbor = 1 AND IsRed = 1 THEN N'red'
                ELSE NULL
            END AS ColorFlag,
            JuiceCount
        FROM windowed
        WHERE HasJuiceWithin3 = 1;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
END
GO
