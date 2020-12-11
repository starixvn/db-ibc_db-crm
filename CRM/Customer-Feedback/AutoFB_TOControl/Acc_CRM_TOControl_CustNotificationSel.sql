/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_CRM_TOControl_CustNotificationSel] 
	@LastNotifiedDate DATETIME,
	@BatchSize	INT = 10,
	@ConfigUAT	BIT = 0,
	@ConfigPRO	BIT = 1,
	@IsCredit	BIT = 1,
	@IsDeposit	BIT = 0,
	@Enviroment	VARCHAR(10) = 'LIVE'	
AS
/*
	Created: 20201126@Johnson
	Task : get customers list reach TO level to create auto feedback
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20201126@Johnson: Initial sp [redmine:#145274]
	
	Parameter's Explanation:
		- @ConfigUAT = 1: UUS customers
		- @ConfigPRO = 1: real customers
		- @IsCredit = 1: get credit customers
		- @IsDeposit = 1: get deposit customers
		- @Enviroment = 'LIVE'/'UAT' config service for each enviroment 
	
*/
BEGIN
	SET NOCOUNT ON
	
	;WITH T AS
	(
		SELECT cs.CustID,
			MatchID,
			MaxTurnOver,
			TotalTurnover,
			HouseTurnover,
			NotifiedPercentValue as ReachLevel,
			ProfileID,		
			ModifiedDatePercentValue as LastNotifiedDate,				
			CASE WHEN s.custid IS NOT NULL THEN 1 ELSE 0 END as IsDeposit,
			ci.currency
		FROM TOControl_Setting cs WITH(NOLOCK)
			INNER JOIN customer ci WITH(NOLOCK) ON cs.custid = ci.custid		
			LEFT JOIN Dep_CustSuper s WITH(NOLOCK) ON ci.srecommend = s.custid
		WHERE ModifiedDatePercentValue > @LastNotifiedDate
			AND NotifiedPercentValue >=80
			AND ci.site <> 'cn88'
	)
	SELECT TOP(@batchSize)
		CustID,
		MatchID,
		t.ProfileID,
		MaxTurnOver,
		TotalTurnover,
		HouseTurnover,
		ReachLevel,
		p.ProfileName,
		STUFF(( SELECT ','+ cast(ps.Bettype as VARCHAR(10))  as [text()]
					FROM TOControl_ProfileSetting ps WITH(NOLOCK) 
					WHERE p.ProfileID = ps.ProfileID
					FOR XML PATH('')
					),1,1,'') as Bettype,		
		LastNotifiedDate
	FROM T 
		INNER JOIN TOControl_Profile p WITH(NOLOCK) ON t.ProfileID = p.ProfileID		
	WHERE	
		1 = CASE WHEN @Enviroment = 'UAT' AND currency <> 20 THEN 0
				ELSE 1 END
		AND 1 = CASE WHEN @ConfigUAT = 1 AND currency = 20 THEN 1
					WHEN @ConfigPRO = 1 AND currency <> 20 THEN 1 
					ELSE 0 END 
		AND 1 = CASE WHEN @IsCredit = 1 AND IsDeposit = 0 THEN 1			
					WHEN @IsDeposit = 1 AND IsDeposit = 1 THEN 1
					ELSE 0 END
	ORDER BY LastNotifiedDate ASC	
END	