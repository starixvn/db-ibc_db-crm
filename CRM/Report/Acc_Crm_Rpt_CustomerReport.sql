ALTER PROCEDURE [dbo].[Acc_Crm_Rpt_CustomerReport]
	@UserName 				NVARCHAR(100) = '',
	@LanguageID				VARCHAR(1000) = NULL,	
	@SiteID					VARCHAR(1000) = NULL,
	@RoleID					VARCHAR(20)='',	
	@HeadLine				VARCHAR(50)=NULL,
	@ExcludeIgnoredAcc		BIT=1,
	@TitleID				INT = NULL,	
	@VIP					SMALLINT = -1,
	@PageSize				INT = 0,
	@PageIndex				INT = 0,
	@TotalRows				INT = 0 OUTPUT
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
	- 20160712@Winnie: #60341 Modify customer report to display more information
	- 20160914@Winnie: Include 'Checker' and 'Ignored Accounts' RedmineID: #64067
Param's Explanation:
	@CustomerType: 0 = All
					1 = Customer
					2 = Guest
*/
DECLARE @RowStart INT, @RowEnd INT 
	SELECT @TotalRows = 0		
	SELECT @PageIndex = @PageIndex - 1
			,@RowStart = @PageSize * @PageIndex + 1
			,@RowEnd = @RowStart + @PageSize - 1
			
DECLARE @tmpRole TABLE (RoleId tinyint)
INSERT INTO @tmpRole
	SELECT val
	FROM f_CRM_strSplit (@RoleID,',')
	
IF ((@PageSize <= 0) AND (@PageIndex <= 0))
BEGIN
SELECT  
		DISTINCT
		 c.CustID, 
		ISNULL(hedinfo.custid,0) AS HeadlineID,
		hedinfo.UserName AS Headline,
		c.UserName,
		c.FirstName,
		c.LastName,
		c.PhoneCountryCode+'-'+c.PhoneAreaCode+'-'+c.Phone AS Phone1,
		c.Phone2CountryCode+'-'+c.Phone2AreaCode+'-'+c.Phone2 AS Phone2,
		c.Phone3CountryCode+'-'+c.Phone3AreaCode+'-'+c.Phone3 AS Phone3,
		c.MobilePhoneCountryCode+'-'+ c.MobilePhoneAreaCode +'-'+c.MobilePhone AS Mobile,
		c.FaxCountryCode+'-'+ c.FaxAreaCode +'-'+ c.Fax AS Fax,
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
		ISNULL(c.IsVIP,0) AS VIP,
		c.Pic1Name+'-'+c.Pic1 AS PIC1,
		c.Pic2Name+'-'+c.Pic2 AS PIC2,
		c.Pic3Name+'-'+c.Pic3 AS PIC3,
		c.Pic4Name+'-'+c.Pic4 AS PIC4,
		c.Birthday,
		c.Passport,
		site.SiteName,
		CASE WHEN ISNULL(closed,0)=1 THEN 'Closed' 
			 WHEN ISNULL(reject,0)=1 THEN 'Suspended'
			 WHEN ISNULL(Enabled,1)=0 THEN 'Disabled'
			 ELSE 'Active' END AS Status,
		ct.CountryName,
		c.Checker
