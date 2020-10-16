/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_CRM_CustWinLimitSel] 
	@BatchSize 	INT = 10,			
	@ConfigUAT 	BIT = 0,
	@ConfigPRO 	BIT = 1,	
	@LastLogID 	BIGINT = 0,
	@IsCredit 	BIT = 1,
	@IsDeposit 	BIT = 0	
AS
/*
	Created: 20201014@Johnson
	Task : get list customers reach win/loss limit
	DB: DBCUST/CustDB
	Original:

	Revisions:
		- 20201014@Johnson: Initial sp [redmine:#142194]
	
	Parameter's Explanation:
		- @ConfigUAT = 1: UUS customers
		- @ConfigPRO = 1: real customers
		- @IsCredit = 1: get credit customers
		- @IsDeposit = 1: get deposit customers
		
*/
BEGIN
	SET NOCOUNT ON
	
	;WITH T AS
	(
	SELECT LogID,
		cg.custid,
		cg.ProductID,	
		cg.GroupID,	
		LevelID, 
		MaxWinLimitSetting,
		TotalWinAmt,
		TotalWinAmt_RM,
		ModifiedDate as ReachedTime,
		BettypeIDList,
		CASE WHEN s.custid IS NOT NULL THEN 1 ELSE 0 END as IsDeposit,
		ci.currency
	FROM WinLimit_CustGameMonitoring_History cg WITH(NOLOCK)
		INNER JOIN custinfo ci WITH(NOLOCK) ON cg.custid = ci.custid		
		LEFT JOIN Dep_CustSuper s WITH(NOLOCK) ON ci.srecommend = s.custid
	WHERE LogID > @LastLogID
	)
	SELECT TOP (@BatchSize) 
		LogID,
		CustID,
		ProductID,		
		wg.GroupName as ProductGroup,
		l.LevelID,
		l.LevelName as level, 
		MaxWinLimitSetting,
		TotalWinAmt,
		TotalWinAmt_RM,
		ReachedTime,
		BettypeIDList
	FROM T
		INNER JOIN Winlimit_LevelSetting l WITH(NOLOCK) ON t.LevelID = l.LevelID
		INNER JOIN Winlimit_Group wg WITH(NOLOCK) ON t.GroupID = wg.GroupID
	WHERE 
		1 = CASE WHEN @ConfigUAT = 1 AND currency = 20 THEN 1
					WHEN @ConfigPRO = 1 AND currency <> 20 THEN 1 
					ELSE 0 END 
		AND 1 = CASE WHEN @IsCredit = 1 AND IsDeposit = 0 THEN 1			
					WHEN @IsDeposit = 1 AND IsDeposit = 1 THEN 1
					ELSE 0 END
	ORDER BY LogID ASC				
END	
	