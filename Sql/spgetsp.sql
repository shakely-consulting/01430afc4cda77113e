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