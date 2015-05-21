ALTER PROCEDURE [dbo].[Acc_CRM_InformTitleDetail]
	@TitleID INT	
AS	
/*
	Created: Elodie
	Date: 2015-04-03
	Task: Inform title detail
	DB: DBCRM/bodb_CRM
		
	Revisions:

	Parameter's Explanation:				
		
	Example: EXEC Acc_CRM_InformTitleDetail @TitleID = 2
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @Currency VARCHAR(1000), @Level VARCHAR(10), @Site VARCHAR(4000), @TypeAccount TINYINT, @Content XML

	SELECT @Content = Filter
	FROM crmInformTitle_New WITH (NOLOCK)
	WHERE TitleID = @TitleID
	
	SELECT	@Site = xmlData.Col.value('@Site','VARCHAR(4000)'),
			@Level = xmlData.Col.value('@Position','VARCHAR(10)'),
			@Currency = xmlData.Col.value('@Currency','VARCHAR(1000)'),
			@TypeAccount = xmlData.Col.value('@DirectAccount','INT')
	FROM @Content.nodes('Filters') xmlData(Col)

	SELECT TitleID, Title, @Currency AS Currency, @Level AS Position, @Site AS Site, @TypeAccount AS TypeAccount
	FROM crmInformTitle_New WITH (NOLOCK)
	WHERE TitleID = @TitleID
END

GO 
GRANT EXECUTE ON [dbo].[Acc_CRM_InformTitleDetail] TO [bodbAdminNet]
GO 
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_InformTitleDetail] TO [vnteam]