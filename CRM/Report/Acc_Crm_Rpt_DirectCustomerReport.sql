/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,vnteam" viewers="vnteam" isFunction="0"></info>*/

USE [bodb_CRM]
GO
/****** Object:  StoredProcedure [dbo].[Acc_Crm_Rpt_DirectCustomerReport]    Script Date: 09/14/2017 09:13:46 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Acc_Crm_Rpt_CustomerReport    Script Date: 10/31/2016 4:20:42 PM ******/
ALTER PROCEDURE [dbo].[Acc_Crm_Rpt_DirectCustomerReport]	
	@HeadLine				VARCHAR(30)=NULL,
	@UserName				VARCHAR(30)=NULL,
	@ExcludeIgnoredAcc		BIT=0,	
	@PageSize				INT = 0,
	@PageIndex				INT = 0,
	@TotalRows				INT = 0 OUTPUT
AS
/*
Created: Winnie
Date: 2017-09-12
Task : Direct Customer Report
DB: DBCRM/bodb_CRM
Original:

Revisions:	
	- 20170912@Winnie: Direct Customer Report RedmineID: #82040
*/
DECLARE @RowStart INT, @RowEnd INT 
	SELECT @TotalRows = 0		
	SELECT @PageIndex = @PageIndex - 1
			,@RowStart = @PageSize * @PageIndex + 1
			,@RowEnd = @RowStart + @PageSize - 1			

CREATE table #tempHeadline(Custid INT,Username VARCHAR(50),groupID SMALLINT)
CREATE CLUSTERED INDEX [IX_groupID] ON [dbo].#tempHeadline 
	(
		groupID ASC
	)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]


INSERT INTO #tempHeadline(Custid,Username,groupID)
SELECT hed.custid,username,groupID
FROM  bodb02.dbo.CustAccount hed WITH(NOLOCK) 
	INNER JOIN bodb02.dbo.Customer hedinfo WITH(NOLOCK)  ON hed.IsGroupHeadLine=1 AND hed.custid=hedinfo.custid
	WHERE  @HeadLine IS NULL OR( hedinfo.username LIKE @HeadLine+'%')

