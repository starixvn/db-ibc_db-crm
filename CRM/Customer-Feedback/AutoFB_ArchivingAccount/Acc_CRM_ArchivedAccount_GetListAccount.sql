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
	CREATE TABLE #CustDirectAccount(CustID INT PRIMARY KEY)
	CREATE TABLE #CustDirectAccount_batch(CustID INT PRIMARY KEY)
	DECLARE @BatchNum INT = 5000

	INSERT INTO #CustDirectAccount(CustID)
	SELECT c.CustID
	FROM CustDirectAccount c WITH(NOLOCK)

	WHILE 1= 1
	BEGIN
		DELETE TOP(@BatchNum) t
		OUTPUT deleted.CustID INTO #CustDirectAccount_batch
		FROM #CustDirectAccount t

		IF @@ROWCOUNT = 0
			BREAK

		INSERT INTO  #ArchivedDirectCust(CustID, TotalDownline)
		SELECT c.CustID , ar.TotalDownline
		FROM #CustDirectAccount_batch c WITH(NOLOCK)
			INNER JOIN CustProductStatus cs WITH(NOLOCK) 
				ON cs.CustID = c.custid
				AND cs.CloseInfo > 0
			INNER JOIN dbo.Cust_ArchiveAccount ar WITH (NOLOCK) 
				ON ar.CustID = c.custid
		WHERE ar.StageID = 1 AND ar.ClosedDate >= @ArchiveDate

		TRUNCATE TABLE #CustDirectAccount_batch

	END

	--Delete all account who reopened --> create new downline -> closed again
	DELETE t
	FROM #ArchivedDirectCust t
		CROSS APPLY(SELECT COUNT(1) AS RealTotalDownline
					FROM custInfo ci WITH(NOLOCK) 
					WHERE t.CustID IN(ci.srecommend,ci.mrecommend,ci.recommend)
                      AND t.custid <> ci.custid
					)  cnt
	WHERE t.TotalDownline <> cnt.RealTotalDownline

	SELECT t.CustID, @ArchiveDate AS ArchivedDate
	FROM #ArchivedDirectCust t
	
	DROP TABLE #ArchivedDirectCust
END	