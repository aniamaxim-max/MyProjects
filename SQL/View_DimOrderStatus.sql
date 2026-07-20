-- SELECT * FROM pbi.v_DimOrderStatus
-- SELECT * FROM pbi.vb_DimOrderStatus

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'v_DimOrderStatus' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_DimOrderStatus;
GO

CREATE VIEW pbi.v_DimOrderStatus AS
SELECT
    CONVERT(VARCHAR(MAX), _IDRRef, 2)                     AS StatusRef,
    _EnumOrder                                            AS EnumOrder,
    CAST(CASE _EnumOrder
        WHEN 0 THEN N'Підготовлено'
        WHEN 1 THEN N'На узгодженні'
        WHEN 2 THEN N'Завершено'
        WHEN 3 THEN N'В роботі'
        WHEN 4 THEN N'На виконанні'
        WHEN 5 THEN N'Проведено'
        WHEN 6 THEN N'Відмовлено клієнтом'
        WHEN 7 THEN N'В роботі 2'
        WHEN 8 THEN N'Відмовлено'
        WHEN 9 THEN N'Закрито-План'
        WHEN 10 THEN N'Закрито-План (експедиція)'
        WHEN 11 THEN N'Закрито-План (власний)'
        WHEN 12 THEN N'Очікується CMR/Акти'
        WHEN 13 THEN N'Закрито факт'
        WHEN 14 THEN N'Закрито факт (експедиція)'
        WHEN 15 THEN N'Виконано'
        WHEN 16 THEN N'Рознесено'
        WHEN 17 THEN N'Перепроведено'
        WHEN 18 THEN N'Готово'
        WHEN 19 THEN N'Узгоджено'
        WHEN 20 THEN N'Закрито-План (на нашому транспорті)'
    END AS NVARCHAR(60))                                  AS StatusName
FROM work.dbo._Enum26798;
GO

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'vb_DimOrderStatus' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_DimOrderStatus;
GO

CREATE VIEW pbi.vb_DimOrderStatus AS
SELECT
    _IDRRef                                               AS StatusRef,
    _EnumOrder                                            AS EnumOrder,
    CAST(CASE _EnumOrder
        WHEN 0 THEN N'Підготовлено'
        WHEN 1 THEN N'На узгодженні'
        WHEN 2 THEN N'Завершено'
        WHEN 3 THEN N'В роботі'
        WHEN 4 THEN N'На виконанні'
        WHEN 5 THEN N'Проведено'
        WHEN 6 THEN N'Відмовлено клієнтом'
        WHEN 7 THEN N'В роботі 2'
        WHEN 8 THEN N'Відмовлено'
        WHEN 9 THEN N'Закрито-План'
        WHEN 10 THEN N'Закрито-План (експедиція)'
        WHEN 11 THEN N'Закрито-План (власний)'
        WHEN 12 THEN N'Очікується CMR/Акти'
        WHEN 13 THEN N'Закрито факт'
        WHEN 14 THEN N'Закрито факт (експедиція)'
        WHEN 15 THEN N'Виконано'
        WHEN 16 THEN N'Рознесено'
        WHEN 17 THEN N'Перепроведено'
        WHEN 18 THEN N'Готово'
        WHEN 19 THEN N'Узгоджено'
        WHEN 20 THEN N'Закрито-План (на нашому транспорті)'
    END AS NVARCHAR(60))                                  AS StatusName
FROM work.dbo._Enum26798;
GO