IF ((@PageSize <= 0) AND (@PageIndex <= 0))
BEGIN
	;WITH temp AS
	(
		SELECT c.Username, c.custid,site,c.Currency,
				CASE WHEN ISNULL(closed,0)=1 THEN 'Closed' 
					WHEN ISNULL(reject,0)=1 THEN 'Suspended'
					WHEN ISNULL(Enabled,1)=0 THEN 'Disabled'
					ELSE 'Active' END AS Status,
				CASE WHEN ci.roleid=1 THEN 'Member'
					WHEN ci.roleid=2 THEN 'Agent'
					WHEN ci.roleid=3 THEN 'Master'
					WHEN ci.roleid=4 THEN 'Super'
					ELSE  'Guest' END  AS Position
		FROM bodb02.dbo.Customer c WITH(NOLOCK) 
			INNER JOIN bodb02.dbo.CustSuper cs WITH(NOLOCK) ON	(c.custid = cs.custid AND cs.IsInternal = 0 AND c.roleid = 4)
			INNER JOIN bodb02.dbo.custInfo ci WITH(NOLOCK) ON ci.custid=c.custid	
			WHERE @Username IS NULL OR( c.username LIKE @Username+'%')
		UNION ALL
		SELECT c.Username, c.custid,site,c.Currency,
				CASE WHEN ISNULL(closed,0)=1 THEN 'Closed' 
					WHEN ISNULL(reject,0)=1 THEN 'Suspended'
					WHEN ISNULL(Enabled,1)=0 THEN 'Disabled'
					ELSE 'Active' END AS Status,
				CASE WHEN ci.roleid=1 THEN 'Member'
					WHEN ci.roleid=2 THEN 'Agent'
					WHEN ci.roleid=3 THEN 'Master'
					WHEN ci.roleid=4 THEN 'Super'
					ELSE  'Guest' END  AS Position
		FROM bodb02.dbo.Customer c WITH(NOLOCK)
			INNER JOIN bodb02.dbo.custInfo ci WITH(NOLOCK) ON ci.custid=c.custid	
			WHERE c.custid NOT IN (SELECT custid FROM bodb02.dbo.Acc_CustDirect WITH(NOLOCK))
				AND c.srecommend IN (SELECT custid FROM bodb02.dbo.Acc_CustDirect WITH(NOLOCK))
				AND c.roleid=3 		
				AND (@Username IS NULL OR( c.username LIKE @Username+'%'))
		UNION ALL
		SELECT c.Username, c.custid,site,c.CurrencY,	
				CASE WHEN ISNULL(closed,0)=1 THEN 'Closed' 
					WHEN ISNULL(reject,0)=1 THEN 'Suspended'
					WHEN ISNULL(Enabled,1)=0 THEN 'Disabled'
					ELSE 'Active' END AS Status,
				CASE WHEN ci.roleid=1 THEN 'Member'
					WHEN ci.roleid=2 THEN 'Agent'
					WHEN ci.roleid=3 THEN 'Master'
					WHEN ci.roleid=4 THEN 'Super'
					ELSE  'Guest' END  AS Position
				
		FROM  bodb02.dbo.Customer c WITH(NOLOCK)
			INNER JOIN  bodb02.dbo.custInfo ci WITH(NOLOCK) ON ci.custid=c.custid	
			WHERE ci.custid NOT IN (SELECT custid from  bodb02.dbo.Acc_CustDirect WITH(NOLOCK))
				AND ci.mrecommend IN (SELECT custid from  bodb02.dbo.Acc_CustDirect WITH(NOLOCK))
				AND ci.roleid=2 	
				AND (@Username IS NULL OR( c.username LIKE @Username+'%'))
		UNION ALL
		SELECT c.Username, c.custid,CA.site,c.CurrencY,	
				CASE WHEN ISNULL(closed,0)=1 THEN 'Closed' 
					WHEN ISNULL(reject,0)=1 THEN 'Suspended'
					WHEN ISNULL(Enabled,1)=0 THEN 'Disabled'
					ELSE 'Active' END AS Status,
				CASE WHEN ci.roleid=1 THEN 'Member'
					WHEN ci.roleid=2 THEN 'Agent'
					WHEN ci.roleid=3 THEN 'Master'
					WHEN ci.roleid=4 THEN 'Super'
					ELSE  'Guest' END  AS Position
		FROM bodb02.dbo.Customer c WITH(NOLOCK)
			INNER JOIN bodb02.dbo.Customer ca (nolock) on c.recommend=ca.custid 
			INNER JOIN bodb02.dbo.custInfo ci WITH(NOLOCK) ON ci.custid=c.custid	
			WHERE c.custid NOT IN (SELECT custid from bodb02.dbo.Acc_CustDirect WITH(NOLOCK))
				AND c.recommend IN (SELECT custid from bodb02.dbo.Acc_CustDirect WITH(NOLOCK))
				AND c.roleid=1 	
				AND (@Username IS NULL OR( c.username LIKE @Username+'%'))
	)

	SELECT ROW_NUMBER() OVER(ORDER BY hed.Username ASC, t.Username  ASC) AS RowNum,
		hed.Username AS headline,t.Username, t.custid, t.Position,t.site,t.Status,e.Currency,	
		crm.IntroducedBy,a.language_name,ctr.CountryName,checker.Username AS Checker,crm.IsVIP,crm.FirstName,crm.LastName,crm.Phone,crm.Phone2,
		crm.Phone3,crm.Pic1,crm.Pic2,crm.Pic3,crm.Pic4,crm.MobilePhone,crm.Email,crm.Skype,crm.MSN,crm.WhatsApp,crm.Line,crm.WeChat,crm.Yahoo,crm.BBM,crm.QQ	
	FROM temp t
		LEFT JOIN dbo.crmCustomer crm WITH(NOLOCK) ON crm.CustID=t.custid
		INNER JOIN  bodb02.dbo.CustAccount cus WITH(NOLOCK) ON t.CustID=cus.custid
		LEFT JOIN #tempHeadline hed ON cus.groupID=hed.groupID
		LEFT JOIN dbo.crmCountry ctr ON crm.CountryID=ctr.CountryID
		LEFT JOIN bodb02.dbo.Customer checker WITH(NOLOCK) ON checker.CustID=cus.Checker
		LEFT JOIN bodb02.dbo.Exchange e WITH(NOLOCK) ON t.Currency=e.ExchangeID
		OUTER APPLY(
			SELECT Stuff((SELECT ',' + lang.Name
						 FROM  dbo.crmCustomerLanguage(nolock) clang
						 inner join dbo.crmLanguage(nolock) lang on lang.LanguageID = clang.LanguageID
						 WHERE clang.CustID = crm.CustID
						 FOR XML PATH('')), 1, 1, '')
			)A (language_name)
		WHERE  (@HeadLine IS NULL OR (hed.Custid IN (select custid FROM #tempHeadline )) )
			AND (ISNULL(@ExcludeIgnoredAcc,0)=0 OR ISNULL(crm.ignored,0) <> @ExcludeIgnoredAcc)
			ORDER BY hed.Username ASC, t.Username  ASC
	RETURN
END


CREATE TABLE #Cust_tmp(CustID INT PRIMARY KEY CLUSTERED,Position VARCHAR(30),Site VARCHAR(10),UserName VARCHAR(30),Status VARCHAR(30),Currency TINYINT,RowNum INT,
	IntroducedBy VARCHAR(50),Checker INT,IsVIP BIT,FirstName NVARCHAR(50),LastName NVARCHAR(50),Phone NVARCHAR(50),Phone2 NVARCHAR(50),
	Phone3 NVARCHAR(50),Pic1 NVARCHAR(100),Pic2 NVARCHAR(100),Pic3 NVARCHAR(100),Pic4 NVARCHAR(100),MobilePhone NVARCHAR(50),Email NVARCHAR(254),Skype NVARCHAR(100),MSN NVARCHAR(100)
	,WhatsApp NVARCHAR(100),Line NVARCHAR(100),	WeChat NVARCHAR(100),Yahoo NVARCHAR(100),BBM NVARCHAR(100),QQ NVARCHAR(100),CountryID INT,Headline VARCHAR(30)	)	
	
CREATE NONCLUSTERED INDEX [IX_RowNum] ON [dbo].#Cust_tmp 
	(
		RowNum ASC
	)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]

;WITH temp2 AS
(
	SELECT c.Username, c.custid,site,c.Currency,
			CASE WHEN ISNULL(closed,0)=1 THEN 'Closed' 
				WHEN ISNULL(reject,0)=1 THEN 'Suspended'
				WHEN ISNULL(Enabled,1)=0 THEN 'Disabled'
				ELSE 'Active' END AS Status,
			CASE WHEN ci.roleid=1 THEN 'Member'
				WHEN ci.roleid=2 THEN 'Agent'
				WHEN ci.roleid=3 THEN 'Master'
				WHEN ci.roleid=4 THEN 'Super'
				ELSE  'Guest' END  AS Position
	FROM bodb02.dbo.Customer c WITH(NOLOCK) 
		INNER JOIN bodb02.dbo.CustSuper cs WITH(NOLOCK) ON	(c.custid = cs.custid AND cs.IsInternal = 0 AND c.roleid = 4)
		INNER JOIN bodb02.dbo.custInfo ci WITH(NOLOCK) ON ci.custid=c.custid	
		WHERE @Username IS NULL OR( c.username LIKE @Username+'%')
	UNION ALL
	SELECT  c.Username, c.custid,site,c.Currency,
				CASE WHEN ISNULL(closed,0)=1 THEN 'Closed' 
					WHEN ISNULL(reject,0)=1 THEN 'Suspended'
					WHEN ISNULL(Enabled,1)=0 THEN 'Disabled'
					ELSE 'Active' END AS Status,
				CASE WHEN ci.roleid=1 THEN 'Member'
					WHEN ci.roleid=2 THEN 'Agent'
					WHEN ci.roleid=3 THEN 'Master'
					WHEN ci.roleid=4 THEN 'Super'
					ELSE  'Guest' END  AS Position
	FROM bodb02.dbo.Customer c WITH(NOLOCK)
		INNER JOIN bodb02.dbo.custInfo ci WITH(NOLOCK) ON ci.custid=c.custid	
		WHERE c.custid NOT IN (SELECT custid FROM bodb02.dbo.Acc_CustDirect WITH(NOLOCK))
			AND c.srecommend IN (SELECT custid FROM bodb02.dbo.Acc_CustDirect WITH(NOLOCK))
			AND c.roleid=3 	
			AND (@Username IS NULL OR( c.username LIKE @Username+'%'))
	UNION ALL
	SELECT  c.Username, c.custid,site,c.Currency,
				CASE WHEN ISNULL(closed,0)=1 THEN 'Closed' 
					WHEN ISNULL(reject,0)=1 THEN 'Suspended'
					WHEN ISNULL(Enabled,1)=0 THEN 'Disabled'
					ELSE 'Active' END AS Status,
				CASE WHEN ci.roleid=1 THEN 'Member'
					WHEN ci.roleid=2 THEN 'Agent'
					WHEN ci.roleid=3 THEN 'Master'
					WHEN ci.roleid=4 THEN 'Super'
					ELSE  'Guest' END  AS Position	
	FROM  bodb02.dbo.Customer c WITH(NOLOCK)
		INNER JOIN  bodb02.dbo.custInfo ci WITH(NOLOCK) ON ci.custid=c.custid	
		WHERE ci.custid NOT IN (SELECT custid from  bodb02.dbo.Acc_CustDirect WITH(NOLOCK))
			AND ci.mrecommend IN (SELECT custid from  bodb02.dbo.Acc_CustDirect WITH(NOLOCK))
			AND ci.roleid=2 	
			AND (@Username IS NULL OR( c.username LIKE @Username+'%'))
	UNION ALL
	SELECT  c.Username, c.custid,ca.site,c.Currency,
				CASE WHEN ISNULL(closed,0)=1 THEN 'Closed' 
					WHEN ISNULL(reject,0)=1 THEN 'Suspended'
					WHEN ISNULL(Enabled,1)=0 THEN 'Disabled'
					ELSE 'Active' END AS Status,
				CASE WHEN ci.roleid=1 THEN 'Member'
					WHEN ci.roleid=2 THEN 'Agent'
					WHEN ci.roleid=3 THEN 'Master'
					WHEN ci.roleid=4 THEN 'Super'
					ELSE  'Guest' END  AS Position
	FROM bodb02.dbo.Customer c WITH(NOLOCK)
		INNER JOIN bodb02.dbo.Customer ca (nolock) on c.recommend=ca.custid 
		INNER JOIN bodb02.dbo.custInfo ci WITH(NOLOCK) ON ci.custid=c.custid	
		WHERE c.custid NOT IN (SELECT custid from bodb02.dbo.Acc_CustDirect WITH(NOLOCK))
			AND c.recommend IN (SELECT custid from bodb02.dbo.Acc_CustDirect WITH(NOLOCK))
			AND c.roleid=1 	
			AND (@Username IS NULL OR( c.username LIKE @Username+'%'))
)	
INSERT INTO #Cust_tmp(UserName,CustID,Position,Site,Status,Currency,RowNum,IntroducedBy,Checker,IsVIP,FirstName,LastName,Phone,Phone2,
						Phone3,Pic1,Pic2,Pic3,Pic4,MobilePhone,Email,Skype,MSN,WhatsApp,Line,WeChat,Yahoo,BBM,QQ,CountryID,Headline	)
