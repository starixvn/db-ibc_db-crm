/*<info serverAlias="DBMSG-bodb_Message" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_PersonalMessageIns]
	@CustList			VARCHAR(MAX),		--max 50 users
	@Title				VARCHAR(300) = NULL,
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
		- 20230308@Tacy: Create SP [RedmineID: #184753]
		- 20230509@Tacy: Write log into [crmUserLog_RunSP] instead of [UserLog_RunSP] [redmineID: #187957]
		- 20240705@Luke: Remove linked-server on DBCust [Redmine: #206895]

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

	CREATE TABLE #tbUser (
		custid INT PRIMARY KEY, 
		UserName VARCHAR(30),
		IsFinished BIT DEFAULT(0))
	
	SET @StartRun=GETDATE()

	INSERT INTO #tbUser(custid, UserName)
	SELECT custid, username 
	FROM OPENJSON(@CustList) WITH (
		custid		INT			'$.id',
		username	VARCHAR(30)	'$.name' 
	) --OPENJSON case-sensitive
	WHERE ISJSON(@CustList) = 1
	
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
			FROM #tbUser t
			WHERE IsFinished=0

			IF @@ROWCOUNT=0
				BREAK;

			INSERT dbo.MsgTarget(MessageId, TargetId, TargetName,PostTime)
			VALUES (@MessageId, @TargetId, @TargetName, GETDATE())

			SELECT @logSpData = (
					SELECT m.MessageId, m.CreatorName
						, COALESCE (CAST (m.Remark AS NVARCHAR(4000)), SPACE (1)) AS Title
						, mt.TargetName
						, COALESCE (CAST (m.Content_en AS NVARCHAR(4000)), SPACE (1)) AS Content_en
						, COALESCE (CAST (m.Content_ch AS NVARCHAR(4000)), SPACE (1)) AS Content_ch
						, COALESCE (CAST (m.Content_cs AS NVARCHAR(4000)), SPACE (1)) AS Content_cs
						, COALESCE (CAST (m.Content_th AS NVARCHAR(4000)), SPACE (1)) AS Content_th
						, COALESCE (CAST (m.Content_vn AS NVARCHAR(4000)), SPACE (1)) AS Content_vn
						, DATEDIFF(MILLISECOND, @StartRun, GETDATE()) AS Duration
					FROM Msg m WITH (NOLOCK)
					INNER JOIN MsgTarget mt WITH (NOLOCK) ON mt.MessageId=m.MessageId
					WHERE m.MessageId=@MessageId AND mt.TargetId=@TargetId
					FOR XML RAW('Msg'))

			--Write Log:
			EXEC DBCRM.bodb_CRM.dbo.WriteLog_UserLog_crmUserLog_RunSP
						@UserID = @Creator,
						@CustID = @TargetId,
						@ActionID = 1015,
						@IP = @IP,
						@NewValues = @logSpData
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH
END
GO