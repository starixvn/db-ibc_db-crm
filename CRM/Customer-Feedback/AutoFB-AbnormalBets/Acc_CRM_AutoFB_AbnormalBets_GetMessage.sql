/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_AutoFB_AbnormalBets_GetMessage]
	@Message XML
AS
/*
	Created: 20240109@Malcolm
	Task :  Get Message
	DB: DBMSG/bodb_Message
	Original:
	Revisions:
		- 20240109@Malcolm: Initialize SPs [Redmine: #198905]

	Param's Explanation:
	. @Message = 
		'<root>
			<r VoidingHistoryCollectionId="1" MessageId="114"/>
		</root>'
		
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Message (VoidingHistoryCollectionId INT, MessageId INT)

	INSERT INTO #Message (VoidingHistoryCollectionId, MessageId)
	SELECT DISTINCT  
		t.c.value('@VoidingHistoryCollectionId', 'INT') AS VoidingHistoryCollectionId
		,t.c.value('@MessageId', 'INT') AS MessageId
	FROM @Message.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@Message = NULL))

	SELECT m.VoidingHistoryCollectionId, m.MessageId, ms.Content_en, ms.Content_cs, ms.Content_vn AS Content_yn
	FROM #Message m
		INNER JOIN dbo.Msg ms WITH(NOLOCK) ON ms.MessageId = m.MessageId
	ORDER BY m.VoidingHistoryCollectionId
	
	DROP TABLE #Message
END
GO



