/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE Acc_CRM_CountryList
	@UserRole		TINYINT=2,
	@Active			TINYINT = 1,
	@Lang			VARCHAR(10)='en-US'
AS

/*
Created: Winnie
Date: 20140212
Task : Get data for main tab
DB: DBCRM.bodb_CRM
Original:

Revisions:	
	- 20190506@Winnie: CN88 Permission RedmineID: #112637
	- 20201030@Johnson: add filter IsActive [redmine: #142194]
    - 20231107@Ned.Le: CRM - Category/sub-category/admin tool (Setting Management) can show by Alphabet (#193380)

Param's Explanation:
	- @Active = 1: get active
				= 2: get all 	
*/

BEGIN
	SET NOCOUNT ON

	SELECT	[CountryID],[CountryAbb]		
			,CASE		WHEN @Lang='zh-TW' THEN ISNULL(CountryNameCT,[CountryName])
						WHEN @Lang='zh-CN' THEN ISNULL(CountryNameCS,[CountryName])
												ELSE [CountryName]
				END AS [CountryName],
			[CountryCode],
			[isActive]
	FROM crmCountry  WITH(NOLOCK) 
	WHERE 1 = CASE WHEN (@Active = 1 AND IsActive = 1) OR @Active = 2 THEN 1 ELSE 0 END
			AND @UserRole=SiteOffer
    ORDER BY [CountryName]
END
GO

