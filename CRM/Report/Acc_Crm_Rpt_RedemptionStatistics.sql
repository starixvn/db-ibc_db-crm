ALTER PROCEDURE Acc_Crm_Rpt_RedemptionStatistics
	@FromDate DATETIME
	,@Todate  DATETIME
	,@Subject NVARCHAR(200)=''
	,@CurrencyID NVARCHAR(200)=''
	,@ReportBy INT
	,@StatusID NVARCHAR(200)=''
AS

/*
Created: 20141124@Dom
Task : report redemption statistics
DB: DBCRM.bodb_CRM
Original:

Revisions:
	
Param's Explanation:
	@ReportBy: 1-Month; 2-Year
*/

BEGIN
	SET NOCOUNT ON;

	IF(@ReportBy=1)
	BEGIN
		SELECT  r.Subject
				,MONTH(ClaimTime) [Month]
				,YEAR(ClaimTime) [Year]
				,ISNULL(ex.Currency,'N/A') Currency
				,ClaimTime
				,r.Amount
				,r.CurrencyID
		FROM crmRedemption r WITH(NOLOCK)
		LEFT JOIN bodb02.dbo.exchange ex with(NOLOCK) ON ex.exchangeid = r.currencyid
		WHERE ClaimTime BETWEEN @FromDate AND @ToDate
			AND Subject LIKE '%'+@Subject+'%'
			AND r.CurrencyID IN(SELECT val FROM dbo.f_Split(@CurrencyID,','))
			AND r.StatusID IN(SELECT val FROM dbo.f_Split(@StatusID,','))
			AND r.StatusID <> 11004
	END
	ELSE IF(@ReportBy=2)
	BEGIN
		SELECT  r.Subject
				,YEAR(ClaimTime) [Year]
				,ClaimTime
				,ex.Currency
				,r.Amount
				,r.CurrencyID
		FROM crmRedemption r WITH(NOLOCK)
		INNER JOIN bodb02.dbo.exchange ex with(NOLOCK) ON ex.exchangeid = r.currencyid
		WHERE ClaimTime BETWEEN @FromDate AND @ToDate
			AND Subject LIKE '%'+@Subject+'%'
			AND r.CurrencyID IN(SELECT val FROM dbo.f_Split(@CurrencyID,','))
			AND r.StatusID IN(SELECT val FROM dbo.f_Split(@StatusID,','))
			AND r.StatusID <> 11004
	END
END
GO
GRANT EXECUTE ON Acc_Crm_Rpt_RedemptionStatistics TO bodbadminnet

