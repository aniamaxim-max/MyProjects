-- exec pbi.GetFuelingIssues

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'GetFuelingIssues' AND SCHEMA_NAME(schema_id) = 'pbi')
    DROP PROCEDURE pbi.GetFuelingIssues;
GO

CREATE PROCEDURE pbi.GetFuelingIssues
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LastDate  DATE = DATEADD(DAY, -5, CAST(GETDATE() AS DATE));
    DECLARE @FirstDate DATE = DATEADD(MONTH, -4, @LastDate);

    SELECT
        c._Description                          AS [Організація],
        FORMAT(f.[Period], 'dd.MM.yyyy')          AS [Дата заправки],
        d.Number                               AS [Номер документу],
        t.LegalNum                            AS [Транспортний засіб],
        cnt.CountryName                         AS [Країна],
        gs.GasStationName                       AS [АЗС],
        f.Quantity                              AS [Кількість, л],
        f.ManagementAmount                      AS [Сума, євро],
        f.ManagementVAT                         AS [ПДВ, євро]
    FROM pbi.vb_Fueling f
    LEFT JOIN work.dbo._Reference162 c
        ON c._IDRRef = f.CompanyRef
    LEFT JOIN pbi.vb_DimTrucks t
        ON t.TruckReff = f.TruckRef
    LEFT JOIN pbi.vb_DimCountry cnt
        ON cnt.CountryRef = f.CountryRef
    LEFT JOIN pbi.vb_DimGasStation gs
        ON gs.GasStationRef = f.GasStationRef
    LEFT JOIN pbi.vb_FuelingDocuments d
        ON d.IDRef = f.IDRef
    WHERE f.FuelRef = 0x9438B52C1CA5BDB511E67F079576A5AA
      AND f.Period BETWEEN @FirstDate AND @LastDate
      AND (
          (f.CompanyRef = 0x9615A4875CF5B4BC11E654B43D80BD63 AND f.ManagementVAT = 0)
          -- ТИМЧАСОВО вимкнено: заправки по «Стеллар МВ, ТОВ»
          /* OR
          (f.CompanyRef = 0x86F7D6671738F3EC11E65341D132A9CC AND (
               (cnt.CountryName IN (
                    N'Австрія', N'Австрия', N'AT',
                    N'Бельгія', N'Бельгия', N'BE',
                    N'Люксембург', N'LU',
                    N'Нідерланди', N'Нидерланды', N'NL',
                    N'Франція', N'Франция', N'FR',
                    N'Швеція', N'Швеция', N'SE',
                    N'Болгарія', N'Болгария', N'BG',
                    N'Італія', N'Италия', N'IT',
                    N'Україна', N'Украина', N'UA'
               ) AND f.ManagementVAT = 0)
               OR
               (cnt.CountryName NOT IN (
                    N'Австрія', N'Австрия', N'AT',
                    N'Бельгія', N'Бельгия', N'BE',
                    N'Люксембург', N'LU',
                    N'Нідерланди', N'Нидерланды', N'NL',
                    N'Франція', N'Франция', N'FR',
                    N'Швеція', N'Швеция', N'SE',
                    N'Болгарія', N'Болгария', N'BG',
                    N'Італія', N'Италия', N'IT',
                    N'Україна', N'Украина', N'UA'
               ) AND f.ManagementVAT <> 0)
          ))
          */
      )
    ORDER BY [Організація], f.[Period];
END
GO
