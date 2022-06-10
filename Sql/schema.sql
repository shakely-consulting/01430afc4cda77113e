if object_id('uspGetPricesRecord') is not null
drop Proc [uspGetPricesRecord];
go

CREATE PROC uspGetPricesRecord (
	@top NVARCHAR(20) = NULL
	,@symbol VARCHAR(10) = ''
	,@holdings VARCHAR(20) = '0.00628000'
	,@debug INT = 0
	)
AS
BEGIN
	SET NOCOUNT ON

	/*EXEC uspRefreshPricesRecordTable;*/

	DECLARE @s NVARCHAR(max);

	SET @s = '
;with cte
as (
	select pr.[Id]
		,row_number() over (
			partition by pr.[Open]
			,pr.[High]
			,pr.[Low]
			,pr.[Close]
			,pr.[AdjustedClose] order by [Date] desc
			) [rownum]
		,pr.UserId
		,pr.[Symbol]
		,pr.[Date]
		,pr.CreatedAt
		,pr.[Open]
		,pr.[High]
		,pr.[Low]
		,pr.[Close]
		,pr.[AdjustedClose]
		,pr.[Volume]
		,pr.[Pct_Change]
	from PricesRecords pr
	where 1 = 1
	)
select ';

	IF (
			isnull(@top, '') <> ''
			AND NOT @top = - 1
			)
		SET @s += ' TOP ' + @top + ' ';
	SET @s += '
	ROW_NUMBER() OVER (
		ORDER BY [Date] DESC, [Id] DESC
		) AS Id
	,UserId
	,cte.[Symbol]
	,cte.[Date]
	,ISNULL(cte.CreatedAt, GETUTCDATE()) CreatedAt
	,cte.[Open]
	,cte.[High]
	,cte.[Low]
	,cte.[Close]
	,cte.[AdjustedClose]
	,cte.[Volume]
	,CONVERT(DECIMAL(10, 2), CASE
			WHEN cast(CreatedAt AS DATE) = cast([Date] AS DATE)
				THEN COALESCE(cte.Pct_Change, ((AdjustedClose - cte.[Open]) / cast(cte.[Open] AS FLOAT)) * 100)
			ELSE ((AdjustedClose - cte.[Open]) / cast(cte.[Open] AS FLOAT)) * 100
			END) Pct_Change
	,[AdjustedClose] * case
		when Symbol = ';
	SET @s += ' ''JNJ'' ';
	SET @s += '  then ''1.215'' ELSE ';
	SET @s += '''' + @holdings + ''''
	SET @s += ' end as CurrentHoldings ';
	SET @s += '
from cte
where rownum = 1
order by Id , [Date] , CreatedAt  '

	IF @debug = 1
		SELECT @s;

	EXEC sp_executesql @s;
END


GO


IF OBJECT_ID('PricesRecords', 'U') IS NOT NULL
	DROP TABLE PricesRecords;
GO

CREATE TABLE PricesRecords(Id int identity(1,1) not null
	,Symbol NVARCHAR(100) null
	,UserId NVARCHAR(100) null
	,[Open] decimal default 0
	,[High] decimal default 0
	,[Low] decimal default 0
	,[Close] decimal default 0
	,[AdjustedClose] decimal default 0
	,Volume decimal default 0
	,Pct_Change float default 0 CONSTRAINT PK_PricesRecords PRIMARY KEY (Id)) ON [PRIMARY]
GO

if object_id('uspGetPricesRecordCount') is not null
drop Proc [uspGetPricesRecordCount];
go

CREATE PROC uspGetPricesRecordCount (
	@top NVARCHAR(20) = NULL
	,@symbol VARCHAR(10) = ''
	,@holdings VARCHAR(20) = '0.00628000'
	,@debug INT = 0
	)
AS
BEGIN
	SET NOCOUNT ON
	SELECT COUNT(*) myCount FROM PricesRecords;
END


GO

if object_id('spnamelike') is not null
drop procedure [spnamelike];
 GO

create proc spnamelike(@objname varchar(776))
as
begin

select OBJECT_DEFINITION(object_id) definition, name
from sys.objects
where name = @objname
	and OBJECT_DEFINITION(object_id) is not null
end

GO

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


if object_id('spcontents') is not null
drop Proc [spcontents];
go

create procedure spcontents (
	@objname sysname
	,@WhereClause nvarchar(max) = null
	,@includePK int = 0
	,@nums int = 1000
	,@debug int = 0
	)
