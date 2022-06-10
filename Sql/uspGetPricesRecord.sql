
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
