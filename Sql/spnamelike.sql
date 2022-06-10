
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