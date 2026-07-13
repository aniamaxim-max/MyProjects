
select 
	CONVERT(VARCHAR(50), r._IDRRef, 2) as OTKRef,
	IIF(r._Date_Time >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, r._Date_Time), r._Date_Time) as OTKDate,
	r._Number,
	CONVERT(VARCHAR(50), r._Fld1348RRef, 2) as ClientRef,
	a.Amount,
	a.SumOTK,
	a.SumOTKNoVAT
from _Document278 r
left join(
	select 
		_Document278_IDRRef as OTKRef,
		SUM(_Fld1385) as Amount,
		SUM(_Fld1390) as SumOTKNoVAT,
		SUM(_Fld1392) as VATOTK,
		SUM(_Fld1390 + _Fld1392) as SumOTK
	from _Document278_VT1383
	group by _Document278_IDRRef) a on r._IDRRef = a.OTKRef
where r._Fld1356 = 0x01 -- упр облік
	and r._Posted = 0x01 -- проведено
	and r._Marked = 0x00 -- видалено




