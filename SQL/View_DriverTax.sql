-- SELECT * from pbi.v_DriverTax 
-- SELECT * from pbi.vb_DriverTax 

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_DriverTax' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_DriverTax
GO

Create view pbi.v_DriverTax AS

select 
	_Code as TaxName,
	case 
		when CONVERT(VARCHAR(MAX), _IDRRef, 2) = 'B98502B31CC3E40111EE1A29D2FD7ACA' then 1
		when CONVERT(VARCHAR(MAX), _IDRRef, 2) = '924F02B31CC3E40111EFA6565A2AB000' then 2
		else 0 end as Num,
	_Fld32492_N as TaxSum

from _Reference32491
where CONVERT(VARCHAR(MAX), _IDRRef, 2) in ('B98502B31CC3E40111EE1A29D2FD7ACA', '924F02B31CC3E40111EFA6565A2AB000')
go




IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'vb_DriverTax' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_DriverTax
GO

Create view pbi.vb_DriverTax AS

select 
	_Code as TaxName,
	case 
		when _IDRRef = 0xB98502B31CC3E40111EE1A29D2FD7ACA then 1
		when _IDRRef = 0x924F02B31CC3E40111EFA6565A2AB000 then 2
		else 0 end as Num,
	_Fld32492_N as TaxSum

from _Reference32491
where _IDRRef in (0xB98502B31CC3E40111EE1A29D2FD7ACA, 0x924F02B31CC3E40111EFA6565A2AB000)
go
