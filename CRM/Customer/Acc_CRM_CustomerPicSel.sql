/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_CustomerPicSel]
	@CustId INT
AS
/*
	Created: 20200505@Winfred
	Task :  CRM - Special remarks renovation
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20220325@Winfred: CRM - Get PIC for special remarks renovation [RedmineId : #167941]
	
	Parameter's Explanation:

		
*/
BEGIN 
	SET NOCOUNT ON

	DECLARE @Recommend INT, @Mrecommend INT, @Srecommend INT
	CREATE TABLE #CustHeadline (CustID INT,	HeadlineID INT,	HeadlineName VARCHAR(50))
	-- Direct accounts
	SELECT @Recommend = recommend, @Mrecommend = mrecommend, @Srecommend = srecommend 
	FROM bodb02.dbo.Customer c WITH(NOLOCK)
	WHERE c.custid = @CustId
	-- Group headline
	INSERT INTO #CustHeadline(CustID,HeadlineID,HeadlineName)
	EXEC bodb02.dbo.Acc_CRM_GroupHeadlineSel @custids = @CustID

	SELECT DISTINCT m.PicID, p.Username 
	FROM dbo.crmPicManagement m WITH(NOLOCK)
		INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON p.PicID = m.PicID 
	WHERE m.CustID IN (@Recommend, @Mrecommend, @Srecommend, @CustId)
	UNION
	SELECT DISTINCT m.PicID, p.Username 
	FROM dbo.crmPicManagement m WITH(NOLOCK)
		INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON p.PicID = m.PicID 
		INNER JOIN #CustHeadline gh WITH(NOLOCK) ON gh.HeadlineID = m.HeadlineID
	
	DROP TABLE #CustHeadline
END
GO