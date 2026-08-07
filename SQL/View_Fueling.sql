-- SELECT * FROM pbi.v_Fueling
-- SELECT * FROM pbi.vb_Fueling
-- SELECT * FROM pbi.v_DimCountry
-- SELECT * FROM pbi.vb_DimCountry
-- SELECT * FROM pbi.v_DimGasStation
-- SELECT * FROM pbi.vb_DimGasStation
-- SELECT * FROM pbi.v_FuelingDocuments
-- SELECT * FROM pbi.vb_FuelingDocuments

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'v_Fueling' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_Fueling;
GO

CREATE VIEW pbi.v_Fueling AS
SELECT
    IIF(_AccumRg26306._Period >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _AccumRg26306._Period), _AccumRg26306._Period) AS Period,
    CONVERT(VARCHAR(MAX), _AccumRg26306._RecorderRRef, 2)                AS IDRef,
    CONVERT(VARCHAR(MAX), _AccumRg26306._Fld26307RRef, 2)                AS CompanyRef,
    CONVERT(VARCHAR(MAX), _AccumRg26306._Fld26308_RRRef, 2)              AS TruckRef,
    CONVERT(VARCHAR(MAX), _AccumRg26306._Fld26309RRef, 2)                AS FuelRef,
    CONVERT(VARCHAR(MAX), _AccumRg26306._Fld26310RRef, 2)                AS CountryRef,
    CONVERT(VARCHAR(MAX), _AccumRg26306._Fld27460RRef, 2)                AS GasStationRef,
    CONVERT(VARCHAR(MAX), _AccumRg26306._Fld27461RRef, 2)                AS FuelMovementTypeRef,
    CONVERT(VARCHAR(MAX), _AccumRg26306._Fld27462RRef, 2)                AS PlasticCardRef,
    CONVERT(VARCHAR(MAX), _AccumRg26306._Fld27463RRef, 2)                AS RouteSheetRef,
    _AccumRg26306._Fld26311                                             AS Quantity,
    _AccumRg26306._Fld26312                                             AS SettlementAmount,
    _AccumRg26306._Fld26313                                             AS VATAmount,
    _AccumRg26306._Fld26314                                             AS ManagementAmount,
    _AccumRg26306._Fld26315                                             AS ManagementVAT,
    _AccumRg26306._Fld26316                                             AS RegulatedAmount,
    _AccumRg26306._Fld26317                                             AS RegulatedVAT
FROM work.dbo._AccumRg26306
WHERE _AccumRg26306._Active = 0x01;
GO

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'vb_Fueling' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_Fueling;
GO

CREATE VIEW pbi.vb_Fueling AS
SELECT
    IIF(_AccumRg26306._Period >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _AccumRg26306._Period), _AccumRg26306._Period) AS Period,
    _AccumRg26306._RecorderRRef                                        AS IDRef,
    _AccumRg26306._Fld26307RRef                                        AS CompanyRef,
    _AccumRg26306._Fld26308_RRRef                                      AS TruckRef,
    _AccumRg26306._Fld26309RRef                                        AS FuelRef,
    _AccumRg26306._Fld26310RRef                                        AS CountryRef,
    _AccumRg26306._Fld27460RRef                                        AS GasStationRef,
    _AccumRg26306._Fld27461RRef                                        AS FuelMovementTypeRef,
    _AccumRg26306._Fld27462RRef                                        AS PlasticCardRef,
    _AccumRg26306._Fld27463RRef                                        AS RouteSheetRef,
    _AccumRg26306._Fld26311                                            AS Quantity,
    _AccumRg26306._Fld26312                                            AS SettlementAmount,
    _AccumRg26306._Fld26313                                            AS VATAmount,
    _AccumRg26306._Fld26314                                            AS ManagementAmount,
    _AccumRg26306._Fld26315                                            AS ManagementVAT,
    _AccumRg26306._Fld26316                                            AS RegulatedAmount,
    _AccumRg26306._Fld26317                                            AS RegulatedVAT
FROM work.dbo._AccumRg26306
WHERE _AccumRg26306._Active = 0x01;
GO

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'v_DimCountry' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_DimCountry;
GO

CREATE VIEW pbi.v_DimCountry AS
SELECT
    CONVERT(VARCHAR(MAX), _IDRRef, 2)     AS CountryRef,
    _Description                          AS CountryName,
    _Fld2088                              AS FullName
FROM work.dbo._Reference111
WHERE _Marked = 0
  AND _Folder = 1;
GO

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'vb_DimCountry' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_DimCountry;
GO

CREATE VIEW pbi.vb_DimCountry AS
SELECT
    _IDRRef                               AS CountryRef,
    _Description                          AS CountryName,
    _Fld2088                              AS FullName
FROM work.dbo._Reference111
WHERE _Marked = 0
  AND _Folder = 1;
GO

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'v_DimGasStation' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_DimGasStation;
GO

CREATE VIEW pbi.v_DimGasStation AS
SELECT
    CONVERT(VARCHAR(MAX), _IDRRef, 2)     AS GasStationRef,
    _Description                          AS GasStationName,
    CONVERT(VARCHAR(MAX), _Fld3563_RRRef, 2) AS ClientStorageRef
