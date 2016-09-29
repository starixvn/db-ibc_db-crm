ALTER PROCEDURE [dbo].[Acc_Crm_Rpt_CustomerReport]
	@UserName 				NVARCHAR(100) = '',
	@LanguageID				VARCHAR(1000) = NULL,	
	@SiteID					VARCHAR(1000) = NULL,
	@RoleID					VARCHAR(20)='',	
	@HeadLine				VARCHAR(50)=NULL,
	@ExcludeIgnoredAcc		BIT=0,
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
declare @p1 int
set @p1=9608
exec Acc_Crm_Rpt_CustomerReport_xtest @TotalRows=@p1 output,@SiteID='0,6004,6006,6014,6016,6019,6023,6024,6025,6026,6027,6028,6029,6037,6055,6274,6294,6343,6344,6254,6200,6201,6202,6204,6206,6207,6208,6248,6211,6212,6213,6214,6215,6216,6232,6241,6247,6249,6250,6252,6255,6258,6259,6260,6261,6262,6263,6264,6265,6266,6267,6268,6269,6271,6272,6274,6278,6279,6280,6281,6282,6283,6284,6285,6286,6292,6293,6287,6288,6289,6290,6291,6295,6296,6297,6298,6299,6300,6306,6307,6308,6309,6310,6311,6312,6313,6314,6315,6316,6317,6318,6321,6322,6323,6324,6325,6327,6328,6329,6331,6332,6335,6336,6337,6338,6339,6340,6341,6342,6345,6346,6347,6348,6349,6350,6351,6352,6355',@UserName=NULL,@PageSize=50,@VIP=-1,@RoleID='1,2,3,4',@PageIndex=1,@ExcludeIgnoredAcc=1,@LanguageID='0,12000,12001,12002,12003,12004,12006,12007,12008,12009',@HeadLine=NULL
select @p1
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
DECLARE @tmpLanguage TABLE (LanguageId INT)
DECLARE @tmpSite TABLE (SiteID INT)
INSERT INTO @tmpRole
	SELECT val
	FROM f_CRM_strSplit (@RoleID,',')
INSERT INTO @tmpLanguage
	SELECT val
	FROM f_CRM_strSplit (@LanguageID,',')

INSERT INTO @tmpSite
	SELECT val
	FROM f_CRM_strSplit (@SiteID,',')
	
	
CREATE table #tempHeadline(Custid INT,Username VARCHAR(50),groupID SMALLINT,Ignored BIT)
CREATE CLUSTERED INDEX [IX_groupID] ON [dbo].#tempHeadline 
	(
		groupID ASC
	)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]

INSERT INTO #tempHeadline(Custid,Username,groupID,Ignored)
SELECT hed.custid,username,groupID,Ignored
FROM DBAGE.bodb02.dbo.CustAccount hed INNER JOIN 
crmCustomer hedinfo WITH(NOLOCK)  ON hed.IsGroupHeadLine=1 AND hed.custid=hedinfo.custid
WHERE  @HeadLine IS NULL OR( hedinfo.username LIKE @HeadLine+'%')

