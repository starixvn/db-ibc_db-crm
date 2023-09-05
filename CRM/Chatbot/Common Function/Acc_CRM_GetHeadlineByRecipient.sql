/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_GetHeadlineByRecipient]
	@RecipientIds VARCHAR(MAX) = ''
AS
/*
	Created: 20200511@Malcolm
	Task :  CRM - Staff/Boss Management of headline
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20200827@Malcolm: Initialize Sps [Redmine: #108739]
		- 20201126@Malcolm: Change bodb02.dbo.f_StringSplit to dbo.f_CRM_strSplit [Redmine: #144265]
		- 20230508@Malcolm: Offer Telegram bot service for Headlines [RedmineId : #179119]
	Param's Explanation:
		
*/
BEGIN 
	SET NOCOUNT ON

	SELECT @RecipientIds = ISNULL(@RecipientIds, '')

	CREATE TABLE #Customer (CustId INT, HeadlineId INT)
	CREATE TABLE #Headlines (HeadlineId INT, HeadlineName VARCHAR(30))
	CREATE TABLE #Recipient (RecipientId INT PRIMARY KEY)

	DECLARE @NumberOfRecipient INT = 0

	INSERT INTO #Recipient (RecipientId)
	SELECT DISTINCT f.value
	FROM STRING_SPLIT(@RecipientIds,',') f

	SELECT @NumberOfRecipient = COUNT(1) FROM #Recipient

	INSERT INTO #Customer(CustId, HeadlineId)
	SELECT m.CustId, MAX(m.HeadlineID)
	FROM dbo.crmPicManagement m WITH(NOLOCK)
		INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.SourceId = m.PicID AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
	WHERE EXISTS(SELECT 1 FROM #Recipient ri WHERE r.RecipientId = ri.RecipientId)
	GROUP BY m.CustID
	HAVING COUNT(PicID) = @NumberOfRecipient
		
	INSERT INTO #Headlines(HeadlineId)
	SELECT DISTINCT HeadlineId
	FROM #Customer

    UPDATE h
		SET h.HeadlineName = CASE WHEN h.HeadlineId = 0 THEN 'Not Assigned Group' ELSE c.username END
	FROM #Headlines h
		LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON h.HeadlineId = c.custid

	SELECT 
		h.HeadlineId,
		h.HeadlineName
	FROM #Headlines h
	ORDER BY CASE WHEN h.HeadlineId = 0 THEN 1 ELSE 0 END, h.HeadlineName ASC

	SELECT
		ct.username
	FROM #Customer c
		INNER JOIN bodb02.dbo.Customer ct WITH(NOLOCK) ON c.CustId = ct.custid
	WHERE HeadlineId = 0
	ORDER BY ct.username

	DROP TABLE #Headlines
	DROP TABLE #Customer
	DROP TABLE #Recipient
END
GO