--select * from pbi.v_PivotRoute order by CountryFrom
--select * from pbi.vb_PivotRoute order by CountryFrom

--select * from pbi.v_Point
--select * from pbi.vb_Point

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_PivotRoute' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_PivotRoute
GO

Create view pbi.v_PivotRoute AS
select 
	CONVERT(VARCHAR(MAX), PR._IDRRef, 2) as PivotRouteRef,
	PR._Description as PivotRouteName,
	PR._Fld3888RRef as PointFrom,
	PR._Fld3889RRef as PointWhere,
	PF.CountryName as CountryFrom,
	PW.CountryName as CountryWhere,
	CASE
		WHEN (PF.CountryName = 'Україна' OR PF.CountryName = 'Європа') AND PW.CountryName = 'Україна' THEN 'Україна'
		WHEN PF.CountryName <> 'Україна' AND PW.CountryName <> 'Україна' THEN 'Європа'
		WHEN PF.CountryName = 'Україна' AND PW.CountryName <> 'Україна' THEN 'Експорт'
		WHEN (PF.CountryName <> 'Україна' AND PF.CountryName <> 'Європа') AND PW.CountryName = 'Україна' THEN 'Імпорт'
		ELSE 'Україна'
	END as RouteType,
	CASE
		WHEN PF.CountryName = 'Польща' AND PW.CountryName = 'Польща' THEN 'Польща'
		WHEN PF.CountryName <> 'Польща' AND PW.CountryName <> 'Польща' THEN 'Європа'
		WHEN PF.CountryName = 'Польща' AND PW.CountryName <> 'Польща' THEN 'Експорт'
		WHEN PF.CountryName <> 'Польща' AND PW.CountryName = 'Польща' THEN 'Імпорт'
		ELSE 'Польща'
	END as RouteTypeTrimex
from _Reference304 PR
inner join pbi.v_Point PF ON PF.PointRef = PR._Fld3888RRef
inner join pbi.v_Point PW ON PW.PointRef = PR._Fld3889RRef
where CAST(PR._Marked AS BIT) = 0
and CAST(PR._Folder AS BIT) = 1


GO


IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_Point' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_Point
GO

Create view pbi.v_Point AS
    select 
        PR._IDRRef as PointRef,
        PR._Description as PointName,
        C._Description as CountryName,
        CONVERT(VARCHAR(36), PR._Fld3853RRef, 2) as TypeRef,
        CASE 
            WHEN CONVERT(VARCHAR(36), PR._Fld3853RRef, 2) = 'B6F8FF047F4959FB48398FBFA5E4A191' then 'Город'
            WHEN CONVERT(VARCHAR(36), PR._Fld3853RRef, 2) = 'BDF15374BD28ADAA407BA956B9EA04CB' then 'Село'
			WHEN CONVERT(VARCHAR(36), PR._Fld3853RRef, 2) = '914D55B1B7E3761E40148D91495C6B9A' then 'Погранперехід'
			WHEN CONVERT(VARCHAR(36), PR._Fld3853RRef, 2) = 'B3FA76702F4D9AEC4428207C824E36F6' then 'Село'
			WHEN CONVERT(VARCHAR(36), PR._Fld3853RRef, 2) = 'B6FE80F53D2689E142B0D48EEC962652' then 'Село'
			WHEN CONVERT(VARCHAR(36), PR._Fld3853RRef, 2) = '92D9CB11D21C4BA840D4DAE3570E0A27' then 'Адрес'
			WHEN CONVERT(VARCHAR(36), PR._Fld3853RRef, 2) = 'AC0D912E53801A93421F41AD81854713' then 'Погранперехід'
            else '1'
        end as PointType
    from _Reference299 PR
    left join _Reference299 C ON C._IDRRef = PR._ParentIDRRef
    where CAST(PR._Marked AS BIT) = 0
    and CAST(PR._Folder AS BIT) = 1
GO

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'vb_PivotRoute' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_PivotRoute
GO

Create view pbi.vb_PivotRoute AS
select 
	PR._IDRRef as PivotRouteRef,
	PR._Description as PivotRouteName,
	PR._Fld3888RRef as PointFrom,
	PR._Fld3889RRef as PointWhere,
	PF.CountryName as CountryFrom,
	PW.CountryName as CountryWhere,
	CASE
		WHEN (PF.CountryName = 'Україна' OR PF.CountryName = 'Європа') AND PW.CountryName = 'Україна' THEN 'Україна'
		WHEN PF.CountryName <> 'Україна' AND PW.CountryName <> 'Україна' THEN 'Європа'
		WHEN PF.CountryName = 'Україна' AND PW.CountryName <> 'Україна' THEN 'Експорт'
		WHEN (PF.CountryName <> 'Україна' AND PF.CountryName <> 'Європа') AND PW.CountryName = 'Україна' THEN 'Імпорт'
		ELSE 'Україна'
	END as RouteType,
	CASE
		WHEN PF.CountryName = 'Польща' AND PW.CountryName = 'Польща' THEN 'Польща'
		WHEN PF.CountryName <> 'Польща' AND PW.CountryName <> 'Польща' THEN 'Європа'
		WHEN PF.CountryName = 'Польща' AND PW.CountryName <> 'Польща' THEN 'Експорт'
		WHEN PF.CountryName <> 'Польща' AND PW.CountryName = 'Польща' THEN 'Імпорт'
		ELSE 'Польща'
	END as RouteTypeTrimex
from _Reference304 PR
inner join pbi.vb_Point PF ON PF.PointRef = PR._Fld3888RRef
inner join pbi.vb_Point PW ON PW.PointRef = PR._Fld3889RRef
where PR._Marked  = 0x00
	and PR._Folder  = 0x01


GO


IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'vb_Point' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_Point
GO

Create view pbi.vb_Point AS
    select 
        PR._IDRRef as PointRef,
        PR._Description as PointName,
        C._Description as CountryName,
        PR._Fld3853RRef as TypeRef,
        CASE 
            WHEN PR._Fld3853RRef = 0xB6F8FF047F4959FB48398FBFA5E4A191 then 'Город'
            WHEN PR._Fld3853RRef = 0xBDF15374BD28ADAA407BA956B9EA04CB then 'Село'
			WHEN PR._Fld3853RRef = 0x914D55B1B7E3761E40148D91495C6B9A then 'Погранперехід'
			WHEN PR._Fld3853RRef = 0xB3FA76702F4D9AEC4428207C824E36F6 then 'Село'
			WHEN PR._Fld3853RRef = 0xB6FE80F53D2689E142B0D48EEC962652 then 'Село'
			WHEN PR._Fld3853RRef = 0x92D9CB11D21C4BA840D4DAE3570E0A27 then 'Адрес'
			WHEN PR._Fld3853RRef = 0xAC0D912E53801A93421F41AD81854713 then 'Погранперехід'
            else '1'
        end as PointType
    from _Reference299 PR
    left join _Reference299 C ON C._IDRRef = PR._ParentIDRRef
    where PR._Marked = 0x00
	 and PR._Folder = 0x01
