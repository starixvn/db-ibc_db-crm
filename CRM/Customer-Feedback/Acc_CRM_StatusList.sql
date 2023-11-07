/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_StatusList]
	@Type			INT = 0,
	@UserRole		TINYINT,
	@Lang			VARCHAR(10)='en-US'
as

/*
	Created: Dom
	Date: 20140417
	Task : Get list status from setting
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:	
		- 20150415@Elodie: Get status for InformHeadline function
		- 20180516@Winnie: CRM - Add New Feedback Status [RedmineID:#95184]
		- 20190507@Winnie:	CN88 	[RedmineID:#112637]
		- 20190828@Winnie:	Add more status [RedmineID:#119163]
		- 20230726@Malcolm:	Add more status [RedmineID:#191787]
        - 20231107@Ned.Le: CRM - Category/sub-category/admin tool (Setting Management) can show by Alphabet (#193380)

	Param's Explanation:
		@Type: = 3: Use in InformHeadline function			
*/

BEGIN
	IF @Type = 1
		SELECT StatusID,IsActive,
		CASE		WHEN @Lang='zh-TW' THEN ISNULL(NameCT,[Name])
					WHEN @Lang='zh-CN' THEN ISNULL(NameCS,[Name])
											ELSE [Name]
			END AS [Name]
		FROM crmStatus WITH(NOLOCK) 
		WHERE StatusID in(11001,11002,11003,11004,11006,11015,11016,11017,11018,11019,11020,11028,11029,11030,11031,11032,11033) AND (siteOffer=@UserRole)
		ORDER BY [Name]
	ELSE IF @Type = 2
		SELECT StatusID,IsActive, 
		CASE		WHEN @Lang='zh-TW' THEN ISNULL(NameCT,[Name])
				WHEN @Lang='zh-CN' THEN ISNULL(NameCS,[Name])
										ELSE [Name]
		END AS [Name]
		FROM crmStatus WITH(NOLOCK) 
		WHERE StatusID in(11004,11008,11009,11010,11011,11012,11019,11021,11022,11023,11024,11025)  AND (siteOffer=@UserRole)
		ORDER BY [Name]
	ELSE IF @Type = 3
		SELECT StatusID,IsActive, 
		CASE		WHEN @Lang='zh-TW' THEN ISNULL(NameCT,[Name])
				WHEN @Lang='zh-CN' THEN ISNULL(NameCS,[Name])
										ELSE [Name]
		END AS [Name]
		FROM crmStatus WITH(NOLOCK) 
		WHERE StatusID in(11013,11014,11026,11027) AND isactive = 1 AND (siteOffer=@UserRole)
        ORDER BY [Name]
	ELSE 
		SELECT StatusID,IsActive,
		CASE		WHEN @Lang='zh-TW' THEN ISNULL(NameCT,[Name])
					WHEN @Lang='zh-CN' THEN ISNULL(NameCS,[Name])
											ELSE [Name]
			END AS [Name] 
		FROM crmStatus WITH(NOLOCK) 
		WHERE isactive=1 AND (siteOffer=@UserRole)
        ORDER BY [Name]
END
GO