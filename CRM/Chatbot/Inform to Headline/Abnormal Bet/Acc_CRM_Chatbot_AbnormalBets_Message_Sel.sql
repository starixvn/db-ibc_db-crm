/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/

USE bodb_Message
GO

ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_AbnormalBets_Message_Sel]
	@Messages XML
AS

/*
	Created: 20200811@Percy
	DB: DBMSG-bodb_Message
	Task: CRM - ChatBot - Get Message Information

	Revisions:
		- 20200811@Percy: Initialize SP [RedmineID: #130544]
		- 20210415@Malcolm: Integrate Abnormal Accounts [RedmineId : #157303]
		- 20230112@Malcolm: Scale Out for CRM [RedmineId : #181906]
        - 20231110@Ned.Le: CRM - Auto generate Feedback and send Headline Notification for voiding Abnormal Bets by Void By BetID [RedmineId : #196660]

	Param's Explanation:
		@Messages:
			<root>
				<r VoidingHistoryCollectionId = "1" MessageId="1" RequestId="1"/>
				<r VoidingHistoryCollectionId = "2" MessageId="2" RequestId="2"/>
				<r VoidingHistoryCollectionId = "3" MessageId="3" RequestId="3"/>
			</root>
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Messages (VoidingHistoryCollectionId INT, MessageId INT, RequestId INT)
	INSERT INTO  #Messages (VoidingHistoryCollectionId, MessageId, RequestId)
	SELECT
		t.c.value('@VoidingHistoryCollectionId', 'INT') AS VoidingHistoryCollectionId
		,t.c.value('@MessageId', 'INT') AS MessageId
		,t.c.value('@RequestId', 'INT') AS RequestId
	FROM @Messages.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@Messages = NULL))

	;WITH CTE_Message AS 
	(
		SELECT VoidingHistoryCollectionId, MIN(MessageId) AS MessageId
		FROM #Messages
		GROUP BY VoidingHistoryCollectionId
	)
	SELECT ms.VoidingHistoryCollectionId,
           m.MessageId,
           m.Content_en,
           m.Content_cs,
           CASE WHEN ISNULL(m.Content_th, '') = '' THEN m.Content_en ELSE m.Content_th END Content_th,
           CASE WHEN ISNULL(m.Content_vn, '') = '' THEN m.Content_en ELSE m.Content_vn END Content_vn
	FROM CTE_Message ms
		INNER JOIN dbo.Msg m WITH(NOLOCK) ON ms.MessageId = m.MessageId
	WHERE m.MsgType = 1 AND m.IsBatch = 1 AND m.Content_en LIKE '%@@%'
	ORDER BY VoidingHistoryCollectionId ASC
	
	DROP TABLE #Messages
END
GO