as /* if object_id('spcontents', 'P') is not null  drop proc spcontents go */
begin
	set nocount on;

	declare @sql2 nvarchar(max)
		,@ident int;

	set @objname = RTRIM(@objname);

	if OBJECT_ID('tempdb..##temp') is not null
		drop table ##temp;

	if OBJECT_ID('tempdb..##tempdata') is not null
		drop table ##tempdata;

	if OBJECT_ID('tblspcontents_tempdata') is not null
		drop table tblspcontents_tempdata;

	if OBJECT_ID('tblspcontents_temp') is not null
		drop table tblspcontents_temp;

	create table [##tempdata] (
		[HMY] numeric(18, 0) IDENTITY(1, 1)
		,[ID] int null
		,[TheData] nvarchar(max) null constraint [PK_##tempdata] primary key nonclustered ([HMY] asc) with (
			PAD_INDEX = off
			,STATISTICS_NORECOMPUTE = off
			,IGNORE_DUP_KEY = off
			,ALLOW_ROW_LOCKS = on
			,ALLOW_PAGE_LOCKS = on
			) on [PRIMARY]
		) on [PRIMARY];

	create table [##temp] (
		[HMY] numeric(18, 0) IDENTITY(1, 1)
		,[ID] int null
		,InsertColumn nvarchar(max) null constraint [PK_##temp] primary key nonclustered ([HMY] asc) with (
			PAD_INDEX = off
			,STATISTICS_NORECOMPUTE = off
			,IGNORE_DUP_KEY = off
			,ALLOW_ROW_LOCKS = on
			,ALLOW_PAGE_LOCKS = on
			) on [PRIMARY]
		) on [PRIMARY];

	declare @objid int = object_id(@objname)
		,@tableCreation nvarchar(MAX)
		,@SQL nvarchar(MAX)
		,@v_Where nvarchar(max)
		,@insertlen numeric;

	set @v_Where = ISNULL(@WhereClause, '0=0');
	set @SQL = 'INSERT INTO ' + quotename(@objname) + ' (' + char(10);
	set @SQL += (
			select (
					select STUFF((
								select ',' + quotename(c.name) + char(10)
								from SYS.all_columns c
								where object_id = @objid
									and c.name <> 'tRowVersion'
									and type_name(c.user_type_id) <> 'image'
									and type_name(c.user_type_id) <> 'varbinary'
									and c.name not like '%select%'
									and type_name(c.user_type_id) not like '%text%'
									and (
										c.is_identity = 0
										or c.is_identity = @includePK
										)
								for xml PATH('')
									,TYPE
								).value('.', 'nvarchar(MAX)'), 1, 1, '')
					) + ')'
			)
	set @insertlen = LEN('SELECT ')
	set @SQL += 'SELECT ';

	insert into ##temp (
		ID
		,InsertColumn
		)
	select 1 ID
		,@SQL as InsertColumn;

	if @debug = 1
		select *
		into tblspcontents_temp
		from ##temp;

	if @WhereClause is null
		set @WhereClause = ' 0=0 ';

	select @SQL = '';

	select @SQL += 'INSERT INTO ##tempdata (ID, TheData) SELECT 1 AS ID,' + STUFF((
				select '+ ' + QUOTENAME(',', '''') + case
						when type_name(c.user_type_id) like '%date%'
							then '+ CASE WHEN ISNULL(RTRIM(REPLACE(' + quotename(object_name(object_id)) + '.' + quotename(c.name) + ',' + '''''''''' + ',' + '''' + '0' + '''' + ')' + /* ")" to the right is rtim close*/ '), ' + '''' + 'NULL' + '''' + ')  = ''NULL'' THEN  ''NULL'' ELSE ' + '''' + '''' + '''' + '''+' + ' REPLACE(RTRIM(' + quotename(object_name(object_id)) + '.' + quotename(c.name) + ')' + /*start here*/ + ',' + '''''''''' + ',' + '''''''''' + '''' + '''' + ')' + '+''' + '''' + '''' + '''' + '  END + ' + '''' + ' /*' + quotename(c.name) + '*/' + ''''
						when type_name(c.user_type_id) in ('varbinary', 'text')
							then '+' + '''' + '''' + '''' + '''' + 'CONVERT(VARCHAR, DecryptByKey(' + quotename(object_name(object_id)) + '.' + quotename(c.name) + ')' + ') +' + '''' + '''' + '''' + ''''
						when type_name(c.user_type_id) in ('int', 'numeric', 'float', 'tinyint', 'bit', 'smallint', 'decimal')
							then '+' + '''' + '''' + '''' + '''' + '+ convert(varchar(20), ISNULL(' + quotename(object_name(object_id)) + '.' + quotename(c.name) + ',' + '''' + '0' + '''' + ')) + ' + '''' + '''' + '''' + '/*' + quotename(c.name) + '*/' + ''''
						else '+ CASE WHEN ISNULL(RTRIM(REPLACE(' + quotename(object_name(object_id)) + '.' + quotename(c.name) + ',' + '''''''''' + ',' + '''' + '0' + '''' + ')' + /* ")" to the right is rtim close*/ '), ' + '''' + 'NULL' + '''' + ')  = ''NULL'' THEN  ''NULL'' ELSE ' + '''' + '''' + '''' + '''+' + ' REPLACE(RTRIM(' + quotename(object_name(object_id)) + '.' + quotename(c.name) + ')' + /*start here*/ + ',' + '''''''''' + ',' + '''''''''' + '''' + '''' + ')' + '+''' + '''' + '''' + '''' + '  END + ' + '''' + ' /*' + quotename(c.name) + '*/' + ''''
						end
				from SYS.all_columns c
				where object_id = @objid
					and c.name <> 'tRowVersion'
					and type_name(c.user_type_id) <> 'image'
					and type_name(c.user_type_id) <> 'varbinary'
					and c.name not like '%select%'
					and type_name(c.user_type_id) not like '%text%'
					and (
						c.is_identity = 0
						or c.is_identity = @includePK
						)
				for xml PATH('')
					,TYPE
				).value('.', 'nvarchar(MAX)'), 1, @insertlen, '') + ' AS ''TheData'' FROM ' + quotename(RTRIM(@objname)) + ' WITH(NOLOCK) WHERE 1=1 and ' + @v_Where;

	if @debug = 1
		select @SQL;

	begin try
		exec SP_EXECUTESQL @sql;

		set @sql2 = '  select top ' + convert(varchar(50), @nums) + ' sch.InsertColumn + '' '' + JS.TheData  as [Insert Statement]   from ##tempdata JS   outer apply (    select InsertColumn    from ##temp    ) sch '

		if @debug = 1
			select @sql2;

		exec SP_EXECUTESQL @sql2
	end try

	begin catch
		select 'Error' = 'Errors below ' + convert(varchar, error_line()) + ' ' + ERROR_MESSAGE()

		union all

		select 'Error' = @sql

		print @sql
	end catch

	begin try
		if @debug = 1
		begin
			select *
			into tblspcontents_tempdata
			from ##tempdata;

			select @sql2;
		end
	end try

	begin catch
		select 'Error' = 'Please see Messages for Errors.'
			,'line' = null

		union all

		select ERROR_MESSAGE() message
			,ERROR_LINE() line

		union all

		select 'Error' = @sql2
			,null
	end catch