FROM crmCustomer(NOLOCK) c 
INNER JOIN DBAGE.bodb02.dbo.CustInfo ci WITH(NOLOCK)  ON c.custid=ci.Custid
INNER JOIN @tmpRole r ON ci.roleid=r.RoleId
LEFT JOIN crmSite(nolock) site ON site.SiteID = c.SiteID
LEFT join crmCustomerLanguage(NOLOCK) custlang ON custlang.CustID = c.CustID
LEFT JOIN DBAGE.bodb02.dbo.CustAccount cus WITH(NOLOCK) ON c.CustID=cus.custid
LEFT JOIN DBAGE.bodb02.dbo.CustAccount hed WITH(NOLOCK) ON cus.groupID=hed.groupID AND hed.IsGroupHeadLine=1
LEFT JOIN DBAGE.bodb02.dbo.Customer hedinfo WITH(NOLOCK) ON hed.custid=hedinfo.custid
LEFT JOIN crmCountry ct WITH(NOLOCK) ON c.CountryID=ct.CountryID
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
			OR (isnull(custlang.LanguageID,0) IN(SELECT val FROM dbo.f_split(@LanguageID,',')) AND ISNULL(@LanguageID,'')<>'')
		)
	AND ((ISNULL(@SiteID,'')='' AND ISNULL(c.SiteID,0)=0) OR ISNULL(c.SiteID,0) IN(SELECT val FROM dbo.f_split(@SiteID,',') ))
	AND (ISNULL(@TitleID,0)=0 OR c.TitleID = @TitleID)
	AND (ISNULL(@Vip,-1)=-1 OR ISNULL(c.IsVIP,0) = @Vip)
	AND (@HeadLine IS NULL OR (@HeadLine=hedinfo.username))
	AND (ISNULL(@ExcludeIgnoredAcc,1)=1 OR ISNULL(c.ignored,0) = @ExcludeIgnoredAcc)
	
	
ORDER BY ISNULL(hedinfo.custid,0) DESC, ISNULL(c.IsVIP,0) DESC
RETURN
END
IF @TotalRows = 0  
BEGIN  
		SELECT @TotalRows = count(DISTINCT c.CustID)
		FROM crmCustomer(NOLOCK) c 
		INNER JOIN DBAGE.bodb02.dbo.CustInfo ci WITH(NOLOCK)  ON c.custid=ci.Custid
		INNER JOIN @tmpRole r ON ci.roleid=r.RoleId
		LEFT join crmCustomerLanguage(NOLOCK) custlang ON custlang.CustID = c.CustID	
		LEFT JOIN DBAGE.bodb02.dbo.CustAccount cus WITH(NOLOCK) ON c.CustID=cus.custid
		LEFT JOIN DBAGE.bodb02.dbo.CustAccount hed WITH(NOLOCK) ON cus.groupID=hed.groupID AND hed.IsGroupHeadLine=1
		LEFT JOIN DBAGE.bodb02.dbo.Customer hedinfo WITH(NOLOCK) ON hed.custid=hedinfo.custid	
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
					OR (isnull(custlang.LanguageID,0) IN(SELECT val FROM dbo.f_split(@LanguageID,',')) AND ISNULL(@LanguageID,'')<>'')
				)
			AND ((ISNULL(@SiteID,'')='' AND ISNULL(c.SiteID,0)=0) OR ISNULL(c.SiteID,0) IN(SELECT val FROM dbo.f_split(@SiteID,',')))		
			AND (ISNULL(@TitleID,0)=0 OR c.TitleID = @TitleID)
			AND (ISNULL(@Vip,-1)=-1 OR ISNULL(c.IsVIP,0) = @Vip)
			AND (@HeadLine IS NULL OR (@HeadLine=hedinfo.username))
			AND (ISNULL(@ExcludeIgnoredAcc,1)=1 OR ISNULL(c.ignored,0) = @ExcludeIgnoredAcc)
			
END
;WITH Pag AS
	(
	  SELECT distinct  c.CustID,ISNULL(IsVIP,0) AS IsVIP
	  , ISNULL(hedinfo.custid,0) AS HeadlineID
	  FROM crmCustomer(NOLOCK) c 
	    INNER JOIN DBAGE.bodb02.dbo.CustInfo ci WITH(NOLOCK)  ON c.custid=ci.Custid
	    INNER JOIN @tmpRole r ON ci.roleid=r.RoleId
		LEFT join crmCustomerLanguage(NOLOCK) custlang ON custlang.CustID = c.CustID
		LEFT JOIN DBAGE.bodb02.dbo.CustAccount cus WITH(NOLOCK) ON c.CustID=cus.custid
		LEFT JOIN DBAGE.bodb02.dbo.CustAccount hed WITH(NOLOCK) ON cus.groupID=hed.groupID AND hed.IsGroupHeadLine=1
		LEFT JOIN DBAGE.bodb02.dbo.Customer hedinfo WITH(NOLOCK) ON hed.custid=hedinfo.custid
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
					OR (isnull(custlang.LanguageID,0) IN(SELECT val FROM dbo.f_split(@LanguageID,',')) AND ISNULL(@LanguageID,'')<>'')
				)
			AND ((ISNULL(@SiteID,'')='' AND ISNULL(c.SiteID,0)=0) OR isnull(c.SiteID,0) IN(SELECT val FROM dbo.f_split(@SiteID,',')))			
			AND (ISNULL(@TitleID,0)=0 OR c.TitleID = @TitleID)
			AND (ISNULL(@Vip,-1)=-1 OR ISNULL(c.IsVIP,0) = @Vip)
			AND (@HeadLine IS NULL OR (@HeadLine=hedinfo.username))
			AND (ISNULL(@ExcludeIgnoredAcc,1)=1 OR ISNULL(c.ignored,0) = @ExcludeIgnoredAcc)
			
	)
	,pag2 as
	(
	SELECT CustID, ROW_NUMBER() OVER(ORDER BY HeadlineID DESC, IsVIP DESC
	) AS RowNum FROM Pag
	)

