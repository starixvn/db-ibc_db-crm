/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_ProvinceSel]
@CountryID		INT = 0,
@Lang			VARCHAR(10)='en-US'
AS

/*
	Created: 20190521@Winnie
	Task :  Get all currency
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
			20190521@Winnie: select Province
            20231107@Ned.Le: CRM - Category/sub-category/admin tool (Setting Management) can show by Alphabet (#193380)

	Param's Explanation:
*/

BEGIN
	SET NOCOUNT ON

	SELECT  ProvinceID,
			CASE	WHEN @Lang='zh-TW' THEN ISNULL(ProvinceNameCT,ProvinceName)
							WHEN @Lang='zh-CN' THEN ISNULL(ProvinceNameCS,ProvinceName)
													ELSE ProvinceName
					END AS ProvinceName,		
			CountryID
	FROM crmProvince WITH (NOLOCK)
	WHERE isActive=1 AND(ISNULL(@CountryID,0)=0 OR CountryID=@CountryID)
    ORDER BY ProvinceName
	
END