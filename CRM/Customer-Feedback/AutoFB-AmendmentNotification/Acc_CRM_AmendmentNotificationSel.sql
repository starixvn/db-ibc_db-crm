/*<info serverAlias="DBEXT-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_AmendmentNotificationSel] 
	@LastSeq 	INT,
	@LastSubmitDate DATETIME2,
	@BatchSizeTicket	INT = 10,
	@ConfigUAT	BIT = 0,
	@ConfigPRO	BIT = 1,
	@IsCredit	BIT = 1,
	@IsDeposit	BIT = 0,
	@Environment	VARCHAR(10) = 'LIVE'	
AS
/*
	Created: Winfred
	Task : get customers list reach Amendment Notification to create auto feedback
	DB: DBEXT/bodb02
	Original:

	Revisions:
		- 202010303@Winfred: Initial sp [redmine:#147470]
	
	Parameter's Explanation:
		- @ConfigUAT = 1: UUS customers
		- @ConfigPRO = 1: real customers
		- @IsCredit = 1: get credit customers
		- @IsDeposit = 1: get deposit customers
		- @Environment = 'LIVE'/'UAT' config service for each enviroment 
	
*/
BEGIN
	SET NOCOUNT ON
	;WITH T AS
	(
		SELECT 
			cs.TicketId,
			cs.CustID,
			cs.TicketEventId,
			cs.Bettype,				
			CASE WHEN s.custid IS NOT NULL THEN 1 ELSE 0 END as IsDeposit,
			te.Status,
			ci.currency,
			te.SubmitDate,
			cs.Seq
		FROM TicketAmendment_Detail cs WITH(NOLOCK)
			INNER JOIN customer ci WITH(NOLOCK) ON cs.custid = ci.custid		
			LEFT JOIN Dep_CustSuper s WITH(NOLOCK) ON ci.srecommend = s.custid	
			INNER JOIN TicketAmendment_Event te WITH(NOLOCK) ON te.TicketEventId = cs.TicketEventId	
		WHERE (te.SubmitDate > @LastSubmitDate OR (te.SubmitDate = @LastSubmitDate AND cs.Seq > @LastSeq))
			AND ci.site <> 'CN88'
	)
	SELECT TOP(@BatchSizeTicket)
		TicketId,
		CustID,
		TicketEventId,
		Bettype,
		Status,
		SubmitDate,
		Seq
	FROM T 
	WHERE 1= CASE WHEN t.currency = 20 AND (@ConfigUAT = 1 OR @Environment = 'UAT') THEN 1
				WHEN t.currency <> 20 AND @ConfigPRO = 1 AND @Environment <> 'UAT' THEN 1
				ELSE 0 END
		AND 1 = CASE WHEN @IsCredit = 1 AND IsDeposit = 0 THEN 1			
					WHEN @IsDeposit = 1 AND IsDeposit = 1 THEN 1
					ELSE 0 END
	ORDER BY t.TicketId ASC	
END	