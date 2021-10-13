/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_AutoVoidingMessageSel]	
	@BatchSize 	INT  ,
	@Environment	VARCHAR(10) = 'LIVE',
	@LastDateUAT DATETIME 
AS
/*
	Created: 20210908@Winfred
	Task : List messages voiding settle need to create FB
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20210908@Winfred: Integrate Auto generate Feedbacks for Voiding Settled Tickets [RedmineId : #157481]
	
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	--Get top new messages
	;WITH tmp AS 
	(	
		SELECT DISTINCT TOP (@BatchSize) MessageId
		FROM crmVoidingMessage WITH(NOLOCK)
		WHERE ((IsProcessed = 0 AND  @Environment = 'LIVE') OR( @Environment <> 'LIVE' AND IsProcessedUAT = 0 AND CreatedDate >= @LastDateUAT)) 		
		ORDER BY MessageId ASC
	)
	SELECT MessageId, MsgTargetId,ISNULL(BetTransId, '') AS BetTransId 
	FROM crmVoidingMessage c WITH(NOLOCK)
	WHERE MessageId IN (SELECT MessageId FROM tmp)
		AND ((IsProcessed = 0 AND  @Environment = 'LIVE') OR( @Environment <> 'LIVE' AND IsProcessedUAT = 0 AND CreatedDate >= @LastDateUAT)) 
	
END
GO		