/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_AutoVoidingMessageUpd]	
	@MessageIds VARCHAR(MAX) ,
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
		- @MessageIds = '<ROOT>
						<r MessageId="1074531542" MsgTargetId="1074531555,1074531556,1074531557,1074531558" />
						</ROOT>'
		
*/
BEGIN
	SET NOCOUNT ON
		
	DECLARE @tmpMessage TABLE (MessageId INT, MsgTargetId VARCHAR(MAX))
	DECLARE @xml XML = CAST(@MessageIds AS XML)	

	INSERT INTO @tmpMessage (MessageId,MsgTargetId)
	SELECT t.c.value('@MessageId[1]','int') MessageId,
		t.c.value('@MsgTargetId[1]','VARCHAR(MAX)') MsgTargetId
	FROM @xml.nodes('/ROOT/r') t(c)	
	
	IF @Environment = 'LIVE'
	BEGIN
		UPDATE cm
		SET IsProcessed = 1		
		FROM crmVoidingMessage cm WITH(UPDLOCK,ROWLOCK)
			INNER JOIN @tmpMessage t ON cm.MessageID = t.MessageID
			CROSS APPLY (
				SELECT SettingID AS MsgTargetId FROM dbo.strSplit(t.MsgTargetId, ',')
			) b
		WHERE isProcessed = 0 AND cm.MsgTargetId = b.MsgTargetId
	
	END 
	ELSE
	BEGIN
		UPDATE cm
		SET IsProcessedUAT = 1		
		FROM crmVoidingMessage cm WITH(UPDLOCK,ROWLOCK)
			INNER JOIN @tmpMessage t ON cm.MessageID = t.MessageID
			CROSS APPLY (
				SELECT SettingID AS MsgTargetId FROM dbo.strSplit(t.MsgTargetId, ',')
			) b
		WHERE IsProcessedUAT = 0  AND cm.MsgTargetId = b.MsgTargetId
	END	
END	