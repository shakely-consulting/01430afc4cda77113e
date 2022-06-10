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
