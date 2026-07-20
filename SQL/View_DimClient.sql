-- SELECT * FROM pbi.v_DimClient
-- SELECT * FROM pbi.vb_DimClient

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'v_DimClient' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_DimClient;
GO

CREATE VIEW pbi.v_DimClient AS
SELECT
    CONVERT(VARCHAR(MAX), _IDRRef, 2)                     AS ClientRef,
    LTRIM(RTRIM(_Code))                                   AS ClientCode,
    _Description                                          AS ClientName,
    LTRIM(RTRIM(_Fld2160))                                AS EDRPOU,
    _Fld2143                                              AS FullName,
    _Fld2148                                              AS INN,
    _Fld34260                                             AS NIP,
    _Fld2166                                              AS NameEnglish,
    CAST(_Fld2162 AS BIT)                                 AS IsNonResident,
    CONVERT(VARCHAR(MAX), _Fld2146RRef, 2)                AS MainClientRef,
    CAST(_Marked AS BIT)                                  AS DeleteMark,
    CAST(CASE
        WHEN _ParentIDRRef = 0x835ABA8F5A3507C811E71B9603D3340F
         AND _IDRRef NOT IN (
            0xAC48F99E1751E73F11E98C40077D0C31,
            0xACEFD32FEC9A2DE011E680D1C3DF19FA,
            0x901C02B31CC3E40111EE903B881D8410,
            0x87D202B31CC3E40111EC40A0C4F0FFD9
         ) THEN 1 ELSE 0 END AS BIT)                     AS InnerClient
FROM work.dbo._Reference123;
GO

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'vb_DimClient' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_DimClient;
GO

CREATE VIEW pbi.vb_DimClient AS
SELECT
    _IDRRef                                               AS ClientRef,
    LTRIM(RTRIM(_Code))                                   AS ClientCode,
    _Description                                          AS ClientName,
    LTRIM(RTRIM(_Fld2160))                                AS EDRPOU,
    _Fld2143                                              AS FullName,
    _Fld2148                                              AS INN,
    _Fld34260                                             AS NIP,
    _Fld2166                                              AS NameEnglish,
    _Fld2162                                              AS IsNonResident,
    _Fld2146RRef                                          AS MainClientRef,
    _Marked                                               AS DeleteMark,
    CAST(CASE
        WHEN _ParentIDRRef = 0x835ABA8F5A3507C811E71B9603D3340F
         AND _IDRRef NOT IN (
            0xAC48F99E1751E73F11E98C40077D0C31,
            0xACEFD32FEC9A2DE011E680D1C3DF19FA,
            0x901C02B31CC3E40111EE903B881D8410,
            0x87D202B31CC3E40111EC40A0C4F0FFD9
         ) THEN 1 ELSE 0 END AS BIT)                     AS InnerClient
FROM work.dbo._Reference123;
GO
