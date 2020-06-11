/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_CRM_MessageAbnormalTicketsSel]	
	@MessageIDs VARCHAR(MAX)=''
AS
/*
	Created: 20200416@Johnson
	Task : Get last messages from voiding tickets
	DB: DBMSG/bodb_Message
	Original:

	Revisions:
		- 20200416@Johnson: Initial sp [redmine:#130949]
		- 20200611@Johnson: enhance service [redmine:#135719]
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT MessageId,Content_en,Content_cs 
	FROM Msg WITH(NOLOCK)
	WHERE MessageID IN (SELECT val FROM dbo.strSplit(@MessageIDs,','))			
	ORDER BY MessageID ASC
END	