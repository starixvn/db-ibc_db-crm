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
	- 20160712@Winnie: CR_20160630_Modify_CustomerReport
Param's Explanation:
	@CustomerType: 0 = All
					1 = Customer
					2 = Guest
*/

if(@ToBirthday IS NULL and @FromBirthday IS NOT NULL)
	select @ToBirthday = getdate()
else if(@ToBirthday IS NOT NULL and @FromBirthday IS NULL)
	select @FromBirthday = '19000101'

SELECT DISTINCT c.CustID, 
		hedinfo.UserName AS Headline,
		c.UserName,
		c.FirstName,
		c.LastName,
		c.PhoneCountryCode+'-'+c.PhoneAreaCode+'-'+c.Phone AS Phone1,
		c.Phone2CountryCode+'-'+c.Phone2AreaCode+'-'+c.Phone2 AS Phone2,
		c.Phone3CountryCode+'-'+c.Phone3AreaCode+'-'+c.Phone3 AS Phone3,
		c.MobilePhone AS Mobile,
		c.Fax,
		c.Email,
		c.Skype,
		c.MSN,
		c.WhatsApp,
		c.Line,
		c.WeChat,
		c.Yahoo,
		c.BBM,
		c.QQ,
		a.language_name AS Language ,
		c.IsVIP AS VIP,
		c.Pic1Name+'-'+c.Pic1 AS PIC1,
		c.Pic2Name+'-'+c.Pic2 AS PIC2,
		c.Pic3Name+'-'+c.Pic3 AS PIC3,
		c.Pic4Name+'-'+c.Pic4 AS PIC4,
		c.Birthday,
		c.Passport,
		site.SiteName		
FROM crmCustomer(NOLOCK) c 
LEFT JOIN crmSite(nolock) site ON site.SiteID = c.SiteID
LEFT join crmCustomerLanguage(NOLOCK) custlang ON custlang.CustID = c.CustID
LEFT JOIN DBAGE.bodb02.dbo.CustAccount cus (NOLOCK) ON c.CustID=cus.custid
LEFT JOIN DBAGE.bodb02.dbo.CustAccount hed (NOLOCK) ON cus.groupID=hed.groupID AND hed.IsGroupHeadLine=1
LEFT JOIN DBAGE.bodb02.dbo.Customer hedinfo (NOLOCK) ON hedinfo.custid=hedinfo.custid
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
