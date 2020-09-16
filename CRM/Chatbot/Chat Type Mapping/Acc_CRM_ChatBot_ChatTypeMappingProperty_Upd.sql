/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,bodbExtAccNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_HeadlineUpd]
	@CustID			INT = 0,
	@Old_Headline   INT = 0,
	@New_Headline   INT = 0,
	@Username		VARCHAR(30) = '',
	@Case			INT = 0,
	@LoginIP		VARCHAR(20)='',
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT,
	@UserID			INT
AS
/*
Created: 20200916@Malcolm
Task : 
DB: DBCRM/bodb_CRM
Original:

	Revisions:		
		- 20200916@Malcolm : Update chat Type mapping property[Redmine : #130544]

*/
BEGIN
	--Remove headline

	DECLARE @Tmp TABLE (ConversationGroupId SMALLINT, HeadlineId INT)

	DELETE cgh
	OUTPUT deleted.ConversationGroupId, deleted.HeadlineId
		INTO @Tmp(ConversationGroupId, HeadlineId)
	FROM dbo.crmConversationGroupHeadline cgh WITH(ROWLOCK, UPDLOCK)
	WHERE cgh.HeadlineId = @CustID

	DELETE cgr
	FROM dbo.crmConversationGroupRecipient cgr WITH(ROWLOCK, UPDLOCK)
	WHERE NOT EXISTS(
			SELECT 1
			FROM dbo.crmConversationGroupHeadline cgh WITH(NOLOCK)
				INNER JOIN @Tmp t ON t.ConversationGroupId = cgh.ConversationGroupId
			WHERE cgr.ConversationGroupId = cgh.ConversationGroupId
		)


	-- Change Headline 

	UPDATE cgh
		SET cgh.HeadlineId = @New_Headline
	FROM dbo.crmConversationGroupHeadline cgh WITH(ROWLOCK)
	WHERE cgh.HeadlineId = @Old_Headline

	--remove direct accounts


END