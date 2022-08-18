/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_CRM_ProblemAccount_AutoFeedbackInfoIns] 
	@xml XML,
	@Enviroment VARCHAR(50) = 'LIVE'
AS
/*
	Created: 20210510@Johnson
	Task : import list customers mark problem account into CRM
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20210510@Johnson: Initial sp [redmine:#142194]
		- 20220817@Winfred: Don't generate feedback for those ignored accounts [redmine:#173914]
	Parameter's Explanation:
		- @xml = <ROOT>
					<r logid="1" custid="1000" hl="101" hlname="XT" related="1000" catid="51" />
					<r logid="2" custid="1001" hl="101" hlname="XT" related="1001" catid="52"  />
				</ROOT>
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmpCust TABLE (LogID		INT,
						CustID			INT,
						HeadlineID		INT,
						HeadlineName	VARCHAR(50),
						RelatedCustID	INT,
						CategoryID		SMALLINT					
						)
		
	INSERT INTO @tmpCust(LogID,CustID,HeadlineID,HeadlineName,RelatedCustID,CategoryID)
	SELECT t.c.value('@logid[1]','int') Logid,
		t.c.value('@custid[1]','int') custid,			
		t.c.value('@hl[1]','int') HeadlineID,
		t.c.value('@hlname[1]','varchar(50)') hlname,
		t.c.value('@related[1]','int') RelatedCustID,
		t.c.value('@catid[1]','int') CategoryID
	FROM @xml.nodes('/ROOT/r') t(c)	
		
	INSERT INTO crmProblemAccountFeedbackInfo (
						LogID
						,CustID
						,HeadlineID
						,HeadlineName
						,RelatedCustID	
						,CategoryID	
						,Status
						,CreatedDate												
						,RetryCount	
						,Enviroment
						)
	SELECT LogID
		,CustID
		,HeadlineID
		,HeadlineName
		,RelatedCustID
		,CategoryID	
		,'initial' as status
		,GETDATE() as CreatedDate
		,0 as retryCount
		,@Enviroment
	FROM @tmpCust t		
	WHERE NOT EXISTS (SELECT 1 FROM crmProblemAccountFeedbackInfo fb WITH(NOLOCK) WHERE t.LogID =fb.LogID)
	
	UPDATE fb 
	SET status = 'ignore',UpdatedTime = GETDATE()
	FROM crmProblemAccountFeedbackInfo fb  WITH(UPDLOCK,ROWLOCK)
		LEFT JOIN crmCustomer c WITH(NOLOCK) ON fb.HeadlineID = c.custid
	WHERE status IN ('initial','fail') AND retryCount < 5 AND c.CustID IS NOT NULL AND c.Ignored = 1

	SELECT LogID
		,fb.CustID		
		,ci.username		
		,HeadlineID
		,HeadlineName
		,ISNULL(c.IsVip,0) as IsVip
		,fb.RelatedCustID
		,fb.CategoryID
	FROM crmProblemAccountFeedbackInfo fb WITH(NOLOCK)		
		INNER JOIN bodb02.dbo.custinfo ci WITH(NOLOCK) ON fb.custid = ci.custid		
		LEFT JOIN crmCustomer c WITH(NOLOCK) ON fb.HeadlineID = c.custid
	WHERE status IN ('initial','fail')
		AND retryCount < 5
		AND Enviroment = @Enviroment
END	