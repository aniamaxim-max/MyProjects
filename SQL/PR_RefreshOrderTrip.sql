-- exec work.pbi.RefreshOrderTrip
-- select * from pbi.OrderTrip
-- =============================================================================
-- Процедура pbi.RefreshOrderTrip — пересчёт кругорейсов и заполнение pbi.OrderTrip
--
-- Правила:
--   * прицеп из DimTrucks: Стеллар -> дом UA, Трімекс -> дом PL;
--   * международный: HA/AA начинают, AH закрывает, HH закрывает открытый рейс;
--     лимиты: разрыв <= 30 дней, длительность <= 60 дней;
--   * украинский: Інтерстарч + максимум 2 следующих UA->UA заказа,
--     разрыв <= 30 дней, длительность <= 30 дней от Інтерстарч;
--   * Ейр Продактс / Лінде Газ: імпорт (AH) + наступний 1 HH — один кругорейс;
--   * остальные HH: короткие (StartPlan=EndPlan, в один день) — один кругорейс
--     на день завершения (EndFact); длинные (>1 дня) — каждый отдельный кругорейс;
--   * неизвестный маршрут / "Маршрут в розробці" -> без TripNo;
--   * TripNo глобальный 1..N по дате завершения рейса.
-- =============================================================================

IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'RefreshOrderTrip' AND SCHEMA_NAME(schema_id) = 'pbi')
    DROP PROCEDURE pbi.RefreshOrderTrip;
GO

