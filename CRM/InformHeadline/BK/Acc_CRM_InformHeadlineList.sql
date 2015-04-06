ALTER PROCEDURE [dbo].[Acc_CRM_InformHeadlineList]
	@TitleID INT = 66, 
	@PageIndex INT =1, 
	@ItemsPerPage INT = 100,
	@Status VARCHAR(100)='',
	@UserName NVARCHAR(50)='',
	@CurrencyID VARCHAR(1000)='',
	@Position VARCHAR(1000)='',
	@Site VARCHAR(1000)='',
	@TotalItem INT = 0 OUTPUT
AS
/*
Created: Dom
Date: 20140509
Task : Get inform headline
DB: DBCRM.bodb_CRM
Original:

Revisions:	
	2014-12-26@Dom: Change talble to get customer info
	2015-01-13@Dom: Update Filter Site/Currency
Param's Explanation:	
	@ItemsPerPage = -1 : get all
	
*/
BEGIN

	SET NOCOUNT ON;

	DECLARE @GroupHeadLine TABLE (GroupID INT)
	
	INSERT INTO @GroupHeadLine
	SELECT DISTINCT GroupId
	FROM bodb02.dbo.CustAccount ca WITH(NOLOCK)
	INNER JOIN bodb02.dbo.CUstInfo ci WITH(NOLOCK) ON ca.CustId = ci.CustId
	INNER JOIN bodb02.dbo.Customer ag WITH(NOLOCK) ON ci.recommend = ag.CustId
	WHERE ci.RoleId=1
		AND (@Site = '' OR ag.site IN(
			SELECT SiteName FROM crmSite WITH(NOLOCK) WHERE Siteid IN(SELECT val FROM bodb02.dbo.strSplit(@site,',')) )
		)
		AND (@CurrencyID = '' OR ci.currency IN (SELECT val FROM bodb02.dbo.strSplit(@CurrencyID,',') ))
		AND ci.closed=0 AND ISNULL(ci.Reject,0)=0 AND ci.Enabled=1
	UNION
	SELECT DISTINCT GroupId
	FROM bodb02.dbo.CustAccount ca WITH(NOLOCK) 
	INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON ca.CustId = ci.CustId
	INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.CustId = ca.CustId
	WHERE ci.RoleId > 1
		AND (@Site = '' OR c.site IN(
				SELECT SiteName FROM crmSite WITH(NOLOCK) WHERE Siteid IN(SELECT val FROM bodb02.dbo.strSplit(@site,',')) )
		)
		AND (@CurrencyID = '' OR ci.currency IN (SELECT val FROM bodb02.dbo.strSplit(@CurrencyID,',') ))
		AND ci.closed=0 AND ISNULL(ci.Reject,0)=0 AND ci.Enabled=1
	------------------------------------------------------------------------------------------------------------------------
		
	DECLARE @Temp TABLE(ID INT,InformID INT)
	INSERT INTO @Temp(ID,InformID)
	SELECT ROW_NUMBER() OVER ( ORDER BY HeadlineID ASC) row,InformID
	FROM crmInformHeadline ih WITH(NOLOCK)
	INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = ih.HeadlineID
	WHERE TitleID=@TitleID 
		AND (@Status='' OR (StatusID IN( SELECT val FROM bodb02.dbo.strSplit(@Status,',')) ) )
		AND (ISNULL(@username,'')='' OR c.username like '%'+@username+'%') 
		--AND (@CurrencyID = '' OR c.currency IN (SELECT val FROM bodb02.dbo.strSplit(@CurrencyID,',') ))
		AND (@Position = '' OR c.roleid IN(SELECT val FROM bodb02.dbo.strSplit(@Position,',') ))
		--AND (@Site = '' OR c.site IN(
		--	SELECT SiteName FROM crmSite WITH(NOLOCK) WHERE Siteid IN(SELECT val FROM bodb02.dbo.strSplit(@site,',')) )
		--)
		AND ih.HeadLineId IN (SELECT CustId FROM crmHeadLine WITH(NOLOCK) WHERE GroupId IN(SELECT GroupId FROM @GroupHeadLine))
	SELECT @TotalItem=MAX(id) FROM @Temp
	IF @ItemsPerPage=-1 SET @ItemsPerPage=@TotalItem -- Export excel purpose

	--select * from crmInformHeadline where informid in  (select informid from @temp)

	SELECT ih.InformID,
			ih.HeadlineID,
			ih.TitleID,
			ih.CreatedTime,
			ih.StatusID,
			ih.UpdatedTime,
			ih.Remark,
			ISNULL(handler.username,'') Handler,
			it.Title,
			it.NoHeadline,
			ist.Name InformStatus,
			c.username HeadlineName,
			creator.username Creator,
			CASE WHEN sta.StationID IS NULL THEN 'N/A' ELSE Station END Extension,
			ih.Extension AS ExtensionID,
			ih.ProductStatus,c.Site 
	FROM @Temp t
	INNER JOIN crmInformHeadline ih WITH(NOLOCK) ON ih.InformID = t.InformID
	INNER JOIN crmInformTitle it WITH (NOLOCK) ON it.ID = ih.TitleID
	INNER JOIN crmInformStatus ist WITH(NOLOCK) ON ih.StatusID = ist.InformStatusID
	INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = ih.HeadlineID
	LEFT JOIN bodb02.dbo.Customer creator WITH(NOLOCK) ON creator.custid = ih.Creator
	LEFT JOIN bodb02.dbo.Customer handler WITH(NOLOCK) ON handler.custid = ih.UpdatedBy
	LEFT JOIN (
		SELECT SettingID AS StationID, SettingValue AS Station FROM crmSetting st WITH(NOLOCK) WHERE SettingName='Station'
	) sta ON sta.StationID = ih.Extension
	WHERE t.ID BETWEEN @PageIndex*@ItemsPerPage-@ItemsPerPage+1 AND @PageIndex*@ItemsPerPage
	ORDER BY ih.HeadlineID
	PRINT @totalitem
	
END
GO
/*

declare @p4 int
set @p4=-1
exec Acc_CRM_InformHeadlineList @ItemsPerPage=20,@Status='1,2,3,4,5,6,7',@PageIndex=1,@TotalItem=@p4 output,@TitleID=57,@Site,@username='e',@position=4
select @p4

*/
