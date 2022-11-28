/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ArchivedAccount_GetListAccount] 
AS
/*
	Created: Winfred
	Task : Get list Direct account for Archiving Dormant Accounts
	DB: DBCUST/CustDB
	Original:

	Revisions:
		- 20221121@Winfred: Get list Direct account for Archiving Dormant Accounts [redmine:#158258]
	
	Parameter's Explanation:
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @ArchiveDate DATETIME
	SELECT @ArchiveDate  = (SELECT MAX(ArchivedDate) FROM Cust_ArchiveAccount WITH(NOLOCK))

	CREATE TABLE #ArchivedDirectCust(CustID INT PRIMARY KEY,  TotalDownline INT)
	INSERT INTO  #ArchivedDirectCust(CustID, TotalDownline)
	SELECT c.CustID , ar.TotalDownline
	FROM CustDirectAccount c WITH(NOLOCK)
		INNER JOIN dbo.Cust_ArchiveAccount ar WITH (NOLOCK) 
			ON ar.CustID = c.custid
		INNER JOIN CustProductStatus cs WITH(NOLOCK) 
			ON cs.CustID = c.custid
			AND cs.CloseInfo > 0
	WHERE ar.StageID = 1 AND ar.ClosedDate = @ArchiveDate

	--Delete all account who reopened --> create new downline -> closed again
	DELETE t
	FROM #ArchivedDirectCust t
		CROSS APPLY(SELECT COUNT(1) AS RealTotalDownline
					FROM custInfo ci WITH(NOLOCK) 
					WHERE t.CustID IN(ci.srecommend,ci.mrecommend,ci.recommend)
                      AND t.custid <> ci.custid
					)  cnt
	WHERE t.TotalDownline <> cnt.RealTotalDownline

	SELECT t.CustID, @ArchiveDate AS ArchivedDate --, hlu.username AS HeadlineGroup
	FROM #ArchivedDirectCust t
		INNER JOIN custAccount ca WITH(NOLOCK) ON t.CustID = ca.custid
		INNER JOIN custAccount hl WITH(NOLOCK) ON ca.groupID = hl.groupID AND hl.IsGroupHeadLine = 1
		INNER JOIN custinfo hlu WITH(NOLOCK) ON hlu.custid = hl.custid

	DROP TABLE #ArchivedDirectCust
END	