SELECT t.Username, t.custid, t.Position,t.site,t.Status,t.Currency,ROW_NUMBER() OVER(ORDER BY hed.Username ASC, t.Username  ASC) AS RowNum,
		crm.IntroducedBy,cus.Checker,crm.IsVIP,crm.FirstName,crm.LastName,crm.Phone,crm.Phone2,
		crm.Phone3,crm.Pic1,crm.Pic2,crm.Pic3,crm.Pic4,crm.MobilePhone,crm.Email,crm.Skype,crm.MSN,crm.WhatsApp,
		crm.Line,crm.WeChat,crm.Yahoo,crm.BBM,crm.QQ,crm.CountryID,hed.Username
FROM temp2 t	
	INNER JOIN  bodb02.dbo.CustAccount cus WITH(NOLOCK) ON t.CustID=cus.custid
	LEFT JOIN dbo.crmCustomer crm WITH(NOLOCK) ON crm.CustID=t.custid
	LEFT JOIN #tempHeadline hed ON cus.groupID=hed.groupID	
	WHERE  (@HeadLine IS NULL OR (hed.Custid IN (select custid FROM #tempHeadline )) )
		AND (ISNULL(@ExcludeIgnoredAcc,0)=0 OR ISNULL(crm.ignored,0) <> @ExcludeIgnoredAcc)

IF @TotalRows = 0  
BEGIN  
	SELECT @TotalRows = COUNT(1)
	FROM #Cust_tmp
END

SELECT t.headline,t.RowNum,t.Username, t.custid, t.Position,t.site,t.Status,e.Currency,	
	t.IntroducedBy,a.language_name,ctr.CountryName,Checker.Username AS Checker,t.IsVIP,t.FirstName,t.LastName,t.Phone,t.Phone2,
	t.Phone3,t.Pic1,t.Pic2,t.Pic3,t.Pic4,t.MobilePhone,t.Email,t.Skype,t.MSN,t.WhatsApp,t.Line,t.Line,t.WeChat,t.Yahoo,t.BBM,t.QQ	
FROM #Cust_tmp t	
	LEFT JOIN dbo.crmCountry ctr ON t.CountryID=ctr.CountryID
	LEFT JOIN bodb02.dbo.Customer checker WITH(NOLOCK) ON checker.CustID=t.Checker
	LEFT JOIN bodb02.dbo.Exchange e WITH(NOLOCK) ON t.Currency=e.ExchangeID
	OUTER APPLY(
		SELECT Stuff((SELECT ',' + lang.Name
					 FROM  dbo.crmCustomerLanguage(nolock) clang
					 inner join dbo.crmLanguage(nolock) lang on lang.LanguageID = clang.LanguageID
					 WHERE clang.CustID = t.CustID
					 FOR XML PATH('')), 1, 1, '')
		)A (language_name)
	WHERE t.RowNum BETWEEN @RowStart AND @RowEnd
	ORDER BY t.headline ASC, t.Username  ASC


GO
