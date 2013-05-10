

ALTER FUNCTION  [dbo].[f_split] 
( 
	@string NVARCHAR( 4000), 
	@splitter CHAR( 1) 
)
RETURNS @res TABLE (val VARCHAR(255))
/*
	Created: @Lukas
	Date: 20110629
	DB: DB06.bodb_CRM
	Original: 

	Revisions:
		
	Param's Explanation:			
*/
AS
BEGIN
	IF SUBSTRING ( @string, LEN( @string), 1)<>@splitter
	BEGIN
		SET @string= @string+@splitter
	END
	
	DECLARE @start INT, 
			@word NVARCHAR(4000), 
			@charindex INT, 
			@i INT

	SELECT	@i=1,
			@start=1,
			@charindex = CHARINDEX( @splitter, @string, @start)

	WHILE (@charindex <> 0)
	BEGIN
		SET @word = SUBSTRING( @string, @start, @charindex - @start)
		SET @word = REPLACE(@word,char(10),'')
		SET @word = REPLACE(@word,char(13),'')
		SET @start = @charindex +1
		SET @charindex= CHARINDEX( @splitter, @string, @start)
		INSERT INTO @res  VALUES( @word)
		SET @i=@i+1
	END
    
	RETURN
END


GO
GRANT VIEW DEFINITION ON f_split to [vnteam]
