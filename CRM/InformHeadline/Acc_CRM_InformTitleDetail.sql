/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_InformTitleDetail]
	@TitleID INT	
AS	
/*
	Created: Elodie
	Date: 2015-04-03
	Task: Inform title detail
	DB: DBCRM/bodb_CRM
		
	Revisions:
	- 20161005@Winnie: Include 'Checker' and 'Ignored Accounts' RedmineID: #64067
	- 20190312@Winnie: CRM - Enhance Inform Headline RedmineID:##109775
	Parameter's Explanation:				
		
	Example: EXEC Acc_CRM_InformTitleDetail_xtest @TitleID = 2
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @Currency VARCHAR(1000), @Level VARCHAR(10), @Site VARCHAR(4000), @TypeAccount TINYINT, @Content XML,@ExcludeIgnored BIT,@IsVip TINYINT

	SELECT @Content = Filter
	FROM crmInformTitle_New WITH (NOLOCK)
	WHERE TitleID = @TitleID
	
	SELECT	@Site = xmlData.Col.value('@Site','VARCHAR(4000)'),
			@Level = xmlData.Col.value('@Position','VARCHAR(10)'),
			@Currency = xmlData.Col.value('@Currency','VARCHAR(1000)'),
			@TypeAccount = xmlData.Col.value('@DirectAccount','INT'),
			@ExcludeIgnored = xmlData.Col.value('@ExcludeIgnored','BIT'),
			@IsVip = xmlData.Col.value('@IsVip','TINYINT')
	FROM @Content.nodes('Filters') xmlData(Col)

	SELECT TitleID, Title, @Currency AS Currency, @Level AS Position, @Site AS Site, @TypeAccount AS TypeAccount,@ExcludeIgnored AS ExcludeIgnored,ISNULL(@IsVip,2) AS IsVip
	FROM crmInformTitle_New WITH (NOLOCK)
	WHERE TitleID = @TitleID
END


GO 
GRANT EXECUTE ON [dbo].[Acc_CRM_InformTitleDetail] TO [bodbAdminNet]
