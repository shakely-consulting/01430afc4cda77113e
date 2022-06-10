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