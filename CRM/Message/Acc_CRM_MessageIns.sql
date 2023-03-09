/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_MessageIns]
	@UserName			VARCHAR(MAX),		--max 50 users
	@Title				VARCHAR(MAX) = NULL,
	@Content_en			NVARCHAR(4000),
	@Content_cs			NVARCHAR(4000),
	@Content_ch			NVARCHAR(4000),
	@Content_th			NVARCHAR(4000),
	@Content_vn			NVARCHAR(4000),
	@Creator			INT,
	@CreatorName		NVARCHAR(50),
	@IsTest				BIT = 0,
	@ErrCode			INT	= 0					OUTPUT,
	@ErrMsg				NVARCHAR(200)	= ''	OUTPUT,
	@IP					VARCHAR(20)		= ''
AS
/*
	Created: 20230308@Tacy
    Task: CRM - Sending Personal Message to SMA in Alpha site
    DB: DBMSG-bodb_Message
	Original: refer SP [Dot_Msg_SetMessage]

	Revisions:
		- 20230308@Tacy: Create SP

	Param's Explanation:
		- @MsgContentsType: to identify normal message or changed settings message
				= 0 ~ Normal Data
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE	  @StartRun		DATETIME
			, @EndRun		DATETIME
			, @Duration		INT
			, @logSpData	NVARCHAR(MAX)
			, @TargetId		INT
			, @TargetName	VARCHAR(30)
			, @MessageId	INT

	DECLARE @tbUser TABLE (
			custid INT, 
			UserName VARCHAR(30),
			IsFinished BIT DEFAULT(0))

	SET @StartRun=GETDATE()
	
	--Check: exists Username
	IF EXISTS (SELECT 1 
				FROM string_split(@UserName,',') t
				WHERE NOT EXISTS (SELECT 1 FROM DBCUST.Custdb.dbo.Customer c WITH (NOLOCK)
								  WHERE c.username=RTRIM(LTRIM(t.value)))
				)
		RETURN

	INSERT INTO @tbUser (custid, UserName)
	SELECT c.Custid, c.username
	FROM DBCUST.CustDB.dbo.Customer c WITH (NOLOCK)
	CROSS APPLY (SELECT 1 val FROM string_split(@UserName,',') t
				 WHERE c.username=RTRIM(LTRIM(t.value))) t
	
	--Insert Msg
	INSERT INTO Msg (Content_ch, Content_cs, Content_th, Content_en, Content_vn,
					 MsgType,  -- 1 : message to customer (personal)
					 IsSticky, -- Is special Message or not
					 Creator, CreatorName,
					 LastUpdator, LastUpdateName, 
					 CreateTime, LastUpdateTime, PostTime, 
					 IsTest, Remark, MsgContentsType)
	VALUES(@Content_ch, @Content_cs, @Content_th, @Content_en, @Content_vn,
			1, 
			0, 
			@Creator, @CreatorName,
			@Creator, @CreatorName, 
			getdate(), getdate(), getdate(), 
			@IsTest, @Title, 100);

	SELECT @MessageId = SCOPE_IDENTITY();

	--Insert MsgTarget
	BEGIN TRY
		WHILE (1=1)
		BEGIN
			UPDATE TOP (1) t
			SET t.IsFinished=1, 
				@TargetId=t.custid, 
				@TargetName=t.UserName
			FROM @tbUser t
			WHERE IsFinished=0

			IF @@ROWCOUNT=0
				BREAK;

			INSERT dbo.MsgTarget(MessageId, TargetId, TargetName)
			VALUES (@MessageId, @TargetId, @TargetName)

			SELECT @logSpData = (
					SELECT m.MessageId, m.CreatorName
						, COALESCE (CAST (m.Remark AS NVARCHAR(4000)), SPACE (1)) AS Title
						, mt.TargetName
						, COALESCE (CAST (m.Content_en AS NVARCHAR(4000)), SPACE (1)) AS Content_en
						, COALESCE (CAST (m.Content_ch AS NVARCHAR(4000)), SPACE (1)) AS Content_ch
						, COALESCE (CAST (m.Content_cs AS NVARCHAR(4000)), SPACE (1)) AS Content_cs
						, COALESCE (CAST (m.Content_th AS NVARCHAR(4000)), SPACE (1)) AS Content_th
						, COALESCE (CAST (m.Content_vn AS NVARCHAR(4000)), SPACE (1)) AS Content_vn
						, COALESCE (CAST (@IP AS VARCHAR(20)), SPACE (1)) AS IP
					FROM Msg m WITH (NOLOCK)
					INNER JOIN MsgTarget mt WITH (NOLOCK) ON mt.MessageId=m.MessageId
					WHERE m.MessageId=@MessageId AND mt.TargetId=@TargetId
					FOR XML RAW('Msg'))

			--Write Log:
			SELECT @EndRun	= GETDATE(), @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun)
	
			EXEC DBCUST.Custdb.dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
							@UserID = @Creator,
							@CustID = @TargetId,
							@ActionID = 1051,
							@TrackingValue = @LogSPData,
							@duration = @Duration
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH
END
GO