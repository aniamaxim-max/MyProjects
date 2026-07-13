IF NOT EXISTS (
    SELECT * FROM sys.indexes 
    WHERE name = '_AccumRg26553__Fld26556_RRRef_Fld26565' 
    AND object_id = OBJECT_ID('dbo._AccumRg26553')
)
BEGIN
    CREATE NONCLUSTERED INDEX [_AccumRg26553__Fld26556_RRRef_Fld26565]
        ON [dbo].[_AccumRg26553] ([_Fld26556_RRRef],[_Fld26565])
        INCLUDE ([_Active],[_Fld26554_RRRef],[_Fld26566])
END;
GO

IF NOT EXISTS (
    SELECT * FROM sys.indexes 
    WHERE name = '_Document650__Fld17685RRef' 
    AND object_id = OBJECT_ID('dbo._Document650')
)
BEGIN
    CREATE NONCLUSTERED INDEX [_Document650__Fld17685RRef] 
        ON [dbo].[_Document650] ([_Fld17685RRef]) INCLUDE ([_Date_Time],[_Number],[_Fld17682],[_Fld17683],[_Fld17716],[_Fld27200])
END; 
GO       

IF NOT EXISTS (
    SELECT * FROM sys.indexes 
    WHERE name = '_InfoRg20830_Period' 
    AND object_id = OBJECT_ID('dbo._InfoRg20830')
)
BEGIN
    CREATE NONCLUSTERED INDEX [_InfoRg20830_Period]
        ON [dbo].[_InfoRg20830] ([_Period])
END;
GO