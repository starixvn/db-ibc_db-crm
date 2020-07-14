/*<info serverAlias="DBCRM-bodb_CRM" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[f_split]
(
	@string NVARCHAR(MAX),
	@splitter CHAR(1)
)
RETURNS @res TABLE (val VARCHAR(MAX))
AS

/*
	Created: 20110629@Lukas
	DB: DBCRM.bodb_CRM

	Revisions:
		- 20200511@Malcolm: Expand param's length [Redmine: #108739]

	Param's Explanation:			
*/

BEGIN
	IF SUBSTRING(@string, LEN(@string), 1) <> @splitter
	BEGIN
		SET @string= @string + @splitter
	END
	
	DECLARE @start INT,
			@word NVARCHAR(MAX),
			@charindex INT,
			@i INT

	SELECT	@i=1,
			@start=1,
			@charindex = CHARINDEX(@splitter, @string, @start)

	WHILE (@charindex <> 0)
	BEGIN
		SET @word = SUBSTRING(@string, @start, @charindex - @start)
		SET @word = REPLACE(@word, CHAR(10), '')
		SET @word = REPLACE(@word, CHAR(13), '')
		SET @start = @charindex +1
		SET @charindex= CHARINDEX(@splitter, @string, @start)
		
		INSERT INTO @res VALUES (@word)
		SET @i = @i+1
	END
    
	RETURN
END
GO