/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_CRM_MessageAbnormalTicketsSel]
	@BatchSize INT,
	@LastMsgID INT
AS
/*
	Created: 20200416@@Johnson
	Task : Get last messages from voiding tickets
	DB: DBMSG/bodb_Message
	Original:

	Revisions:
		- 20200416@@Johnson: Initial sp [redmine:#130949]
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT TOP (@BatchSize) MessageId,Content_en,Content_cs 
	FROM Msg WITH(NOLOCK)
	WHERE MessageID > @LastMsgID
		AND MsgContentsType = 103
	ORDER BY MessageID ASC
	
END	