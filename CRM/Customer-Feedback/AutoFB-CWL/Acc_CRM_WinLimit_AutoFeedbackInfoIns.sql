/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_WinLimit_AutoFeedbackInfoIns] @xml XML
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
		- 20210120@Johnson: get sports to map sub-product [redmine:#148977]
		- 20210507@Johnson: dont get sports for VS,VS2,NG mapping NA for them [redmine:#154722]
		- 20220817@Winfred: Don't generate feedback for those ignored accounts [redmine:#173914]
		- 20230214@Tacy:	CRM - Split 789y site [RedmineID: #182438]
        - 20240927@Ned.Le: CRM - Incorporate new product - Virtual Sports 5 (#207712)

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
	
	UPDATE fb 
	SET status = 'ignore',UpdatedTime = GETDATE()
	FROM crmWinLimitFeedbackInfo fb  WITH(UPDLOCK,ROWLOCK)
		INNER JOIN crmCustomer c WITH(NOLOCK) ON fb.HeadlineID = c.custid
	WHERE status IN ('initial','fail') AND retryCount < 5  AND c.Ignored = 1

	SELECT LogID
		,fb.CustID
		,ci.currency
		,ci.username
		,ag.site
		,s.SiteLabel
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
		INNER JOIN bodb02.dbo.Site s WITH (NOLOCK) ON s.site=ag.site
		LEFT JOIN crmCustomer c WITH(NOLOCK) ON fb.HeadlineID = c.custid
	WHERE status IN ('initial','fail')
		AND retryCount < 5
		
	SELECT LogID
		,CustID
		,e.currency
		,username
		,site
		,SiteLabel
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

    ;WITH
    CTE_ProductID AS (
        SELECT oa.ProductID
        FROM bodb_CRM.dbo.crmSetting s WITH (NOLOCK)
             OUTER APPLY (SELECT TRIM(value) ProductID FROM STRING_SPLIT(s.ExtraInfo, ',')) oa
        WHERE s.SettingName = 'Prevent Hardcode'
              AND s.SettingValue = 'Virtual Sport Group'
        UNION ALL
        SELECT 3 ProductID
    )
	SELECT DISTINCT LogID, s.SportType, s.SportName
	FROM bodb02.dbo.SportBettypeMatrix mt WITH(NOLOCK)		
		INNER JOIN (SELECT LogID, productid, val as bettype
					FROM #Result 
						CROSS APPLY dbo.f_CRM_strSplit(BettypeIDList,',') t
					WHERE productid NOT IN (SELECT ProductID FROM CTE_ProductID)) rs on mt.ProductID = rs.productid and mt.BetType = rs.bettype
		INNER JOIN bodb02.dbo.Sports s ON mt.sporttype = s.sporttype		
					
	DROP TABLE #Result
END	
GO