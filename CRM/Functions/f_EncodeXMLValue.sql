ALTER FUNCTION [dbo].[f_EncodeXMLValue](@value NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS
/* 
Created: @Lukas
Date: 20101119
Task: ViewLog function 331
DB: DB052.bodb_CRM
Original: DB02.bodb02.dbo.f_EncodeXMLValue

Revisions:
	- 20120529@Elodie: correct value of an apostrophe(')
					   change DB06 to DB052
Param's Explanation:	
*/
BEGIN
	/*
		# &amp; refers to an ampersand (&) 
		# &lt; refers to a less-than symbol (<) 
		# &gt; refers to a greater-than symbol (>) 
		# &quot; refers to a double-quote mark (") 
		# &apos; refers to an apostrophe (')	
	*/
		
	SELECT @value = REPLACE(@value, '&', '&amp;')
	SELECT @value = REPLACE(@value, '<', '&lt;')
	SELECT @value = REPLACE(@value, '>', '&gt;')
	SELECT @value = REPLACE(@value, '"', '&quot;')
	SELECT @value = REPLACE(@value, '''', '&apos;')
	
	RETURN @value
END

GO
GRANT EXECUTE ON [dbo].[f_EncodeXMLValue] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[f_EncodeXMLValue] TO [vnteam]