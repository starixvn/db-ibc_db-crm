/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_FailVoidingMessageSel]		
AS
/*
	Created: 20210908@Winfred
	Task : get list messageid fail for creating fb
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20210908@Winfred: Integrate Auto generate Feedbacks for Voiding Settled Tickets [RedmineId : #157481]
	
	Param's Explanation:		
*/
BEGIN
	SET NOCOUNT ON
		
	SELECT DISTINCT a.MessageID, b.MsgTargetId,c.CreatedDate, c.BetTransId
	FROM dbo.crmAutoFBVoiding a WITH(NOLOCK)
	CROSS APPLY (
				SELECT SettingID AS MsgTargetId FROM dbo.strSplit(a.ListMsgTargetId, ',')
			) b
	INNER JOIN crmVoidingMessage c WITH(NOLOCK) ON a.MessageID = c.MessageID  AND c.MsgTargetId = b.MsgTargetId
	WHERE a.status IN ('initial','fail')
		AND retryCount < 5	
		
		
		
END	