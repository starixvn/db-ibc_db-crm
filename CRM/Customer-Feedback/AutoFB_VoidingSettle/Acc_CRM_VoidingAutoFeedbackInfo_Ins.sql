/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_VoidingAutoFeedbackInfo_Ins] 
	@Message XML 
	,@Environment VARCHAR(20) = 'LIVE'	
	,@ErrCode INT = 0				OUTPUT
	,@ErrMsg NVARCHAR(200) = ''	OUTPUT
AS
/*
	Created: 20210908@Winfred
	Task : import list customers reach Amendment Notification into CRM
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20210908@Winfred: Integrate Auto generate Feedbacks for Voiding Settled Tickets [RedmineId : #157481]
		- 20231030@Malcolm: Add Virtual Sports 3 [RedmineId: #191355]
        - 20240126@Ned.Le: CRM - Support auto Feedback and Notification to headlines/ Accounting PIC when having Refund and Result Amendment for VS4 product [RedmineId: #200080]
		- 20240718@Luke: CRM - Incorporate new product - Virtual Sports 5 [Redmine: #207712]
	Parameter's Explanation:
		- @xml = '<ROOT>
					<r MessageId="1074531549" TransId="111882173239" CustId="2211693" UserName="P11DD07011" HeadlineID="18838369" HeadlineName="PK" MatchId="701010342" MatchCode=NULL Bettype="485" EventType="1" EventDate = "2021-06-14 11:13:27.4026070"  ProductID="1" ListMsgTargetId="1076587408,1076587409,1076587410,1076587411"/>
					<r MessageId="1074531549" TransId="111882173240" CustId="2211693" UserName="P11DD07011" HeadlineID="18838369" HeadlineName="PK" MatchId="701010342" MatchCode=NULL Bettype="486" EventType="1" EventDate = "2021-06-14 11:13:27.4026070"  ProductID="1" ListMsgTargetId="1076587408,1076587409,1076587410,1076587411"/> 
					<r MessageId="1074531549" TransId="111882173241" CustId="2211693" UserName="P11DD07011" HeadlineID="18838369" HeadlineName="PK" MatchId="701010342" MatchCode=NULL Bettype="486" EventType="1" EventDate = "2021-06-14 11:13:27.4026070" ProductID="1" ListMsgTargetId="1076587408,1076587409,1076587410,1076587411"/> 
					......................................................................
					<r MessageId="74531667" TransId="111882172362" CustId="34988541" UserName="TVKJ01AB228" HeadlineID="23834636" HeadlineName="TVKJ" MatchId="99601135" MatchCode=NULL Bettype="486" EventType="1" EventDate = "2021-06-14 11:13:27.4026070"  ProductID="1" ListMsgTargetId="16086285"/> 
				</ROOT>'
*/
BEGIN
	SET NOCOUNT ON
		
	IF @Message IS NULL OR @Message.exist('*') = 0 RETURN
	DECLARE @ProductID VARCHAR(MAX) = '' ,@MessageId INT, @ListMsgTargetId VARCHAR(MAX),
	@HeadlineID INT ,@HeadlineName VARCHAR(50), @affectedId VARCHAR(MAX), 
	@affectedName VARCHAR(MAX), @Listbettype VARCHAR(MAX), @LogVoidingID INT

	-- Get List Customer reach
	DECLARE @tmpCust TABLE (
						MessageId			INT,
						TransId				BIGINT,
						CustID				INT,
						Username			VARCHAR(30),
						Bettype				SMALLINT,
						EventType			INT,
						EventDate 			DATETIME,
						ProductID			INT,
						HeadlineID			INT,
						HeadlineName		VARCHAR(50),
						MatchId				INT,
						MatchCode			VARCHAR(100),
						MsgTargetId			VARCHAR(MAX),
						LogVoidingID		INT, 
						ListProductID		VARCHAR(MAX),
						ListBettype			VARCHAR(MAX),
						affectedId			VARCHAR(MAX),
						affectedName		VARCHAR(MAX),
						ListMsgTargetId		VARCHAR(MAX),
						isFinished			BIT DEFAULT(0)
						)
	
	INSERT INTO @tmpCust(MessageId,TransId,CustID,Username,HeadlineID,HeadlineName,MatchId,MatchCode,Bettype,EventType,EventDate,ProductID,MsgTargetId)
	SELECT 
		t.c.value('@MessageId[1]','int') MessageId,
		t.c.value('@TransId[1]','bigint') TransId,	
		t.c.value('@CustID[1]','int') CustID,	
		t.c.value('@UserName[1]','VARCHAR(30)') Username,
		t.c.value('@HeadlineID[1]','int') HeadlineID,	
		t.c.value('@HeadlineName[1]','VARCHAR(50)') HeadlineName,
		t.c.value('@MatchId[1]','int') MatchId,	
		t.c.value('@MatchCode[1]','VARCHAR(100)') MatchCode,
		t.c.value('@Bettype[1]','int') Bettype,	
		t.c.value('@EventType[1]','VARCHAR(100)') EventType,
		t.c.value('@EventDate[1]','DATETIME') EventDate,
		t.c.value('@ProductID[1]','int') ProductID,
		t.c.value('@ListMsgTargetId[1]', 'NVARCHAR(MAX)') AS MsgTargetId
	FROM @Message.nodes('/ROOT/r') t(c)	

	 DELETE a
	 FROM @tmpCust a   
	 WHERE EXISTS (SELECT TOP 1 1 FROM dbo.crmAutoFBVoiding fb WITH(NOLOCK)
								  WHERE fb.MessageId =a.MessageId AND fb.HeadlineID = a.HeadlineID )

	IF 	NOT EXISTS (SELECT TOP 1 1 FROM @tmpCust )
	BEGIN
		SELECT @ErrCode = 100 , @ErrMsg='ErrMsg="'+ ERROR_MESSAGE() + '"'
		RETURN 
	END
	
	BEGIN TRY
		UPDATE a
		SET a.ListBettype = c.Bettype, a.affectedId = d.affectedId, 
			a.affectedName = e.affectedName , a.ListProductID = f.ProductID, a.ListMsgTargetId = g.MsgTargetId
		FROM @tmpCust a
			OUTER APPLY(
				SELECT STUFF(( SELECT ','+ cast(ps.Bettype as VARCHAR(10))  as [text()]
					FROM @tmpCust ps  
					WHERE ps.HeadlineID = a.HeadlineID AND ps.MessageId = a.MessageId
					GROUP BY ps.Bettype
					ORDER by MAX(ps.Bettype) 
					FOR XML PATH('')
					),1,1,'')
			)c (Bettype)
			OUTER APPLY(
				SELECT STUFF(( SELECT  ','+ cast(ps.CustID as VARCHAR(10))  as [text()]
					FROM @tmpCust ps
					WHERE ps.HeadlineID = a.HeadlineID AND ps.MessageId = a.MessageId 
					GROUP BY ps.CustID
					ORDER by MAX(ps.CustID)
					FOR XML PATH('')
					),1,1,'')
			)d (affectedId)
			OUTER APPLY(
				SELECT STUFF(( SELECT ','+ cast(ps.Username as VARCHAR(30))  as [text()]
					FROM @tmpCust ps  
					WHERE ps.HeadlineID = a.HeadlineID AND ps.MessageId = a.MessageId 
					GROUP BY ps.Username
					ORDER by MAX(ps.CustID)
					FOR XML PATH('')
					),1,1,'')
			)e (affectedName)
			OUTER APPLY(
				SELECT STUFF(( SELECT ','+ cast(ps.ProductID as VARCHAR(30))  as [text()]
					FROM @tmpCust ps  
					WHERE ps.HeadlineID = a.HeadlineID AND ps.MessageId = a.MessageId 
					GROUP BY ps.ProductID
					ORDER by MAX(ps.CustID)
					FOR XML PATH('')
					),1,1,'')
			)f (ProductID)
			OUTER APPLY(
				SELECT STUFF(( SELECT ','+ cast(ps.MsgTargetId as VARCHAR(Max))  as [text()]
					FROM @tmpCust ps  
					WHERE ps.HeadlineID = a.HeadlineID AND ps.MessageId = a.MessageId 
					GROUP BY ps.MsgTargetId
					ORDER by MAX(ps.MsgTargetId)
					FOR XML PATH('')
					),1,1,'')
			)g (MsgTargetId)


		WHILE (1 = 1)
		BEGIN
			UPDATE TOP (1) @tmpCust
			SET isFinished = 1
				,@MessageId=MessageId
				,@HeadlineID=HeadlineID
				,@HeadlineName=HeadlineName
				,@affectedId=affectedId 
				,@affectedName=affectedName
				,@Listbettype= Listbettype
				,@ProductID= ListProductID
				,@ListMsgTargetId = ListMsgTargetId
			WHERE isFinished = 0	
			
			IF @@ROWCOUNT = 0 OR @ErrCode<>0 BREAK 
			INSERT INTO dbo.crmAutoFBVoiding (
						MessageId,
						HeadlineID, 
						HeadlineName, 
						ProductID, 
						RetryCount,
						affectedId,
						affectedName,
						ListMsgTargetId,
						Listbettype,
						CreatedDate,
						[Status],
						Environment
						)
			VALUES( 
						@MessageId ,-- MessageId,
						@HeadlineID ,-- HeadlineID, 
						@HeadlineName ,-- HeadlineName, 
						@ProductID ,--ProductID, 
						0 ,--AS RetryCount,
						@affectedId ,--AS affectedId,
						@affectedName ,--AS affectedName,
						@ListMsgTargetId, --ListMsgTargetId
						@Listbettype, --Listbettype
						GETDATE(), --CreatedDate
						'' ,--AS [Status],
						@Environment
					)
		
			SET @LogVoidingID = SCOPE_IDENTITY()
			
			--Get dynamic VS parlay bettype from crmSetting
			DECLARE @bettypes AS TABLE (bettype SMALLINT)

			INSERT INTO @bettypes (bettype)
			SELECT b.bettype 
			FROM dbo.crmSetting s WITH (NOLOCK) 
				OUTER APPLY (
					SELECT TRIM(value) AS bettype 
					FROM STRING_SPLIT(s.ExtraInfo, ',')
					WHERE value <> ''
				) AS b
			WHERE s.SettingName = 'Prevent Hardcode'
				AND s.SettingValue = 'Virtual Sport Parlay Bettype'
			UNION SELECT 9
			UNION SELECT 29

			UPDATE a 
			SET a.LogVoidingID = @LogVoidingID ,a.isFinished = 1
			FROM @tmpCust a
			WHERE a.MessageId = @MessageId AND a.HeadlineID = @HeadlineID
			--  get normal ticket
			INSERT INTO dbo.crmAutoEventVoiding (
					LogVoidingID
					,MatchId
					,MatchCode
					,EventType
					,EventDate
					,ProductID
					,CreatedDate)
			SELECT DISTINCT @LogVoidingID,
				   A.MatchId,
				   a.MatchCode,
				   A.EventType,
				   A.EventDate,
				   A.ProductID,
				   GETDATE() AS CreatedDate
			FROM @tmpCust a
			WHERE a.MessageId = @MessageId 
				AND a.HeadlineID = @HeadlineID 
				AND a.Bettype NOT IN (SELECT bettype FROM @bettypes)
			
			--  get main ticket
			
			INSERT INTO dbo.crmAutoEventVoiding (
					LogVoidingID
					,MatchId
					,MatchCode
					,EventType
					,EventDate
					,ProductID
					,CreatedDate)
			SELECT DISTINCT @LogVoidingID,
				   A.MatchId,
				   C.Username + ' : ' + b.TransId AS MatchCode,
				   A.EventType,
				   A.EventDate,
				   A.ProductID,
				   GETDATE() AS CreatedDate
			FROM @tmpCust a
			OUTER APPLY(
				SELECT STUFF(( SELECT ', '+ cast(ps.TransId as VARCHAR(30))  as [text()]
					FROM @tmpCust ps  
					WHERE ps.HeadlineID = a.HeadlineID AND ps.MessageId = a.MessageId  
							AND ps.MatchId = a.MatchId AND a.Bettype IN (SELECT bettype FROM @bettypes)
					GROUP BY ps.TransId
					ORDER by MAX(ps.TransId)
					FOR XML PATH('')
					),1,1,'')
			)b (TransId)
			OUTER APPLY(
				SELECT STUFF(( SELECT ', '+ cast(ps.Username as VARCHAR(max))  as [text()]
					FROM @tmpCust ps  
					WHERE ps.HeadlineID = a.HeadlineID AND ps.MessageId = a.MessageId  
							AND ps.MatchId = a.MatchId AND a.Bettype IN (SELECT bettype FROM @bettypes)
					GROUP BY ps.Username
					ORDER by MAX(ps.Username)
					FOR XML PATH('')
					),1,1,'')
			)c (Username)
			WHERE a.MessageId = @MessageId 
				AND a.HeadlineID = @HeadlineID 
				AND a.Bettype IN (SELECT bettype FROM @bettypes)
		END	
	  END TRY  
	  BEGIN CATCH  
			DELETE CA FROM crmAutoEventVoiding  CA WITH(ROWLOCK, UPDLOCK)
			INNER JOIN crmAutoFBVoiding B WITH(NOLOCK) ON CA.LogVoidingID = B.LogVoidingID AND B.[Status] = ''
		
			DELETE FROM crmAutoFBVoiding WITH(ROWLOCK, UPDLOCK)
			WHERE [Status] = ''
			
			SELECT @ErrCode = 100 , @ErrMsg='ErrMsg="'+ ERROR_MESSAGE() + '"'
		
	  END CATCH 
	  
	  IF EXISTS(SELECT TOP 1 1 FROM @tmpCust t WHERE ISNULL(T.LogVoidingID,0) = 0)
	  BEGIN
			DELETE CA FROM crmAutoEventVoiding  CA WITH(ROWLOCK, UPDLOCK)
			INNER JOIN crmAutoFBVoiding B WITH(NOLOCK) ON CA.LogVoidingID = B.LogVoidingID AND B.[Status] = ''
		
			DELETE FROM crmAutoFBVoiding WITH(ROWLOCK, UPDLOCK)
			WHERE [Status] = ''
			
			SET @ErrCode = 100 
			SET @ErrMsg ='ERROR INSERT MESSAGGE '+ ( SELECT  TOP 1 CAST(T.MessageId AS VARCHAR(10))
													FROM @tmpCust t WHERE ISNULL(T.LogVoidingID,0) = 0)
	  END
	  IF @ErrCode = 0 OR @ErrCode IS NULL
	  BEGIN
			UPDATE crmAutoFBVoiding WITH(ROWLOCK, UPDLOCK)
			SET [Status] = 'initial'
			WHERE [Status] = '' AND MessageId IN (SELECT MessageId FROM @tmpCust)
	  END 	
	
			
END	