end


GO
IF object_id('spgetinsert') IS NOT NULL
	DROP PROCEDURE spgetinsert;
GO

CREATE PROCEDURE spgetinsert (
	@objname SYSNAME
	,@WhereClause NVARCHAR(max) = NULL
	,@includePK BIT = 0
	,@nums INT = 1000
	,@debug INT = 0
	)
AS /* if object_id('spcontents', 'P') is not null  drop proc spcontents go */
BEGIN
	SET NOCOUNT ON;

	DECLARE @sql2 NVARCHAR(max)
		,@ident INT;

	SET @objname = RTRIM(@objname);

	DECLARE @objid INT = object_id(@objname)
		,@tableCreation NVARCHAR(MAX)
		,@SQL NVARCHAR(MAX)
		,@v_Where NVARCHAR(max)
		,@insertlen NUMERIC
		,@COLS NVARCHAR(MAX);

	SET @v_Where = ISNULL(@WhereClause, '0=0');

	SET @COLS = (
			SELECT (
					SELECT STUFF((
								SELECT ',' + quotename(c.name) + CHAR(10)
								FROM SYS.all_columns c
								WHERE object_id = @objid
									AND c.name <> 'tRowVersion'
									AND type_name(c.user_type_id) <> 'image'
									AND type_name(c.user_type_id) <> 'varbinary'
									AND type_name(c.user_type_id) NOT LIKE '%text%'
									AND (
										c.is_identity = 0
										OR c.is_identity = @includePK
										)
								FOR XML PATH('')
									,TYPE
								).value('.', 'nvarchar(MAX)'), 1, 1, '')
					)
			)
	SET @SQL = 'INSERT INTO ' + quotename(@objname) + ' (' + CHAR(10) + @COLS + ')'

	SET @SQL += CHAR(10) + 'SELECT ' + @COLS + ' FROM ' + quotename(@objname)

	SELECT @SQL;

END
GO

 SPGETINSERT MENUOTHERITEMS

GO

 IF object_id('spgetsp') IS NOT NULL
	DROP PROCEDURE [spgetsp];
GO

CREATE PROCEDURE spgetsp (@objName SYSNAME)
AS
BEGIN
	DECLARE @s NVARCHAR(max)
		,@temp NVARCHAR(10) = '';
	DECLARE @sysobj_type CHAR(20);

	SET @objName = replace(replace(@objName, '[', ''), ']', '');

	SELECT @sysobj_type = CASE
			WHEN type = 'P'
				THEN 'procedure'
			WHEN type IN (
					'FN'
					,'IF'
					)
				THEN 'function'
			WHEN type = 'V'
				THEN 'view'
			WHEN type = 'TR'
				THEN 'trigger'
			END
	FROM sys.all_objects
	WHERE object_id = object_id(@objname);

	IF LEFT(@objName, 1) = '#'
		SET @temp = 'tempdb..';
	SET @s = 'if object_id(''' + @temp + @objname + ''') is not null drop ' + @sysobj_type + ' ' + quotename(@objname) + ';	' + CHAR(10) + CHAR(13) + ' GO ' + CHAR(10) + CHAR(13)
	SET @s += object_definition(object_id(@objName))

	SELECT 'Create' = @s
END
go

if not exists (select * from sys.all_columns where object_name(object_id) = 'PricesRecords' and name = 'Date')
alter table PricesRecords add [Date] datetime null;


if not exists (select * from sys.all_columns where object_name(object_id) = 'PricesRecords' and name = 'CreatedAt')
alter table PricesRecords add CreatedAt datetime null;