IF ((@PageSize <= 0) AND (@PageIndex <= 0))
BEGIN
SELECT  
		DISTINCT
		 c.CustID, 
		ISNULL(hed.custid,0) AS HeadlineID,
		hed.UserName AS Headline,
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
LEFT JOIN DBAGE.bodb02.dbo.CustInfo ci WITH(NOLOCK)  ON c.custid=ci.Custid
LEFT JOIN crmSite(nolock) site ON site.SiteID = c.SiteID
LEFT join crmCustomerLanguage(NOLOCK) custlang ON custlang.CustID = c.CustID
LEFT JOIN DBAGE.bodb02.dbo.CustAccount cus WITH(NOLOCK) ON c.CustID=cus.custid
LEFT JOIN #tempHeadline hed ON cus.groupID=hed.groupID
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
			OR (isnull(custlang.LanguageID,0) IN(SELECT LanguageID FROM @tmpLanguage) AND ISNULL(@LanguageID,'')<>'')
		)
	AND ((ISNULL(@SiteID,'')='' AND ISNULL(c.SiteID,0)=0) OR ISNULL(c.SiteID,0) IN(SELECT siteid FROM @tmpSite ))	
	AND (ISNULL(@Vip,-1)=-1 OR ISNULL(c.IsVIP,0) = @Vip)	
	AND (ISNULL(@ExcludeIgnoredAcc,0)=0 OR ISNULL(hed.ignored,0) <> @ExcludeIgnoredAcc)
	AND (ISNULL(ci.roleid,0) IN (SELECT RoleID FROM @tmpRole))
	AND (@HeadLine IS NULL OR (hed.Custid IN (select custid FROM #tempHeadline )) )
ORDER BY ISNULL(hed.custid,0) DESC, ISNULL(c.IsVIP,0) DESC
RETURN
END
IF @TotalRows = 0  
BEGIN  
		SELECT @TotalRows = count(DISTINCT c.CustID)
		FROM crmCustomer(NOLOCK) c 
		LEFT JOIN DBAGE.bodb02.dbo.CustInfo ci WITH(NOLOCK)  ON c.custid=ci.Custid		
		LEFT join crmCustomerLanguage(NOLOCK) custlang ON custlang.CustID = c.CustID	
		LEFT JOIN DBAGE.bodb02.dbo.CustAccount cus WITH(NOLOCK) ON c.CustID=cus.custid
		LEFT JOIN  #tempHeadline hed  ON cus.groupID=hed.groupID 
		
		WHERE (ISNULL(@UserName,'')='' OR c.UserName LIKE '%'+@UserName+'%')
			AND (
					(ISNULL(@LanguageID,'')='')-- and isnull(A.language_name,'')='')
					OR (isnull(custlang.LanguageID,0) IN(SELECT LanguageID FROM @tmpLanguage) AND ISNULL(@LanguageID,'')<>'')
				)
			AND ((ISNULL(@SiteID,'')='' AND ISNULL(c.SiteID,0)=0) OR ISNULL(c.SiteID,0) IN(SELECT siteid FROM @tmpSite ))	
			AND (ISNULL(@Vip,-1)=-1 OR ISNULL(c.IsVIP,0) = @Vip)			
			AND (ISNULL(@ExcludeIgnoredAcc,0)=0 OR ISNULL(hed.ignored,0) <> @ExcludeIgnoredAcc)
			AND (ISNULL(ci.roleid,0) IN (SELECT RoleID FROM @tmpRole))
			AND (@HeadLine IS NULL OR (hed.Custid IN (select custid FROM #tempHeadline )) )
END
;WITH Pag AS
	(
	  SELECT distinct  c.CustID,ISNULL(IsVIP,0) AS IsVIP
	  , ISNULL(hed.custid,0) AS HeadlineID
	  FROM crmCustomer(NOLOCK) c 
	    LEFT JOIN 
	    DBAGE.bodb02.dbo.CustInfo ci WITH(NOLOCK)  ON c.custid=ci.Custid	   
		LEFT join crmCustomerLanguage(NOLOCK) custlang ON custlang.CustID = c.CustID
		LEFT JOIN DBAGE.bodb02.dbo.CustAccount cus WITH(NOLOCK) ON c.CustID=cus.custid
		LEFT JOIN #tempHeadline hed  ON cus.groupID=hed.groupID 
		
		WHERE (ISNULL(@UserName,'')='' OR c.UserName LIKE '%'+@UserName+'%')
			AND (
					(ISNULL(@LanguageID,'')='')-- and isnull(A.language_name,'')='')
					OR (isnull(custlang.LanguageID,0) IN(SELECT LanguageID FROM @tmpLanguage) AND ISNULL(@LanguageID,'')<>'')
				)
			AND ((ISNULL(@SiteID,'')='' AND ISNULL(c.SiteID,0)=0) OR isnull(c.SiteID,0) IN(SELECT siteid FROM @tmpSite ))							
			AND (ISNULL(@Vip,-1)=-1 OR ISNULL(c.IsVIP,0) = @Vip)			
			AND (ISNULL(@ExcludeIgnoredAcc,0)=0 OR ISNULL(hed.ignored,0) <> @ExcludeIgnoredAcc)
			AND (ISNULL(ci.roleid,0) IN (SELECT RoleID FROM @tmpRole))
			AND (@HeadLine IS NULL OR (hed.Custid IN (select custid FROM #tempHeadline )) )
			
	)
	,pag2 as
	(
	SELECT CustID, ROW_NUMBER() OVER(ORDER BY HeadlineID DESC, IsVIP DESC
	) AS RowNum FROM Pag
	)

SELECT DISTINCT c.CustID, 
		ISNULL(hed.custid,0) AS hedId,
		hed.UserName AS Headline,
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
LEFT JOIN DBAGE.bodb02.dbo.CustInfo ci WITH(NOLOCK)  ON c.custid=ci.Custid
LEFT JOIN crmSite(nolock) site ON site.SiteID = c.SiteID
LEFT JOIN DBAGE.bodb02.dbo.CustAccount cus WITH(NOLOCK) ON c.CustID=cus.custid
LEFT JOIN #tempHeadline hed  ON cus.groupID=hed.groupID 
LEFT JOIN crmCountry ct WITH(NOLOCK) ON c.CountryID=ct.CountryID
OUTER APPLY(
	SELECT Stuff((SELECT ',' + lang.Name
                 FROM  crmCustomerLanguage(nolock) clang
				 inner join crmLanguage(nolock) lang on lang.LanguageID = clang.LanguageID
				 WHERE clang.CustID = c.CustID
                 FOR XML PATH('')), 1, 1, '')
)A (language_name)
WHERE pag2.RowNum BETWEEN @RowStart AND @RowEnd
ORDER BY ISNULL(hed.custid,0) DESC,ISNULL(c.IsVIP,0) DESC
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
