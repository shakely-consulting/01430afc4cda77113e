IF object_id('spcreatetable') IS NOT NULL
	DROP PROC [spcreatetable];
GO


CREATE PROCEDURE spcreatetable (@objname SYSNAME)
AS /*IF OBJECT_ID('sp_gettableschema2') IS NOT NULLDROP PROC sp_gettableschema2GO*/
BEGIN
	DECLARE @objid INT = OBJECT_ID(@objname)
		,@tableCreation NVARCHAR(MAX)
		,@dropDummy NVARCHAR(MAX)
		,@HasIdentity NVARCHAR(max)
		,@identitycol SYSNAME
		,@boolIdentity INT
		,@end NVARCHAR(max)
        ,@query NVARCHAR(MAX)

	SELECT @boolIdentity = dbo.fnHasIdentity(@objname);

	SELECT @identitycol = name
	FROM sys.all_columns
	WHERE object_name(object_id) = @objname
		AND is_identity = 1;

	SELECT @HasIdentity = '(' + CHAR(9) + CHAR(10) + CHAR(13) + CHAR(9) + QUOTENAME(@identitycol) + ' NUMERIC(18,0) IDENTITY (1,1) '
	FROM sys.all_columns
	WHERE is_identity = 1;

	IF @boolIdentity = 0
		SELECT @tableCreation = 'IF OBJECT_ID(' + QUOTENAME(@objname, '''') + ') IS NULL CREATE TABLE ' + QUOTENAME(@objname) + ' (';
	ELSE IF @boolIdentity = 1
		SELECT @tableCreation = 'IF OBJECT_ID(' + QUOTENAME(@objname, '''') + ') IS NULL CREATE TABLE ' + QUOTENAME(@objname) + ' ' + @HasIdentity;

	IF @boolIdentity = 0
		SELECT @end = ' ) ON [PRIMARY] ;'
	ELSE IF @boolIdentity = 1
		SELECT @end = 'CONSTRAINT ' + QUOTENAME('PK_' + @objname) + ' PRIMARY KEY NONCLUSTERED( ' + QUOTENAME(isnull(@identitycol, 'Id')) + ' ASC)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ' + 'ON [PRIMARY]) ON [PRIMARY] ' + CHAR(10);

	SELECT [Create] AS 'Create'
	FROM (
		SELECT @tableCreation AS 'Create'

		UNION ALL

		SELECT CASE WHEN ODB = 1 AND @boolIdentity = 0 then Col ELSE ', ' + Col END + ' NULL ' AS 'Create'
		FROM (
			SELECT ROW_NUMBER() OVER (
					ORDER BY column_id
					) AS ODB
				,(
					CASE
						WHEN type_name(user_type_id) IN ('numeric', 'decimal')
							THEN QUOTENAME(name) + ' ' + type_name(user_type_id) + ' (' + convert(VARCHAR, precision) + ',' + convert(VARCHAR, scale) + ')'
						WHEN type_name(user_type_id) LIKE '%DATE%'
							THEN QUOTENAME(name) + ' ' + type_name(user_type_id)
						WHEN type_name(user_type_id) IN ('varchar', 'nvarchar', 'char')
							AND CONVERT(INT, max_length) <> - 1
							THEN QUOTENAME(name) + ' ' + type_name(user_type_id) + ' (' + convert(VARCHAR, CONVERT(INT, max_length / CASE WHEN  left(type_name(user_type_id),1) = 'n' then 2 else 1 end)) + ')'
						WHEN type_name(user_type_id) IN ('varchar', 'nvarchar', 'char')
							AND CONVERT(INT, max_length) = - 1
							THEN QUOTENAME(name) + ' ' + type_name(user_type_id) + ' (MAX)'
						WHEN type_name(user_type_id) IN ('varbinary', 'float', 'text')
							THEN QUOTENAME(name) + ' ' + type_name(user_type_id)
						WHEN type_name(user_type_id) IN ('smallint', 'tinyint', 'int', 'bigint', 'bit', 'money', 'timestamp')
							THEN QUOTENAME(name) + ' ' + type_name(user_type_id)
						ELSE QUOTENAME(name) + ' ' + type_name(user_type_id)
						END
					) AS Col
			FROM sys.all_columns
			WHERE object_name(object_id) = @objname
				AND is_identity <> 1
			) AS TEMP
		WHERE Col IS NOT NULL

		UNION ALL

		SELECT @end
		) X;
END
GO
