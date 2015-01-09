ALTER PROCEDURE [dbo].[Acc_Crm_Rpt_CustomerReport]
	@UserName 				NVARCHAR(100) = '',
	@LanguageID				VARCHAR(1000) = NULL,	
	@SiteID					VARCHAR(1000) = NULL,	
	@FromBirthday			DATETIME=NULL,
	@ToBirthday				DATETIME=NULL,
	@TitleID				INT = NULL,	
	@VIP					SMALLINT = -1
AS
/*
Created: Dom
Date: 2014-02-20
Task : update setting
DB: DBCRM/bodb_CRM
Original:

Revisions:
	- 20140812@Dom: Feature [#18860] Change requests on 10 Jul 2014
	- 20141118@Dom: add more fields of communication tool
Param's Explanation:
	@CustomerType: 0 = All
					1 = Customer
					2 = Guest
*/

if(@ToBirthday IS NULL and @FromBirthday IS NOT NULL)
	select @ToBirthday = getdate()
else if(@ToBirthday IS NOT NULL and @FromBirthday IS NULL)
	select @FromBirthday = '19000101'

SELECT DISTINCT CustID= c.CustID, 
		
		Title		= setting.SettingValue,
		UserName	= c.UserName,
		VIP			= c.IsVIP,
		Birthday	= c.Birthday,
		Pic1		= c.Pic1,
		Pic2		= c.Pic2,
		Pic3		= c.Pic3,
		Pic4		= c.Pic4,
		Pic1Name	= c.Pic1Name,
		Pic2Name	= c.Pic2Name,
		Pic3Name	= c.Pic3Name,
		Pic4Name	= c.Pic4Name,
		Language	= a.language_name,
		Site		= site.SiteName,
		c.Skype,
		c.Email
FROM crmCustomer(NOLOCK) c 
LEFT JOIN crmSetting(NOLOCK) setting ON setting.SettingID = c.TitleID AND setting.SettingName='title'
LEFT JOIN crmSite(nolock) site ON site.SiteID = c.SiteID
LEFT join crmCustomerLanguage(NOLOCK) custlang ON custlang.CustID = c.CustID
OUTER APPLY(
	SELECT Stuff((SELECT ',' + lang.Name
                 FROM  crmCustomerLanguage(nolock) clang
				 inner join crmLanguage(nolock) lang on lang.LanguageID = clang.LanguageID
				 WHERE clang.CustID = c.CustID
                 FOR XML PATH('')), 1, 1, '')
)A (language_name)
WHERE (ISNULL(@UserName,'')='' OR c.UserName LIKE '%'+@UserName+'%')
	AND (
			(ISNULL(@LanguageID,'')='' and isnull(A.language_name,'')='')
			OR (custlang.LanguageID IN(SELECT val FROM dbo.f_split(@LanguageID,',')) AND ISNULL(@LanguageID,'')<>'')
		)
	AND ((ISNULL(@SiteID,'')='' AND ISNULL(c.SiteID,0)=0) OR c.SiteID IN(SELECT val FROM dbo.f_split(@SiteID,',')))
	AND ((@FromBirthday IS NULL AND @ToBirthday IS NULL) OR c.Birthday BETWEEN @FromBirthday AND @ToBirthday )
	AND (ISNULL(@TitleID,0)=0 OR c.TitleID = @TitleID)
	AND (ISNULL(@Vip,-1)=-1 OR c.IsVIP = @Vip)

ORDER BY c.IsVIP DESC

GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_Crm_Rpt_CustomerReport] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_Crm_Rpt_CustomerReport] TO [vnteam]
GO 