FROM work.dbo._Reference264
WHERE _Marked = 0;
GO

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'vb_DimGasStation' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_DimGasStation;
GO

CREATE VIEW pbi.vb_DimGasStation AS
SELECT
    _IDRRef                               AS GasStationRef,
    _Description                          AS GasStationName,
    _Fld3563_RRRef                        AS ClientStorageRef
FROM work.dbo._Reference264
WHERE _Marked = 0;
GO

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'v_FuelingDocuments' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_FuelingDocuments;
GO

CREATE VIEW pbi.v_FuelingDocuments AS
SELECT
    CONVERT(VARCHAR(MAX), _IDRRef, 2)                   AS IDRef,
    _Version                                            AS Version,
    CAST(_Marked AS BIT)                                AS DeleteMark,
    IIF(_Date_Time >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Date_Time), _Date_Time) AS DateTime,
    _NumberPrefix                                       AS NumberPrefix,
    LTRIM(RTRIM(_Number))                               AS Number,
    CAST(_Posted AS BIT)                                AS Posted,
    CONVERT(VARCHAR(MAX), _Fld17995RRef, 2)             AS CompanyRef,
    CONVERT(VARCHAR(MAX), _Fld17996RRef, 2)             AS GasStationRef,
    CONVERT(VARCHAR(MAX), _Fld17997RRef, 2)             AS CountryRef,
    CONVERT(VARCHAR(MAX), _Fld17998RRef, 2)             AS EmployeeRef,
    _Fld17999                                          AS TotalQuantity,
    CONVERT(VARCHAR(MAX), _Fld18000RRef, 2)             AS DepartmentRef,
    CONVERT(VARCHAR(MAX), _Fld18001RRef, 2)             AS OrganizationDepartmentRef,
    CONVERT(VARCHAR(MAX), _Fld18002RRef, 2)             AS ResponsibleRef,
    CAST(_Fld18003 AS BIT)                              AS PostToAccounting,
    CAST(_Fld18004 AS BIT)                              AS PostToManagement,
    CAST(_Fld18005 AS BIT)                              AS AmountIncludesVAT,
    CONVERT(VARCHAR(MAX), _Fld18006RRef, 2)             AS ContractRef,
    _Fld18007                                          AS DocumentAmount,
    _Fld18008                                          AS DocumentQuantity,
    CAST(_Fld18009 AS BIT)                              AS ConsiderVAT,
    CONVERT(VARCHAR(MAX), _Fld18010RRef, 2)             AS FuelMovementTypeRef,
    CONVERT(VARCHAR(MAX), _Fld18011RRef, 2)             AS ColumnRef,
    CONVERT(VARCHAR(MAX), _Fld18012RRef, 2)             AS UTPDocumentRef,
    CONVERT(VARCHAR(MAX), _Fld27357RRef, 2)             AS BaseDocumentRef,
    CAST(_Fld28768 AS BIT)                              AS PostToAccounting_ControlRights,
    CAST(_Fld28769 AS BIT)                              AS PostToManagement_ControlRights,
    _Fld34255                                          AS Comment,
    CONVERT(VARCHAR(MAX), _Fld34608RRef, 2)             AS BaseDocumentRef2
FROM work.dbo._Document654
WHERE _Fld18004 = 0x01;
GO

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'vb_FuelingDocuments' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_FuelingDocuments;
GO

CREATE VIEW pbi.vb_FuelingDocuments AS
SELECT
    _IDRRef                                             AS IDRef,
    _Version                                            AS Version,
    _Marked                                             AS DeleteMark,
    IIF(_Date_Time >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Date_Time), _Date_Time) AS DateTime,
    _NumberPrefix                                       AS NumberPrefix,
    LTRIM(RTRIM(_Number))                               AS Number,
    _Posted                                             AS Posted,
    _Fld17995RRef                                       AS CompanyRef,
    _Fld17996RRef                                       AS GasStationRef,
    _Fld17997RRef                                       AS CountryRef,
    _Fld17998RRef                                       AS EmployeeRef,
    _Fld17999                                          AS TotalQuantity,
    _Fld18000RRef                                       AS DepartmentRef,
    _Fld18001RRef                                       AS OrganizationDepartmentRef,
    _Fld18002RRef                                       AS ResponsibleRef,
    _Fld18003                                          AS PostToAccounting,
    _Fld18004                                          AS PostToManagement,
    _Fld18005                                          AS AmountIncludesVAT,
    _Fld18006RRef                                       AS ContractRef,
    _Fld18007                                          AS DocumentAmount,
    _Fld18008                                          AS DocumentQuantity,
    _Fld18009                                          AS ConsiderVAT,
    _Fld18010RRef                                       AS FuelMovementTypeRef,
    _Fld18011RRef                                       AS ColumnRef,
    _Fld18012RRef                                       AS UTPDocumentRef,
    _Fld27357RRef                                       AS BaseDocumentRef,
    _Fld28768                                          AS PostToAccounting_ControlRights,
    _Fld28769                                          AS PostToManagement_ControlRights,
    _Fld34255                                          AS Comment,
    _Fld34608RRef                                       AS BaseDocumentRef2
FROM work.dbo._Document654
WHERE _Fld18004 = 0x01;
GO
