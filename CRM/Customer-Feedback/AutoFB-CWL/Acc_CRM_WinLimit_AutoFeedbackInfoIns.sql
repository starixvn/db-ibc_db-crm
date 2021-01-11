/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_CRM_WinLimit_AutoFeedbackInfoIns] 
	@xml XML	
AS
/*
	Created: 20201015@Johnson
	Task : import list customers reach win/loss limit into CRM
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20201015@Johnson: Initial sp [redmine:#142194]
		- 20201123@Johnson: get VIP status & productID to check language for 789y headline [redmine:#145836]
		- 20210108@Johnson: get ProductName En only [redmine:#145274]
	Parameter's Explanation:
		- @xml = <ROOT>
					<r logid="1" custid="1000" hl="101" hlname="XT" related="1000" product="21" group="Allbet Casino" level="Orange" limitsetting="20000" winamount="25000" winamountRM="25000" time="2020-10-10 10:15:12" bettype="2401,2403" />
					<r logid="2" custid="1001" hl="101" hlname="XT" related="1001" product="21" group="Allbet Casino" level="Yellow" limitsetting="30000" winamount="35000" winamountRM="35000" time="2020-10-10 10:15:25" bettype="2401,2403" />
				</ROOT>
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmpCust TABLE (LogID		INT,
						CustID			INT,
						HeadlineID		INT,
						HeadlineName	VARCHAR(50),
						RelatedCustID	INT,
						ProductID		INT,
						ProductGroup	VARCHAR(200),
						Level			VARCHAR(50),
						MaxWinLimitSetting	MONEY,
						TotalWinAmt		MONEY,
						TotalWinAmt_RM	MONEY,
						ReachedTime		DATETIME,
						BettypeIDList	VARCHAR(1024)						
						)
		
	INSERT INTO @tmpCust(LogID,CustID,HeadlineID,HeadlineName,RelatedCustID,ProductID,ProductGroup,
						Level,MaxWinLimitSetting,TotalWinAmt,TotalWinAmt_RM,ReachedTime,BettypeIDList)
	SELECT t.c.value('@logid[1]','int') Logid,
		t.c.value('@custid[1]','int') custid,			
		t.c.value('@hl[1]','int') HeadlineID,
		t.c.value('@hlname[1]','varchar(50)') hlname,
		t.c.value('@related[1]','int') RelatedCustID,
		t.c.value('@product[1]','int') ProductID,			
		t.c.value('@group[1]','varchar(200)') productGroup,
		t.c.value('@level[1]','varchar(50)') Level,
		t.c.value('@limitsetting[1]','money') MaxWinLimitSetting,
		t.c.value('@winamount[1]','money') TotalWinAmt,
		t.c.value('@winamountRM[1]','money') TotalWinAmt_RM,		
		t.c.value('@time[1]','datetime') ReachedTime,
		t.c.value('@bettype[1]','varchar(1024)') BettypeIDList
	FROM @xml.nodes('/ROOT/r') t(c)	
	
	INSERT INTO crmWinLimitFeedbackInfo (
						LogID
						,CustID
						,HeadlineID
						,HeadlineName
						,RelatedCustID
						,ProductID
						,ProductGroup
						,Level
						,MaxWinLimitSetting
						,TotalWinAmt
						,TotalWinAmt_RM
						,ReachedTime
						,BettypeIDList		
						,Status
						,CreatedDate												
						,RetryCount	
						)
	SELECT LogID
		,CustID
		,HeadlineID
		,HeadlineName
		,RelatedCustID
		,ProductID
		,ProductGroup
		,Level
		,MaxWinLimitSetting
		,TotalWinAmt
		,TotalWinAmt_RM
		,ReachedTime
		,BettypeIDList	
		,'initial' as status
		,GETDATE() as CreatedDate
		,0 as retryCount
	FROM @tmpCust t		
	WHERE NOT EXISTS (SELECT 1 FROM crmWinLimitFeedbackInfo fb WITH(NOLOCK) WHERE t.LogID =fb.LogID)
	
	SELECT LogID
		,fb.CustID
		,ci.currency
		,ci.username
		,ag.site
		,HeadlineID
		,HeadlineName
		,ISNULL(c.IsVip,0) as IsVip
		,fb.RelatedCustID
		,fb.ProductID
		,p.ProductName
		,fb.ProductGroup
		,Level
		,MaxWinLimitSetting
		,TotalWinAmt
		,TotalWinAmt_RM
		,ReachedTime
		,BettypeIDList	
	INTO #Result	
	FROM crmWinLimitFeedbackInfo fb WITH(NOLOCK)		
		INNER JOIN bodb02.dbo.Products p WITH(NOLOCK) ON fb.ProductID = p.ProductID
		INNER JOIN bodb02.dbo.custinfo ci WITH(NOLOCK) ON fb.custid = ci.custid
		INNER JOIN bodb02.dbo.customer ag WITH(NOLOCK) ON ci.recommend = ag.custid
		LEFT JOIN crmCustomer c WITH(NOLOCK) ON fb.HeadlineID = c.custid
	WHERE status IN ('initial','fail')
		AND retryCount < 5
		
	SELECT LogID
		,CustID
		,e.currency
		,username
		,site
		,HeadlineID
		,HeadlineName
		,IsVip
		,RelatedCustID
		,ProductID
		,ProductName
		,ProductGroup
		,Level
		,MaxWinLimitSetting
		,TotalWinAmt
		,TotalWinAmt_RM
		,ReachedTime
		,BettypeIDList 
	FROM #Result rs
		INNER JOIN bodb02.dbo.Exchange e WITH(NOLOCK) ON rs.currency = e.ExchangeID
	
	SELECT typeid as bettype, typenamee as Name
	FROM bodb02.dbo.bettype WITH(NOLOCK)
	WHERE typeid IN (SELECT val
					FROM #Result
						CROSS APPLY (SELECT val from dbo.f_crm_strSplit(BettypeIDList,','))t
					)
	
	DROP TABLE #Result
END	
	
	
	