
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_Crm_Rpt_CustomerReport    Script Date: 3/26/2014 6:06:08 PM ******/
CREATE PROCEDURE [dbo].[Acc_Crm_Rpt_CustomerReport]
	@FirstName 		NVARCHAR(100) = NULL,
	@LastName 		NVARCHAR(100) = NULL,
	@CountryID 		VARCHAR(1000) = NULL,	
	@LanguageID		VARCHAR(1000) = NULL,	
	@SiteID			VARCHAR(1000) = NULL,	
	@FromBirthday	DATETIME=0,
	@ToBirthday		DATETIME=0,
	@TitleID		INT = NULL,	
	@VIP			SMALLINT = -1,	
	@CustomerType	TINYINT = 0
AS
/*
Created: Dom
Date: 2014-02-20
Task : update setting
DB: DBCRM/bodb_CRM
Original:

Revisions:
	
Param's Explanation:
	@CustomerType: 0 = All
					1 = Customer
					2 = Guest
*/

if(isnull(@ToBirthday,0)=0)
select @ToBirthday = getdate()

SELECT DISTINCT CustID= c.CustID, 
		VIP			= c.IsVIP,
		Title		= setting.SettingValue,
		FirstName	= c.FirstName,
		LastName	= c.LastName,
		Birthday	= c.Birthday,
		Country		= country.CountryName,
		Language	= a.language_name,
		Site		= site.SiteName,
		CustomerType = CASE WHEN c.CustID < 0 THEN 'Guest' ELSE 'Customer' END,
		MobilePhone = c.MobilePhone,
		MobilePhoneAreaCode = c.MobilePhoneAreaCode,
		MobilePhoneCountryCode = c.MobilePhoneCountryCode,
		Fax			= c.Fax,
		FaxAreaCode	= c.FaxAreaCode,
		FaxCountryCode = c.FaxCountryCode,
		c.Skype,
		c.Email,
		c.Birthday,
		c.Line1,
		c.Line2,
		c.Line3,
		c.Phone,
		c.PhoneAreaCode,
		c.PhoneCountryCode,
		c.Phone2,
		c.Phone2AreaCode,
		c.Phone2CountryCode,
		c.Phone3,
		c.Phone3AreaCode,
		c.Phone3CountryCode,
		c.City,
		c.State,
		c.PostCode
FROM crmCustomer(NOLOCK) c 
LEFT JOIN crmSetting(NOLOCK) setting ON setting.SettingID = c.TitleID AND setting.SettingName='title'
LEFT JOIN crmCountry(NOLOCK) country ON c.CountryID = country.CountryID
LEFT JOIN crmSite(nolock) site ON site.SiteID = c.SiteID
LEFT join crmCustomerLanguage(NOLOCK) custlang ON custlang.CustID = c.CustID
OUTER APPLY(
	SELECT Stuff((SELECT ',' + lang.Name
                 FROM  crmCustomerLanguage(nolock) clang
				 inner join crmLanguage(nolock) lang on lang.LanguageID = clang.LanguageID
				 WHERE clang.CustID = c.CustID
                 FOR XML PATH('')), 1, 1, '')
)A (language_name)
WHERE (ISNULL(@FirstName,'')='' OR c.FirstName LIKE '%'+@FirstName+'%')
	AND (ISNULL(@LastName,'')='' OR c.LastName LIKE '%'+@LastName+'%')
	AND ((ISNULL(@CountryID,'')='' AND ISNULL(c.CountryID,0)=0) OR c.CountryID IN(SELECT val FROM dbo.f_split(@CountryID,',')))
	AND (
			(ISNULL(@LanguageID,'')='' and isnull(A.language_name,'')='')
			OR (custlang.LanguageID IN(SELECT val FROM dbo.f_split(@LanguageID,',')) AND ISNULL(@LanguageID,'')<>'')
		)
	AND ((ISNULL(@SiteID,'')='' AND ISNULL(c.SiteID,0)=0) OR c.SiteID IN(SELECT val FROM dbo.f_split(@SiteID,',')))
	AND ((ISNULL(@FromBirthday,0)=0 AND ISNULL(@ToBirthday,0)=0) OR c.Birthday BETWEEN @FromBirthday AND @ToBirthday )
	AND (ISNULL(@TitleID,0)=0 OR c.TitleID = @TitleID)
	AND (ISNULL(@Vip,-1)=-1 OR c.IsVIP = @Vip)
	AND (@CustomerType=0 OR (@CustomerType=1 and c.CustID>0) OR (@CustomerType=2 and c.CustID<0))

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
