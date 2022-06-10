IF object_id('spkeys') IS NOT NULL
	DROP PROCEDURE [spkeys];
	GO

CREATE PROCEDURE spkeys (@objname NVARCHAR(776) = '')
AS
BEGIN
Declare @sql nvarchar(max);

set @sql = '
	SELECT ''Create'' = ''IF NOT EXISTS (SELECT * FROM sys.objects where name = '' + QUOTENAME(obj.name, '''''''') + '')'' + CHAR(10) + ''BEGIN '' + CHAR(10) + ''ALTER TABLE '' + QUOTENAME(tab1.name) + '' ADD CONSTRAINT '' + quotename(obj.name) + '' FOREIGN KEY ('' + quotename(col1.name) + '') REFERENCES '' + quotename(tab2.name) + ''('' + quotename(col2.name) + '')'' + CHAR(10) + '' END ''
		,''Drop'' = ''IF EXISTS (SELECT * FROM sys.objects where name = '' + QUOTENAME(obj.name, '''''''') + '')'' + CHAR(10) + ''BEGIN '' + CHAR(10) + ''ALTER TABLE '' + QUOTENAME(tab1.name) + '' DROP CONSTRAINT '' + quotename(obj.name) + CHAR(10) + '' END ''';

set @sql += '
	FROM sys.foreign_key_columns fkc
	INNER JOIN sys.objects obj ON obj.object_id = fkc.constraint_object_id
	INNER JOIN sys.tables tab1 ON tab1.object_id = fkc.parent_object_id
	INNER JOIN sys.schemas sch ON tab1.schema_id = sch.schema_id
	INNER JOIN sys.columns col1 ON col1.column_id = parent_column_id
		AND col1.object_id = tab1.object_id
	INNER JOIN sys.tables tab2 ON tab2.object_id = fkc.referenced_object_id
	INNER JOIN sys.columns col2 ON col2.column_id = referenced_column_id
		AND col2.object_id = tab2.object_id
	WHERE 1=1 ';

  IF @objname <> ''
begin
       set @sql += '
       AND obj.name = ' + quotename(@objname, '''') + '
		OR tab1.name = ' + quotename(@objname, '''')+ '
		OR tab2.name = ' +quotename(@objname, '''') + ';'

end

begin try
select error_message()

exec sp_executesql @sql;
end try
begin catch
select @sql;
end catch
END

GO

exec spkeys
GO