SELECT DISTINCT c.CustID, 
		ISNULL(hedinfo.custid,0) AS hedId,
		hedinfo.UserName AS Headline,
		c.UserName,
		c.FirstName,
		c.LastName,
		c.PhoneCountryCode+'-'+c.PhoneAreaCode+'-'+c.Phone AS Phone1,
		c.Phone2CountryCode+'-'+c.Phone2AreaCode+'-'+c.Phone2 AS Phone2,
		c.Phone3CountryCode+'-'+c.Phone3AreaCode+'-'+c.Phone3 AS Phone3,
		c.MobilePhoneCountryCode+'-'+ c.MobilePhoneAreaCode +'-'+c.MobilePhone AS Mobile,
		c.FaxCountryCode+'-'+ c.FaxAreaCode +'-'+ c.Fax AS Fax,
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
		ISNULL(c.IsVIP,0) AS VIP,
		c.Pic1Name+'-'+c.Pic1 AS PIC1,
		c.Pic2Name+'-'+c.Pic2 AS PIC2,
		c.Pic3Name+'-'+c.Pic3 AS PIC3,
		c.Pic4Name+'-'+c.Pic4 AS PIC4,
		c.Birthday,
		c.Passport,
		site.SiteName,		
		CASE WHEN ISNULL(closed,0)=1 THEN 'Closed' 
			 WHEN ISNULL(reject,0)=1 THEN 'Suspended'
			 WHEN ISNULL(Enabled,1)=0 THEN 'Disabled'
			 ELSE 'Active' END AS Status,
		ct.CountryName ,
		c.Checker
FROM crmCustomer(NOLOCK) c 
INNER JOIN pag2 ON c.CustID = pag2.CustID
INNER JOIN DBAGE.bodb02.dbo.CustInfo ci WITH(NOLOCK)  ON c.custid=ci.Custid
LEFT JOIN crmSite(nolock) site ON site.SiteID = c.SiteID
LEFT JOIN DBAGE.bodb02.dbo.CustAccount cus WITH(NOLOCK) ON c.CustID=cus.custid
LEFT JOIN DBAGE.bodb02.dbo.CustAccount hed WITH(NOLOCK) ON cus.groupID=hed.groupID AND hed.IsGroupHeadLine=1
LEFT JOIN DBAGE.bodb02.dbo.Customer hedinfo WITH(NOLOCK) ON hed.custid=hedinfo.custid
LEFT JOIN crmCountry ct WITH(NOLOCK) ON c.CountryID=ct.CountryID
OUTER APPLY(
	SELECT Stuff((SELECT ',' + lang.Name
                 FROM  crmCustomerLanguage(nolock) clang
				 inner join crmLanguage(nolock) lang on lang.LanguageID = clang.LanguageID
				 WHERE clang.CustID = c.CustID
                 FOR XML PATH('')), 1, 1, '')
)A (language_name)
WHERE pag2.RowNum BETWEEN @RowStart AND @RowEnd
ORDER BY ISNULL(hedinfo.custid,0) DESC,ISNULL(c.IsVIP,0) DESC
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
