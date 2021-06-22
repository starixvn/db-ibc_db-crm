/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_AmendmentNoti_AutoFeedbackInfoIns] 
	@xml XML 
	,@Environment VARCHAR(20) = 'LIVE'	
	,@ErrCode INT = 0				OUTPUT
	,@ErrMsg NVARCHAR(200) = ''	OUTPUT
AS
/*
	Created: Winfred
	Task : import list customers reach Amendment Notification into CRM
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 202010303@Winfred: Initial sp [redmine:#147470]
	
	Parameter's Explanation:
		- @xml = '<ROOT>
					<r ticketid="1" custid="642291" ticketeventid="500001" bettype="3602" Seq = "1" SubmitDate = "2021-06-14 11:13:27.4026070"/>
					<r ticketid="2" custid="642292" ticketeventid="500001" bettype="3601" Seq = "1" SubmitDate = "2021-06-14 11:13:27.4026070"/>
					<r ticketid="3" custid="642293" ticketeventid="780022" bettype="801" Seq = "1" SubmitDate = "2021-06-14 11:13:27.4026070"/>
					<r ticketid="4" custid="642294" ticketeventid="780022" bettype="801" Seq = "1" SubmitDate = "2021-06-14 11:13:27.4026070"/>
				</ROOT>'
*/
BEGIN
	SET NOCOUNT ON
	
	IF @xml IS NULL OR @xml.exist('*') = 0 RETURN
	DECLARE @AffectedList VARCHAR(MAX) = '' ,@TicketEventId INT,@HeadlineID INT ,@HeadlineName VARCHAR(50), @affectedId VARCHAR(MAX), @affectedName VARCHAR(MAX), @Listbettype VARCHAR(MAX), @LogID INT
	CREATE TABLE #Result (TicketEventId INT,HeadlineID INT ,HeadlineName VARCHAR(50), affectedId VARCHAR(MAX), affectedName VARCHAR(MAX), Listbettype VARCHAR(MAX), isFinished BIT DEFAULT(0))
	-- Get List Customer reach
	DECLARE @tmpCust TABLE (
						TicketId			INT,
						CustID				INT,
						Username			VARCHAR(30),
						TicketEventId		INT,						
						Bettype				SMALLINT,
						Seq					INT,
						SubmitDate			DATETIME2,
						HeadlineID			INT,
						HeadlineName		VARCHAR(50),
						LogID				INT
						)
	
	CREATE TABLE #CustHeadline (
					CustID			INT,
					HeadlineID		INT,					
					HeadlineName	VARCHAR(50)
					)

	INSERT INTO @tmpCust(TicketId,CustID,TicketEventId,Bettype,Seq,SubmitDate)
	SELECT 
		t.c.value('@ticketid[1]','int') TicketId,
		t.c.value('@custid[1]','int') custid,	
		t.c.value('@ticketeventid[1]','int') TicketEventId,	
		t.c.value('@bettype[1]','smallint') bettype,
		t.c.value('@Seq[1]','int') Seq,
		t.c.value('@SubmitDate[1]','DATETIME2') SubmitDate
	FROM @xml.nodes('/ROOT/r') t(c)	

	 DELETE a
	 FROM @tmpCust a   
	 WHERE EXISTS (SELECT TOP 1 1 FROM crmCustAmendment fb WITH(NOLOCK)
									INNER JOIN crmAmendmentNotiFeedbackInfo b WITH(NOLOCK) ON fb.TicketEventId = b.TicketEventId
								  WHERE fb.TicketId =a.TicketId AND b.SubmitDate = a.SubmitDate )

	IF 	NOT EXISTS (SELECT TOP 1 1 FROM @tmpCust )
	BEGIN
		SELECT @ErrCode = 100 , @ErrMsg='ErrMsg="'+ ERROR_MESSAGE() + '"'
		RETURN 
	END
		
	UPDATE a
	SET a.Username = c.username
	FROM @tmpCust a
		INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON a.custid = c.custid
	
	SELECT @AffectedList =  STUFF((SELECT DISTINCT ',' + cast(custid AS VARCHAR(10))
									FROM @tmpCust
									FOR XML PATH('')), 1, 1, '')

	-- Get headline list customer
	INSERT INTO #CustHeadline(CustID,HeadlineID,HeadlineName)
	EXEC bodb02.dbo.Acc_CRM_GroupHeadlineSel @custids = @AffectedList

	UPDATE a
	SET a.HeadlineID = c.HeadlineID,a.HeadlineName = c.HeadlineName 
	FROM @tmpCust a
		INNER JOIN #CustHeadline c WITH(NOLOCK) ON a.custid = c.custid

	BEGIN TRY
		INSERT INTO #Result (TicketEventId,HeadlineID,HeadlineName,affectedId,affectedName,Listbettype)
		SELECT 
			DISTINCT
			b.TicketEventId,
			a.HeadlineID,
			a.HeadlineName,
			d.affectedId,
			e.affectedName,
			c.Bettype
		FROM #CustHeadline a
			INNER JOIN @tmpCust b on a.CustID = b.CustID
			OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(ps.Bettype as VARCHAR(10))  as [text()]
					FROM @tmpCust ps  
					WHERE ps.HeadlineID = a.HeadlineID AND ps.TicketEventId = b.TicketEventId 
					FOR XML PATH('')
					),1,1,'')
			)c (Bettype)
			OUTER APPLY(
				SELECT STUFF(( SELECT  ','+ cast(ps.CustID as VARCHAR(10))  as [text()]
					FROM @tmpCust ps
					WHERE ps.HeadlineID = a.HeadlineID AND ps.TicketEventId = b.TicketEventId 
					GROUP BY ps.CustID
					ORDER by MAX(ps.CustID)
					FOR XML PATH('')
					),1,1,'')
			)d (affectedId)
			
			OUTER APPLY(
				SELECT STUFF(( SELECT ','+ cast(ps.Username as VARCHAR(30))  as [text()]
					FROM @tmpCust ps  
					WHERE ps.HeadlineID = a.HeadlineID AND ps.TicketEventId = b.TicketEventId 
					GROUP BY ps.Username
					ORDER by MAX(ps.CustID)
					FOR XML PATH('')
					),1,1,'')
			)e (affectedName)

		WHILE (1 = 1)
		BEGIN
			UPDATE TOP (1) #Result
			SET isFinished = 1
				,@TicketEventId=TicketEventId
				,@HeadlineID=HeadlineID
				,@HeadlineName=HeadlineName
				,@affectedId=affectedId 
				,@affectedName=affectedName
				,@Listbettype= Listbettype
			WHERE isFinished = 0	
			
			IF @@ROWCOUNT = 0 OR @ErrCode<>0 BREAK 
			INSERT INTO dbo.crmAmendmentNotiFeedbackInfo (
						TicketEventId,
						HeadlineID, 
						HeadlineName, 
						ProductID, 
						RetryCount,
						affectedId,
						affectedName,
						[Status],
						MatchId,
						MatchCode,
						MessageId,
						EventType,
						ActualResult,
						WrongResult,
						CreatedDate,
						Listbettype,
						Environment,
						SubmitDate
						)
			SELECT 
						TicketEventId,
						@HeadlineID AS HeadlineID, 
						@HeadlineName AS HeadlineName, 
						ProductID, 
						0 AS RetryCount,
						@affectedId AS affectedId,
						@affectedName AS affectedName,
						'' AS [Status],
						a.MatchId,
						a.MatchCode,
						a.MessageId,
						a.EventType,
						a.ActualResult,
						a.WrongResult,
						GETDATE() AS CreatedDate,
						@Listbettype AS Listbettype,
						@Environment,
						a.SubmitDate
			FROM bodb02.dbo.TicketAmendment_Event a WITH(NOLOCK)
			WHERE a.TicketEventId  = @TicketEventId
		
			SET @LogID = SCOPE_IDENTITY()
			
			UPDATE a 
			SET a.LogID = @LogID 
			FROM @tmpCust a
			INNER JOIN #CustHeadline b on A.CustID = b.CustID
			WHERE a.TicketEventId = @TicketEventId AND b.HeadlineID = @HeadlineID
			
			INSERT INTO dbo.crmCustAmendment (
					TicketId
					,CustId
					,HeadlineID
					,LogID
					,TicketEventId
					,CreateDate
					,Bettype
					,Seq)
			SELECT A.TicketId,
				   A.CustID,
				   B.HeadlineID,
				   A.LogID,
				   A.TicketEventId,
				   GETDATE() AS CreatedDate,
				   A.Bettype,
				   A.Seq
			FROM @tmpCust a
			INNER JOIN #CustHeadline b on A.CustID = b.CustID
			WHERE a.TicketEventId = @TicketEventId AND b.HeadlineID = @HeadlineID
		END	
	  END TRY  
	  BEGIN CATCH  
			DELETE CA FROM crmCustAmendment  CA WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tmpCust B ON CA.CustID = B.CustID AND CA.TicketId = B.TicketId
		
			DELETE FROM crmAmendmentNotiFeedbackInfo WITH(ROWLOCK, UPDLOCK)
			WHERE [Status] = ''
			
			SELECT @ErrCode = 100 , @ErrMsg='ErrMsg="'+ ERROR_MESSAGE() + '"'
		
	  END CATCH 
	  
	  IF EXISTS(SELECT TOP 1 1 FROM @tmpCust t WHERE ISNULL(T.LogID,0) = 0)
	  BEGIN
			DELETE CA FROM crmCustAmendment  CA WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tmpCust B ON CA.CustID = B.CustID AND CA.TicketId = B.TicketId
		
			DELETE FROM crmAmendmentNotiFeedbackInfo WITH(ROWLOCK, UPDLOCK)
			WHERE  [Status] = ''
			
			SET @ErrCode = 100 
			SET @ErrMsg ='ERROR INSERT TICKET '+ ( SELECT  TOP 1 CAST(T.TicketId AS VARCHAR(10))
													FROM @tmpCust t WHERE ISNULL(T.LogID,0) = 0)
	  END
	  IF @ErrCode = 0 OR @ErrCode IS NULL
	  BEGIN
			UPDATE crmAmendmentNotiFeedbackInfo WITH(ROWLOCK, UPDLOCK)
			SET [Status] = 'initial'
			WHERE [Status] = '' AND LogID IN (SELECT LogID FROM @tmpCust)
	  END 	
	
	DROP TABLE #CustHeadline
		
END	