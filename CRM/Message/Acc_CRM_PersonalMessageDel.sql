/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_PersonalMessageDel]
	  @MessageID	INT
	, @ErrCode		INT				= 0		OUTPUT
	, @ErrMsg		NVARCHAR(200)	= ''	OUTPUT
	, @IP			VARCHAR(20)		= ''
AS
/*
	Created: 20230308@Tacy
    Task: CRM - Sending Personal Message to SMA in Alpha site
    DB: DBMSG-bodb_Message

	Revisions:
		- 20230308@Tacy: Create SP

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE	  @StartRun		DATETIME
			, @EndRun		DATETIME
			, @Duration		INT
			, @logSpData	NVARCHAR(MAX)
			, @UserID		INT
			, @CustID		INT

	DECLARE @tbCust TABLE (
				CustID INT PRIMARY KEY, 
				IsFinished BIT DEFAULT(0)
	)

	SET @StartRun=GETDATE()
	
	INSERT INTO @tbCust (CustID)
	SELECT TargetId
	FROM MsgTarget WITH (NOLOCK)
	WHERE MessageId=@MessageID

	SELECT @UserID=Creator
	FROM Msg WITH (NOLOCK)
	WHERE MessageId=@MessageID

	--Delete Msg
	BEGIN TRY
		UPDATE MsgTarget WITH (ROWLOCK, UPDLOCK)
		SET isDeleted=1
		WHERE MessageId=@MessageID

		UPDATE Msg WITH (ROWLOCK, UPDLOCK)
		SET isDeleted=1
		WHERE MessageId=@MessageID
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	WHILE (1=1)
	BEGIN
		UPDATE TOP (1) t
		SET t.IsFinished=1, @CustID=t.CustID
		FROM @tbCust t 
		WHERE T.IsFinished=0

		IF @@ROWCOUNT=0
			BREAK;

		SELECT @logSpData = (
			SELECT m.MessageId, m.CreatorName
				, COALESCE (CAST (m.remark AS NVARCHAR(4000)), SPACE (1)) AS Title
				, TargetName
				, COALESCE (CAST (m.Content_en AS NVARCHAR(4000)), SPACE (1)) AS Content_en
				, COALESCE (CAST (m.Content_ch AS NVARCHAR(4000)), SPACE (1)) AS Content_ch
				, COALESCE (CAST (m.Content_cs AS NVARCHAR(4000)), SPACE (1)) AS Content_cs
				, COALESCE (CAST (m.Content_th AS NVARCHAR(4000)), SPACE (1)) AS Content_th
				, COALESCE (CAST (m.Content_vn AS NVARCHAR(4000)), SPACE (1)) AS Content_vn
				, COALESCE (CAST (@IP AS VARCHAR(20)), SPACE (1)) AS IP
			FROM Msg m WITH (NOLOCK)
			INNER JOIN MsgTarget mt WITH (NOLOCK) ON mt.MessageId=m.MessageId
			WHERE TargetId=@CustID
			FOR XML RAW('Msg'))

		--Write Log:
		SELECT @EndRun	= GETDATE(), @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun)
	
		EXEC DBCUST.Custdb.dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
						@UserID = @UserID,
						@CustID = @CustID,
						@ActionID = 1053,
						@TrackingValue = @LogSPData,
						@duration = @Duration
	END
END
GO