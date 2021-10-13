/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_VoidingAutoFeedbackInfo_BatchUpd]	
	@LogVoidingID 	INT,	
	@Status 	VARCHAR(20),
	@Description VARCHAR(1000),
	@Environment	VARCHAR(10) = 'LIVE'
AS
/*
	Created: 20210908@Winfred
	Task : update status list messageid fail for creating fb 
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20210908@Winfred: Integrate Auto generate Feedbacks for Voiding Settled Tickets [RedmineId : #157481]
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	
	UPDATE crmAutoFBVoiding WITH(UPDLOCK,ROWLOCK)
	SET status = @status,
		RetryCount = CASE WHEN @status = 'fail' THEN retrycount + 1 ELSE retrycount END,
		Description = @Description,
		UpdatedTime = GETDATE()
	WHERE LogVoidingID = @LogVoidingID
	
	IF @Environment = 'LIVE'
	BEGIN
		UPDATE cm
		SET IsProcessed = 1		
		FROM crmVoidingMessage cm WITH(UPDLOCK,ROWLOCK)
			INNER JOIN crmAutoFBVoiding t WITH(NOLOCK) ON cm.MessageID = t.MessageID
			CROSS APPLY (
				SELECT SettingID AS MsgTargetId FROM dbo.strSplit(t.ListMsgTargetId, ',')
			) b
		WHERE isProcessed = 0 AND t.LogVoidingID = @LogVoidingID AND cm.MsgTargetId = b.MsgTargetId
	END 
	ELSE
	BEGIN
		UPDATE cm
		SET IsProcessedUAT = 1		
		FROM crmVoidingMessage cm WITH(UPDLOCK,ROWLOCK)
			INNER JOIN crmAutoFBVoiding t WITH(NOLOCK) ON cm.MessageID = t.MessageID
			CROSS APPLY (
				SELECT SettingID AS MsgTargetId FROM dbo.strSplit(t.ListMsgTargetId, ',')
			) b
		WHERE IsProcessedUAT = 0  AND t.LogVoidingID = @LogVoidingID AND cm.MsgTargetId = b.MsgTargetId
	END	
END	