if object_id('fnHasIdentity') is not null
	drop proc [fnHasIdentity];


GO
CREATE FUNCTION fnHasIdentity (@objname NVARCHAR(776))
RETURNS INT
AS
BEGIN

	declare	@dbname	sysname
		,@no varchar(35), @yes varchar(35), @none varchar(35)
	declare @colname sysname
		,@IsIdentity int
	select @no = 'no', @yes = 'yes', @none = 'none'
	select @dbname = parsename(@objname,3)
	if @dbname is null
		select @dbname = db_name()
	else if @dbname <> db_name()
		begin
		RETURN 0
		end
	declare @objid int
	declare @sysobj_type char(2)
	select @objid = object_id, @sysobj_type = type from sys.all_objects where object_id = object_id(@objname)

		if @sysobj_type in ('S ','U ','V ','TF')
		begin
			select @colname = col_name(@objid, column_id) from sys.identity_columns where object_id = @objid
			select @IsIdentity =	case isnull(@colname,'No identity column defined.') WHEN 'No identity column defined.' THEN 0 ELSE 1 END

		end

	return ISNULL(@IsIdentity, 0)
END
