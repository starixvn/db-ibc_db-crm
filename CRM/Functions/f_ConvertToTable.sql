 
ALTER FUNCTION  [dbo].[f_ConvertToTable] 
( 
	@string			VARCHAR(4000), 
	@row_splitter	CHAR(1),
	@col_splitter	CHAR(1)
)
RETURNS @res TABLE ( val1 VARCHAR(20), val2 VARCHAR(20))
/*
Created: @Lukas
Date: 20101119
DB: DB06.bodb_CRM
Original: 

Revisions:
	
Param's Explanation:	
*/
AS
BEGIN


	DECLARE	@substring varchar(100)

	DECLARE @start		INT, 
			@val1		VARCHAR(20), 
			@val2		VARCHAR(20), 
			@charindex	INT, 
			@i			INT

    IF SUBSTRING(@string, LEN(@string),1) <> @row_splitter
		SET @string = @string + @row_splitter

    SELECT	@i		= 1, 
			@start	= 1
    SET @charindex = CHARINDEX( @row_splitter, @string, @start)
    WHILE (@charindex <> 0)
	BEGIN
		SET @substring = SUBSTRING( @string, @start, @charindex - @start)		

		select @val1 = substring(@substring,1,charindex(@col_splitter,@substring,1)-1)
		select @val2 = substring(@substring,charindex(@col_splitter,@substring,1)+1,len(@substring))

		SET @start= @charindex +1
		SET @charindex= CHARINDEX( @row_splitter, @string, @start)
		INSERT INTO @res  VALUES ( @val1, @val2)
		set @i=@i+1
	END     
	RETURN
END

GO
GRANT EXECUTE ON [dbo].[f_ConvertToTable] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[f_ConvertToTable] TO [vnteam]