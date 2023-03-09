/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_MessageDel]
	  @MessageID	INT
	, @CustID		INT
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

	SET @StartRun=GETDATE()
	
	SELECT @UserID=Creator
	FROM Msg WITH (NOLOCK)
	WHERE MessageId=@MessageID

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
		WHERE m.MessageId=@MessageID AND mt.TargetId=@CustID
		FOR XML RAW('Msg'))

	--Delete Msg
	BEGIN TRY
		DELETE FROM MsgTarget WITH (ROWLOCK)
		WHERE MessageId=@MessageID AND TargetId=@CustID

		IF NOT EXISTS (SELECT 1 FROM Msg m WITH (NOLOCK)
						INNER JOIN MsgTarget mt WITH (NOLOCK) ON m.MessageId=mt.MessageId)
		BEGIN
			DELETE FROM Msg WITH (ROWLOCK)
			WHERE MessageId=@MessageID
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	--Write Log:
	SELECT @EndRun	= GETDATE(), @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun)
	
	EXEC DBCUST.Custdb.dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
					@UserID = @UserID,
					@CustID = @CustID,
					@ActionID = 1053,
					@TrackingValue = @LogSPData,
					@duration = @Duration
END
GO