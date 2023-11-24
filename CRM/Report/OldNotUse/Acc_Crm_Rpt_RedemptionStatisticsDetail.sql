ALTER PROCEDURE Acc_Crm_Rpt_RedemptionStatisticsDetail
	@FromDate DATETIME
	,@Todate  DATETIME
	,@Subject NVARCHAR(200)=''
	,@CurrencyID NVARCHAR(200)=''
	,@StatusID NVARCHAR(200)=''
	,@TotalRows			INT			= 0 OUTPUT
	,@PageIndex			INT			= 1
	,@ItemsPerPage		INT			= 2
AS

/*
Created: 20141124@Dom
Task : report redemption statistics Detail
DB: DBCRM.bodb_CRM
Original:

Revisions:
	
Param's Explanation:
	
*/

BEGIN

	CREATE TABLE #Redemption(ID INT IDENTITY(1,1), RedemptionID INT)

		INSERT INTO #Redemption(RedemptionID)
		SELECT  r.ID
		FROM crmRedemption r WITH(NOLOCK)
		LEFT JOIN bodb02.dbo.exchange ex with(NOLOCK) ON ex.exchangeid = r.currencyid
		INNER JOIN crmcustomer ci WITH(NOLOCK) ON ci.CustID = r.CustID
		INNER JOIN crmStatus s WITH(NOLOCK) ON s.StatusID = r.StatusID 
		WHERE ClaimTime BETWEEN @FromDate AND @ToDate
			AND Subject LIKE '%'+@Subject+'%'
			AND r.CurrencyID IN(SELECT val FROM dbo.f_Split(@CurrencyID,','))
			AND r.StatusID IN(SELECT val FROM dbo.f_Split(@StatusID,','))
		
		SELECT @TotalRows=MAX(ID) FROM #Redemption
--------------------------------------------------------------------------------------------

		SELECT  r.Subject
				,r.ClaimTime
				,r.Amount
				,r.DoneBy
				,ISNULL(ex.Currency,'N/A') Currency
				,s.Name Status
				,ci.UserName
				,r.CurrencyID
		FROM crmRedemption r WITH(NOLOCK)
		INNER JOIN #Redemption t ON t.RedemptionID = r.ID
		LEFT JOIN bodb02.dbo.exchange ex with(NOLOCK) ON ex.exchangeid = r.currencyid
		INNER JOIN crmcustomer ci WITH(NOLOCK) ON ci.CustID = r.CustID
		INNER JOIN crmStatus s WITH(NOLOCK) ON s.StatusID = r.StatusID 
		WHERE t.ID BETWEEN @PageIndex*@ItemsPerPage-@ItemsPerPage+1 AND @PageIndex*@ItemsPerPage
	
END
GO

GRANT EXECUTE ON Acc_Crm_Rpt_RedemptionStatisticsDetail TO bodbadminnet