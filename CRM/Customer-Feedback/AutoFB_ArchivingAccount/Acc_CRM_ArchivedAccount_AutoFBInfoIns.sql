/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ArchivedAccount_AutoFBInfoIns] 
	 @BatchSize 		INT 
	,@BatchSizeAccount	INT 
	,@MaxLogFBId		INT
	,@Environment		VARCHAR(20) = 'LIVE'	
	,@ServiceID			INT = 1	
	,@ErrCode			INT = 0	 OUTPUT
	,@ErrMsg NVARCHAR(200) = ''	OUTPUT
AS
/*
	Created: Winfred
	Task : CRM -Auto-generated FB to Headline for Archiving Dormant Accounts
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20221121@Winfred: CRM -Auto-generated FB to Headline for Archiving Dormant Accounts [redmine:#158258]
	
	Parameter's Explanation:
		- @BatchSize = 3000
*/
BEGIN
	SET NOCOUNT ON
	
	IF 	EXISTS (SELECT TOP 1 1 FROM crmArchivedAccount WITH(NOLOCK) WHERE LogFeedbackId IS NULL )
	BEGIN
		DECLARE @AffectedList VARCHAR(MAX) = '', @HeadlineID INT, @HeadlineName NVARCHAR(50), @LogFBID INT, @AffectedName NVARCHAR(MAX), @AffectedId VARCHAR(MAX), @LogIDList VARCHAR(MAX), @ArchivedDate DATE
		CREATE TABLE #CustHeadline (CustID INT, HeadlineID INT, HeadlineName NVARCHAR(50))
		CREATE TABLE #Result (HeadlineID INT ,HeadlineName NVARCHAR(50), AffectedId VARCHAR(MAX), AffectedName NVARCHAR(MAX), LogIDList VARCHAR(MAX),ArchivedDate	DATE, isFinished BIT DEFAULT(0))
		DECLARE @tmpCust TABLE (
							LogID				INT,
							LogFeedbackId		INT,
							CustID				INT,
							ArchivedDate		DATE,
							Username			VARCHAR(30),
							HeadlineID			INT,
							HeadlineName		NVARCHAR(50)
							)
		
		INSERT INTO @tmpCust(LogID, CustID, ArchivedDate)
		SELECT TOP (@BatchSizeAccount) LogID, CustId, ArchivedDate 
		FROM crmArchivedAccount WITH(NOLOCK) 
		WHERE LogFeedbackId IS NULL

		UPDATE a
		SET a.Username = c.username
		FROM @tmpCust a
			INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON a.custid = c.custid

		SELECT @AffectedList =  STUFF((SELECT DISTINCT ',' + cast(custid AS VARCHAR(20))
									FROM @tmpCust
									FOR XML PATH('')), 1, 1, '')

		---- Get headline list customer
		INSERT INTO #CustHeadline(CustID,HeadlineID,HeadlineName)
		EXEC bodb02.dbo.Acc_CRM_GroupHeadlineSel @custids = @AffectedList

		UPDATE a
		SET a.HeadlineID = c.CustID,a.HeadlineName = c.Username 
		FROM #CustHeadline a
			INNER JOIN @tmpCust c ON a.custid = c.custid
		WHERE a.HeadlineID IS NULL

		UPDATE a
		SET a.HeadlineID = c.HeadlineID,a.HeadlineName = c.HeadlineName 
		FROM @tmpCust a
			INNER JOIN #CustHeadline c WITH(NOLOCK) ON a.custid = c.custid
		
		BEGIN TRY
			INSERT INTO #Result (HeadlineID,HeadlineName,AffectedId,AffectedName,LogIDList,ArchivedDate)
			SELECT 
				DISTINCT
				a.HeadlineID,
				a.HeadlineName,
				d.AffectedId,
				e.AffectedName,
				c.LogIDList,
				b.ArchivedDate
			FROM #CustHeadline a
				INNER JOIN @tmpCust b on a.CustID = b.CustID
				OUTER APPLY(
					SELECT STUFF(( SELECT DISTINCT ','+ cast(ps.LogID AS VARCHAR(10))  as [text()]
						FROM @tmpCust ps  
						WHERE ps.HeadlineID = a.HeadlineID
						FOR XML PATH('')
						),1,1,'')
				)c (LogIDList)
				OUTER APPLY(
					SELECT STUFF(( SELECT  ','+ cast(ps.CustID AS VARCHAR(15))  as [text()]
						FROM @tmpCust ps
						WHERE ps.HeadlineID = a.HeadlineID  
						GROUP BY ps.CustID
						ORDER by MAX(ps.CustID)
						FOR XML PATH('')
						),1,1,'')
				)d (AffectedId)
				OUTER APPLY(
					SELECT STUFF(( SELECT ','+ cast(ps.Username AS NVARCHAR(50))  as [text()]
						FROM @tmpCust ps  
						WHERE ps.HeadlineID = a.HeadlineID 
						GROUP BY ps.Username
						ORDER by MAX(ps.CustID)
						FOR XML PATH('')
						),1,1,'')
				)e (AffectedName)

			WHILE (1 = 1)
			BEGIN
				UPDATE TOP (1) #Result
				SET isFinished = 1
					,@HeadlineID=HeadlineID
					,@HeadlineName=HeadlineName
					,@AffectedId=AffectedId 
					,@AffectedName=AffectedName
					,@LogIDList= LogIDList
					,@ArchivedDate = ArchivedDate
				WHERE isFinished = 0	
			
				IF @@ROWCOUNT = 0 OR @ErrCode<>0 BREAK 

				INSERT INTO crmServiceFeedbackInfo(
					 HeadlineID
					,HeadlineName
					,RetryCount
					,AffectedId
					,AffectedName
					,ArchivedDate
					,CreatedDate
					,Status
					,Environment
					,ServiceID)
				SELECT @HeadlineID, @HeadlineName , 0 AS RetryCount, @AffectedId, 
					   @AffectedName, @ArchivedDate , GETDATE() AS CreatedDate, '' AS [Status],
					   @Environment, @ServiceID

				SET @LogFBID = SCOPE_IDENTITY()

				UPDATE a 
				SET a.LogFeedbackId = @LogFBID 
				FROM @tmpCust a
				WHERE a.LogID IN (SELECT DISTINCT value FROM STRING_SPLIT(@LogIDList, ',') 
								  WHERE value <> '')
					 AND a.HeadlineID = @HeadlineID AND a.HeadlineName = @HeadlineName 
				     AND a.ArchivedDate = @ArchivedDate
			END
		END TRY  
		BEGIN CATCH  
			UPDATE a SET a.LogFeedbackId = 0 FROM @tmpCust a
		
			DELETE FROM crmServiceFeedbackInfo WITH(ROWLOCK, UPDLOCK)
			WHERE [Status] = ''
			
			SELECT @ErrCode = 100 , @ErrMsg='ErrMsg="'+ ERROR_MESSAGE() + '"'
		
		END CATCH 
		
		IF EXISTS(SELECT TOP 1 1 FROM @tmpCust t WHERE ISNULL(T.LogFeedbackId,0) = 0)
		BEGIN
			DELETE FROM crmServiceFeedbackInfo WITH(ROWLOCK, UPDLOCK)
			WHERE  [Status] = ''
			
			SET @ErrCode = 100 
			SET @ErrMsg ='ERROR INSERT CUSTOMER '+ ( SELECT TOP 1 CAST(T.LogID AS VARCHAR(10))
													FROM @tmpCust t WHERE ISNULL(T.LogFeedbackId,0) = 0)
		END
		ELSE IF @ErrCode = 0 OR @ErrCode IS NULL
		BEGIN
			UPDATE a
			SET a.LogFeedbackId = b.LogFeedbackId
			FROM crmArchivedAccount a WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tmpCust b ON a.LogID = b.LogID

			UPDATE crmServiceFeedbackInfo WITH(ROWLOCK, UPDLOCK)
			SET [Status] = 'initial'
			WHERE [Status] = '' AND LogFeedbackId IN (SELECT DISTINCT LogFeedbackId FROM @tmpCust)
		END
	END

	UPDATE fb 
	SET status = 'ignore',UpdateDate = GETDATE()
	FROM crmServiceFeedbackInfo fb  WITH(UPDLOCK,ROWLOCK)
		INNER JOIN crmCustomer c WITH(NOLOCK) ON fb.HeadlineID = c.custid
	WHERE status IN ('initial','fail') AND retryCount < 5  AND c.Ignored = 1

	SELECT TOP (@BatchSize) 
		a.LogFeedbackId
		,a.HeadlineID
		,a.HeadlineName
		,a.RetryCount
		,a.AffectedId
		,a.AffectedName
		,a.ArchivedDate
		,a.CreatedDate
		,a.UpdateDate
		,a.Status
		,a.Description
		,a.Environment
		,a.ServiceID
	FROM crmServiceFeedbackInfo a WITH(NOLOCK)
	WHERE a.LogFeedbackId > @MaxLogFBId AND status IN ('initial','fail') AND retryCount < 5
	AND a.ServiceID = @ServiceID AND Environment = @Environment

	DROP TABLE #CustHeadline, #Result	
	
END	