CREATE PROCEDURE pbi.RefreshOrderTrip
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Stellar     binary(16) = 0x86F7D6671738F3EC11E65341D132A9CC;
    DECLARE @Trimex      binary(16) = 0x9615A4875CF5B4BC11E654B43D80BD63;
    DECLARE @Interstarch varchar(32) = 'ACEFD32FEC9A2DE011E680D1BDE4569E';
    DECLARE @ClientLinde        varchar(32) = 'ACEFD32FEC9A2DE011E680D1BDE456FD';  -- Лінде Газ Україна ПрАТ
    DECLARE @ClientAirProducts  varchar(32) = '8CA1D8710025B9B611EB8C7FDCE23E90';  -- ЕЙР ПРОДАКТС УКРАЇНА ТОВ
    DECLARE @DraftRoute  binary(16) = 0xB8D4899CCA59332411E686274F7DF155;
    DECLARE @ZeroRef     binary(16) = 0x00000000000000000000000000000000;

    -- 1. База: заказы на прицепах Стеллар/Трімекс
    IF OBJECT_ID('tempdb..#Base') IS NOT NULL DROP TABLE #Base;

    ;WITH CompanyLast AS
    (
        SELECT
            i._Fld23489RRef AS TruckRef,
            i._Fld23490RRef AS CompanyRef,
            ROW_NUMBER() OVER (PARTITION BY i._Fld23489RRef ORDER BY i._Period DESC) AS rn
        FROM work.dbo._InfoRg23488 i
    ),
    Raw AS
    (
        SELECT
            CONVERT(varchar(32), d._IDRRef, 2) AS OrderRef,
            LTRIM(RTRIM(d._Number)) AS OrderNo,

            IIF(d._Date_Time >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, d._Date_Time), NULL) AS OrderDate,
            IIF(d._Fld17682  >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, d._Fld17682),  NULL) AS StartPlan,
            IIF(d._Fld17683  >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, d._Fld17683),  NULL) AS EndPlan,
            IIF(d._Fld17716  >  DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, d._Fld17716),  NULL) AS StartFact,
            IIF(d._Fld27200  >  DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, d._Fld27200),  NULL) AS EndFact,

            CONVERT(varchar(32), d._Fld17704_RRRef, 2) AS TrailerRef,
            RTRIM(tn._Fld23607) AS TrailerName,
            CONVERT(varchar(32), c.CompanyRef, 2) AS TrailerCompanyRef,
            org._Description AS TrailerCompany,
            CASE
                WHEN c.CompanyRef = @Stellar THEN 'UA'
                WHEN c.CompanyRef = @Trimex  THEN 'PL'
            END AS HomeCountry,

            CONVERT(varchar(32), d._Fld17681_RRRef, 2) AS ClientRef,
            cl._Description AS ClientName,

            LTRIM(RTRIM(cf._Description)) AS CountryFrom,
            LTRIM(RTRIM(cw._Description)) AS CountryWhere,
            r._Description AS RouteName,

            CASE
                WHEN d._Fld17700RRef = @ZeroRef
                  OR d._Fld17700RRef = @DraftRoute
                  OR r._IDRRef IS NULL
                  OR cf._IDRRef IS NULL
                  OR cw._IDRRef IS NULL
                THEN 1 ELSE 0
            END AS IsUnknown
        FROM work.dbo._Document650 d
        INNER JOIN CompanyLast c
            ON c.TruckRef = d._Fld17704_RRRef AND c.rn = 1
        LEFT JOIN work.dbo._InfoRg23603 tn
            ON tn._Fld23604RRef = d._Fld17704_RRRef
        LEFT JOIN work.dbo._Reference162 org
            ON org._IDRRef = c.CompanyRef
        LEFT JOIN work.dbo._Reference123 cl
            ON cl._IDRRef = d._Fld17681_RRRef
        LEFT JOIN work.dbo._Reference304 r
            ON r._IDRRef = d._Fld17700RRef
        LEFT JOIN work.dbo._Reference299 pf
            ON pf._IDRRef = r._Fld3888RRef
        LEFT JOIN work.dbo._Reference299 pw
            ON pw._IDRRef = r._Fld3889RRef
        LEFT JOIN work.dbo._Reference111 cf
            ON cf._IDRRef = pf._Fld3854RRef
        LEFT JOIN work.dbo._Reference111 cw
            ON cw._IDRRef = pw._Fld3854RRef
        WHERE d._Posted = 0x01
          AND d._Marked = 0x00
          AND d._Fld32970 = 0x00
          AND d._Fld17704_RRRef <> @ZeroRef
          AND d._Fld17685RRef NOT IN (
                  0xA0C10503CE54D6E848C4F4190A4E05BC,  -- Отказано клиентом
                  0xB7CC74CE4579F3A7446ED6CC7227830A   -- Отказано
              )
          AND c.CompanyRef IN (@Stellar, @Trimex)
    ),
    Raw2 AS
    (
        SELECT
            *,
            CASE
                WHEN EndFact IS NULL
                    THEN COALESCE(
                             CASE
                                 WHEN EndPlan IS NOT NULL
                                  AND (StartPlan IS NULL OR EndPlan >= StartPlan)
                                 THEN EndPlan
                             END,
                             StartPlan, OrderDate
                         )
                WHEN (StartPlan IS NULL OR EndFact >= DATEADD(day, -90, StartPlan))
                 AND (EndPlan IS NULL OR EndPlan < StartPlan OR EndFact <= DATEADD(day, 90, EndPlan))
                    THEN EndFact
                WHEN EndPlan IS NOT NULL AND (StartPlan IS NULL OR EndPlan >= StartPlan)
                    THEN EndPlan
                ELSE COALESCE(StartPlan, OrderDate, EndFact)
            END AS SortDate
        FROM Raw
    )
    SELECT
        OrderRef, OrderNo, OrderDate, StartPlan, EndPlan, StartFact, EndFact,
        SortDate,

        TrailerRef, TrailerName, TrailerCompanyRef, TrailerCompany, HomeCountry,
        ClientRef, ClientName, CountryFrom, CountryWhere, RouteName, IsUnknown,

        CASE
            WHEN IsUnknown = 1 THEN 'U'
            WHEN CountryFrom = HomeCountry AND CountryWhere = HomeCountry THEN 'HH'
            WHEN CountryFrom = HomeCountry THEN 'HA'
            WHEN CountryWhere = HomeCountry THEN 'AH'
            ELSE 'AA'
        END AS Dir
    INTO #Base
    FROM Raw2;

    -- 2. Последовательность (без неизвестных маршрутов)
    IF OBJECT_ID('tempdb..#Seq') IS NOT NULL DROP TABLE #Seq;

    SELECT
        b.*,
        ROW_NUMBER() OVER (
            ORDER BY
                b.TrailerRef,
                COALESCE(b.SortDate, CAST('9999-12-31' AS datetime2)),
                b.EndPlan,
                b.StartPlan,
                b.OrderDate,
                b.OrderNo,
                b.OrderRef
        ) AS rn
    INTO #Seq
    FROM #Base b
    WHERE b.IsUnknown = 0;

    CREATE CLUSTERED INDEX IX_Seq ON #Seq (TrailerRef, rn);

    -- 3. Курсор: международные рейсы + украинские цепочки
    IF OBJECT_ID('tempdb..#Trips') IS NOT NULL DROP TABLE #Trips;
    IF OBJECT_ID('tempdb..#OrderTrip') IS NOT NULL DROP TABLE #OrderTrip;

    CREATE TABLE #Trips
    (
        TripId    int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        TripKind  char(4) NOT NULL,   -- 'Intl' / 'Dom'
        TrailerRef varchar(32) NOT NULL
    );

    CREATE TABLE #OrderTrip
    (
        OrderRef varchar(32) NOT NULL PRIMARY KEY,
        TripId   int NOT NULL,
        TripKind char(4) NOT NULL
    );

    DECLARE
        @OrderRef     varchar(32),
        @TrailerRef   varchar(32),
        @SortDate     datetime2(0),
        @Dir          char(2),
        @CountryFrom  char(3),
        @CountryWhere char(3),
        @ClientRef    varchar(32),
        @StartPlan    datetime2(0),
        @EndPlan      datetime2(0);

    DECLARE
        @CurTrailer  varchar(32) = NULL,
        @IntlId      int         = NULL,
        @IntlStart   datetime2(0)= NULL,
        @IntlPrev    datetime2(0)= NULL,
        @DomId       int         = NULL,
        @DomStart    datetime2(0)= NULL,
        @DomPrev     datetime2(0)= NULL,
        @DomFollow   int         = 0,
        @PendingImportTrip int   = NULL,
        @ShortGroupId int        = NULL,
        @ShortGroupDay date      = NULL,
        @NewId       int;

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT OrderRef, TrailerRef, SortDate, Dir, CountryFrom, CountryWhere, ClientRef, StartPlan, EndPlan
        FROM #Seq
        ORDER BY TrailerRef, rn;

    OPEN cur;
    FETCH NEXT FROM cur INTO @OrderRef, @TrailerRef, @SortDate, @Dir, @CountryFrom, @CountryWhere, @ClientRef, @StartPlan, @EndPlan;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- новый прицеп -> сброс состояния
        IF @CurTrailer IS NULL OR @CurTrailer <> @TrailerRef
        BEGIN
            SET @CurTrailer = @TrailerRef;

            SET @IntlId    = NULL;
            SET @IntlStart = NULL;
            SET @IntlPrev  = NULL;

            SET @DomId     = NULL;
            SET @DomStart  = NULL;
            SET @DomPrev   = NULL;
            SET @DomFollow = 0;

            SET @PendingImportTrip = NULL;

            SET @ShortGroupId = NULL;
            SET @ShortGroupDay = NULL;
        END;

        -- правило Ейр Продактс / Лінде Газ: імпорт (AH) + наступний 1 HH
        IF @PendingImportTrip IS NOT NULL AND @Dir <> 'HH'
        BEGIN
            SET @PendingImportTrip = NULL;
        END;

        -- лимиты международного рейса
        IF @IntlId IS NOT NULL
           AND @SortDate IS NOT NULL
           AND (
                (@IntlPrev IS NOT NULL AND DATEDIFF(day, @IntlPrev, @SortDate) > 30)
                OR
                (@IntlStart IS NOT NULL AND DATEDIFF(day, @IntlStart, @SortDate) > 60)
           )
        BEGIN
            SET @IntlId    = NULL;
            SET @IntlStart = NULL;
            SET @IntlPrev  = NULL;
        END;

        -- лимиты украинской цепочки
        IF @DomId IS NOT NULL
           AND @SortDate IS NOT NULL
           AND (
                (@DomPrev IS NOT NULL AND DATEDIFF(day, @DomPrev, @SortDate) > 30)
                OR
                (@DomStart IS NOT NULL AND DATEDIFF(day, @DomStart, @SortDate) > 30)
           )
        BEGIN
            SET @DomId     = NULL;
            SET @DomStart  = NULL;
            SET @DomPrev   = NULL;
            SET @DomFollow = 0;
        END;

        IF @Dir IN ('HA', 'AA', 'AH')
        BEGIN
            -- международный заказ разрывает украинскую цепочку
            SET @DomId     = NULL;
            SET @DomStart  = NULL;
            SET @DomPrev   = NULL;
            SET @DomFollow = 0;

            SET @ShortGroupId = NULL;
            SET @ShortGroupDay = NULL;

            IF @Dir = 'HA'
            BEGIN
                SET @IntlId    = NULL;
                SET @IntlStart = NULL;
                SET @IntlPrev  = NULL;

                INSERT INTO #Trips (TripKind, TrailerRef) VALUES ('Intl', @TrailerRef);
                SET @NewId = CAST(SCOPE_IDENTITY() AS int);

                SET @IntlId    = @NewId;
                SET @IntlStart = @SortDate;
            END
            ELSE IF @Dir = 'AA'
            BEGIN
                IF @IntlId IS NULL
                BEGIN
                    INSERT INTO #Trips (TripKind, TrailerRef) VALUES ('Intl', @TrailerRef);
                    SET @NewId = CAST(SCOPE_IDENTITY() AS int);

                    SET @IntlId    = @NewId;
                    SET @IntlStart = @SortDate;
                END
            END
            ELSE -- AH
            BEGIN
                IF @IntlId IS NULL
                BEGIN
                    INSERT INTO #Trips (TripKind, TrailerRef) VALUES ('Intl', @TrailerRef);
                    SET @NewId = CAST(SCOPE_IDENTITY() AS int);

                    SET @IntlId    = @NewId;
                    SET @IntlStart = @SortDate;
                END
            END;

            INSERT INTO #OrderTrip (OrderRef, TripId, TripKind)
            VALUES (@OrderRef, @IntlId, 'Intl');

            SET @IntlPrev = @SortDate;

            IF @Dir = 'AH'
            BEGIN
                IF @ClientRef IN (@ClientLinde, @ClientAirProducts)
                BEGIN
                    SET @PendingImportTrip = @IntlId;
                END;

                SET @IntlId    = NULL;
                SET @IntlStart = NULL;
                SET @IntlPrev  = NULL;
            END
        END
        ELSE -- HH
        BEGIN
            -- Ейр Продактс / Лінде Газ: приклеюємо наступний 1 HH до імпорту
            IF @PendingImportTrip IS NOT NULL
            BEGIN
                INSERT INTO #OrderTrip (OrderRef, TripId, TripKind)
                VALUES (@OrderRef, @PendingImportTrip, 'Intl');

                SET @PendingImportTrip = NULL;

                SET @ShortGroupId = NULL;
                SET @ShortGroupDay = NULL;
            END
            ELSE
            BEGIN
                -- домашний заказ закрывает открытый международный рейс
                IF @IntlId IS NOT NULL
                BEGIN
                    SET @IntlId    = NULL;
                    SET @IntlStart = NULL;
                    SET @IntlPrev  = NULL;
                END;

                IF @CountryFrom = 'UA' AND @CountryWhere = 'UA'
                BEGIN
                    IF @ClientRef = @Interstarch
                    BEGIN
                        SET @ShortGroupId = NULL;
                        SET @ShortGroupDay = NULL;

                        INSERT INTO #Trips (TripKind, TrailerRef) VALUES ('Dom', @TrailerRef);
                        SET @NewId = CAST(SCOPE_IDENTITY() AS int);

                        SET @DomId     = @NewId;
                        SET @DomStart  = @SortDate;
                        SET @DomPrev   = @SortDate;
                        SET @DomFollow = 0;

                        INSERT INTO #OrderTrip (OrderRef, TripId, TripKind)
                        VALUES (@OrderRef, @DomId, 'Dom');
                    END
                    ELSE IF @DomId IS NOT NULL AND @DomFollow < 2
                    BEGIN
                        SET @ShortGroupId = NULL;
                        SET @ShortGroupDay = NULL;

                        INSERT INTO #OrderTrip (OrderRef, TripId, TripKind)
                        VALUES (@OrderRef, @DomId, 'Dom');

                        SET @DomFollow = @DomFollow + 1;
                        SET @DomPrev   = @SortDate;

                        IF @DomFollow >= 2
                        BEGIN
                            SET @DomId     = NULL;
                            SET @DomStart  = NULL;
                            SET @DomPrev   = NULL;
                            SET @DomFollow = 0;
                        END
                    END
                    ELSE
                    BEGIN
                        SET @DomId     = NULL;
                        SET @DomStart  = NULL;
                        SET @DomPrev   = NULL;
                        SET @DomFollow = 0;

                        -- оставшиеся HH: короткие группируем по дню завершения,
                        -- длинные — каждый отдельным кругорейсом
                        IF @StartPlan IS NOT NULL AND @EndPlan IS NOT NULL
                           AND CAST(@StartPlan AS date) = CAST(@EndPlan AS date)
                        BEGIN
                            IF @ShortGroupId IS NULL
                               OR @ShortGroupDay IS NULL
                               OR @ShortGroupDay <> CAST(@SortDate AS date)
                            BEGIN
                                INSERT INTO #Trips (TripKind, TrailerRef) VALUES ('Dom', @TrailerRef);
                                SET @NewId = CAST(SCOPE_IDENTITY() AS int);

                                SET @ShortGroupId  = @NewId;
                                SET @ShortGroupDay = CAST(@SortDate AS date);
                            END;

                            INSERT INTO #OrderTrip (OrderRef, TripId, TripKind)
                            VALUES (@OrderRef, @ShortGroupId, 'Dom');
                        END
                        ELSE
                        BEGIN
                            SET @ShortGroupId  = NULL;
                            SET @ShortGroupDay = NULL;

                            INSERT INTO #Trips (TripKind, TrailerRef) VALUES ('Dom', @TrailerRef);
                            SET @NewId = CAST(SCOPE_IDENTITY() AS int);

                            INSERT INTO #OrderTrip (OrderRef, TripId, TripKind)
                            VALUES (@OrderRef, @NewId, 'Dom');
                        END
                    END
                END
                ELSE
                BEGIN
                    -- PL->PL и прочее: украинской цепочки нет
                    SET @DomId     = NULL;
                    SET @DomStart  = NULL;
                    SET @DomPrev   = NULL;
                    SET @DomFollow = 0;

                    SET @ShortGroupId = NULL;
                    SET @ShortGroupDay = NULL;
                END
            END
        END;

        FETCH NEXT FROM cur INTO @OrderRef, @TrailerRef, @SortDate, @Dir, @CountryFrom, @CountryWhere, @ClientRef, @StartPlan, @EndPlan;
    END;

    CLOSE cur;
    DEALLOCATE cur;

    -- 4. Сводка по рейсам + глобальная нумерация
    IF OBJECT_ID('tempdb..#TripSum') IS NOT NULL DROP TABLE #TripSum;

    SELECT
        t.TripId,
        t.TripKind,
        t.TrailerRef,
        MIN(s.SortDate) AS TripStart,
        MAX(s.SortDate) AS TripEnd,
        MIN(s.rn)       AS FirstRn
    INTO #TripSum
    FROM #Trips t
    INNER JOIN #OrderTrip ot ON ot.TripId = t.TripId
    INNER JOIN #Seq s        ON s.OrderRef = ot.OrderRef
    GROUP BY t.TripId, t.TripKind, t.TrailerRef;

    ALTER TABLE #TripSum ADD TripNo int NULL;

    ;WITH Numbered AS
    (
        SELECT
            TripId,
            ROW_NUMBER() OVER (
                ORDER BY TripEnd, TrailerRef, TripStart, FirstRn, TripId
            ) AS TripNo
        FROM #TripSum
    )
    UPDATE ts
    SET ts.TripNo = n.TripNo
    FROM #TripSum ts
    INNER JOIN Numbered n ON n.TripId = ts.TripId;

    -- 5. Запись в таблицу
    DECLARE @RowsWritten int;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM pbi.OrderTrip;

        INSERT INTO pbi.OrderTrip
        (
            OrderRef, TripNo, TripType, TrailerRef, TrailerName, TrailerCompany,
            TripStart, TripEnd, CalculatedAt
        )
        SELECT
            b.OrderRef,
            ts.TripNo,
            CASE ts.TripKind WHEN 'Intl' THEN N'Міжнародний' WHEN 'Dom' THEN N'Український' END,
            b.TrailerRef,
            b.TrailerName,
            b.TrailerCompany,
            ts.TripStart,
            ts.TripEnd,
            SYSUTCDATETIME()
        FROM #Base b
        LEFT JOIN #OrderTrip ot ON ot.OrderRef = b.OrderRef
        LEFT JOIN #TripSum  ts ON ts.TripId   = ot.TripId;

        SET @RowsWritten = @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @RowsWritten AS RowsWritten;
END
GO
