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
	

	DECLARE @___GroupId				INT,
			@___NumberOfRecipient	INT,
			@___NumberOfHeadline	INT,
			@___HeadlineXML			XML, 
			@___RecipientXML		XML,
			@___LanguageXML			XML,
			@___BotXML				XML,
			@OldValues				NVARCHAR(MAX),
			@NewValues              NVARCHAR(MAX)

	DECLARE @TmpRecipient	TABLE (RecipientId INT)
	DECLARE @TmpGroup	TABLE (ConversationGroupId INT)
	DECLARE @TmpGroupHeadline TABLE (ConversationGroupId SMALLINT, HeadlineId INT)
	DECLARE @TmpGroupRecipient TABLE (ConversationGroupId SMALLINT, RecipientId INT)

	--Remove headline
	IF @Case = 2
	BEGIN
		DELETE cgh
		OUTPUT deleted.ConversationGroupId, deleted.HeadlineId
			INTO @TmpGroupHeadline(ConversationGroupId, HeadlineId)
		FROM dbo.crmConversationGroupHeadline cgh WITH(ROWLOCK, UPDLOCK)
		WHERE cgh.HeadlineId = @CustID

		DELETE cgr
		OUTPUT deleted.ConversationGroupId, deleted.RecipientId
			INTO @TmpGroupRecipient (ConversationGroupId, RecipientId)
		FROM dbo.crmConversationGroupRecipient cgr WITH(ROWLOCK, UPDLOCK)
		WHERE NOT EXISTS(
				SELECT 1
				FROM dbo.crmConversationGroupHeadline cgh WITH(NOLOCK)
					INNER JOIN @TmpGroupHeadline t ON t.ConversationGroupId = cgh.ConversationGroupId
				WHERE cgr.ConversationGroupId = cgh.ConversationGroupId
			)	

		DECLARE Cursor_Group CURSOR FOR SELECT ConversationGroupId FROM @TmpGroupHeadline

		OPEN Cursor_Group;

		FETCH NEXT FROM Cursor_Group INTO @___GroupId

		WHILE @@FETCH_STATUS = 0
		BEGIN
			--Both (Old/new values is unchanged)
			SELECT @___LanguageXML = 
			(
				SELECT t.LanguageId AS '@Id', s.SettingValue AS '@Name'
				FROM dbo.crmConversationGroup t 
					INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingID = t.LanguageId
				WHERE t.ConversationGroupId = @___GroupId
				FOR XML PATH('Language')
			)

			SELECT @___BotXML = 
			(
				SELECT t.BotId AS '@Id', cb.BotName AS '@Name'
				FROM dbo.crmConversationGroupBot t
					INNER JOIN dbo.crmConversationBot cb WITH(NOLOCK) ON cb.BotId = t.BotId
				WHERE t.ConversationGroupId = @___GroupId
				FOR XML PATH('Bot')
			)

			-- Old Values
			SELECT @___HeadlineXML =	
			(
				SELECT  t.HeadlineId AS '@Id', 
						CASE WHEN  t.HeadlineId = 0 THEN 'Not Assigned Group' 
						ELSE c.username END AS '@Name'
				FROM @TmpGroupHeadline t
						LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = t.HeadlineId
				WHERE t.ConversationGroupId = @___GroupId
				FOR XML PATH('Headline')
			)

			IF EXISTS(SELECT 1FROM @TmpGroupRecipient tgr WHERE tgr.ConversationGroupId = @___GroupId)
			BEGIN
				SELECT @___RecipientXML = 
				(
					SELECT t.RecipientId AS '@Id', 
	    					 p.Username AS '@Name', 
	    					 r.RecipientTypeId AS '@RecipientTypeId', 
	    					 rt.RecipientTypeName AS '@RecipientTypeName'
					FROM @TmpGroupRecipient t
						INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId = t.RecipientId
						INNER JOIN dbo.crmRecipientType rt WITH(NOLOCK) ON r.RecipientTypeId = rt.RecipientTypeId
 						INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON p.PicID = r.SourceId
					WHERE t.ConversationGroupId = @___GroupId AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
					FOR XML PATH('Recipient')
				)
			END
			ELSE 
			BEGIN
				SELECT @___RecipientXML = 
				(
					SELECT t.RecipientId AS '@Id', 
	    					 p.Username AS '@Name', 
	    					 r.RecipientTypeId AS '@RecipientTypeId', 
	    					 rt.RecipientTypeName AS '@RecipientTypeName'
					FROM dbo.crmConversationGroupRecipient t
						INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId = t.RecipientId
						INNER JOIN dbo.crmRecipientType rt WITH(NOLOCK) ON r.RecipientTypeId = rt.RecipientTypeId
 						INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON p.PicID = r.SourceId
					WHERE t.ConversationGroupId = @___GroupId AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
					FOR XML PATH('Recipient')
				)
			END

			SELECT @OldValues =	CAST((SELECT t.ConversationGroupId AS '@Id',
									 t.ConversationGroupName AS '@Name',
									 t.ConversationId AS '@LetstalkID',
									 t.Remark AS '@Remark',
									 @___BotXML,
									 @___HeadlineXML,
									 @___RecipientXML,
									 @___LanguageXML
							FROM dbo.crmConversationGroup t
							WHERE t.ConversationGroupId = @___GroupId
							FOR XML PATH('ConversationGroup'), ROOT('Acc_CRM_ChatBot_ChatTypeMapping_Upd'))
						AS NVARCHAR(MAX))
			-- New Values
			FETCH NEXT FROM Cursor_Group INTO @___GroupId
		END
		
	END
	-- Change Headline 
	IF @Case IN (3,4)
	BEGIN
		UPDATE cgh
			SET cgh.HeadlineId = @New_Headline
		FROM dbo.crmConversationGroupHeadline cgh WITH(ROWLOCK)
		WHERE cgh.HeadlineId = @Old_Headline
	END
	--remove direct accounts

	IF @Case = 1 AND @New_Headline <> 0
	BEGIN
		INSERT INTO @TmpRecipient (RecipientId)
		SELECT r.RecipientId 
		FROM dbo.crmPicManagement m WITH(NOLOCK) 
			INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.SourceId = m.PicID
		WHERE m.CustID = @CustID
			AND r.DataSource = 'bodb_CRM.dbo.crmPIC' 

		INSERT INTO @TmpGroup (ConversationGroupId)
		SELECT cgh.ConversationGroupId
		FROM dbo.crmConversationGroupHeadline cgh WITH(NOLOCK)
		WHERE cgh.HeadlineId = @New_Headline
	
		DELETE t
		FROM @TmpGroup t
		WHERE EXISTS(
				SELECT 1
				FROM dbo.crmConversationGroupRecipient cgr WITH(NOLOCK)
					LEFT JOIN @TmpRecipient p ON p.RecipientId = cgr.RecipientId
				WHERE p.RecipientId IS NULL AND cgr.ConversationGroupId = t.ConversationGroupId
			)

		DECLARE Cursor_TmpGroup CURSOR
		FOR SELECT ConversationGroupId FROM @TmpGroup

		OPEN Cursor_TmpGroup;

		FETCH NEXT FROM Cursor_TmpGroup INTO @___GroupId

		WHILE @@FETCH_STATUS = 0
		BEGIN
			SELECT @___NumberOfRecipient = COUNT(*) 
			FROM dbo.crmConversationGroupRecipient  cgr WITH(NOLOCK) 
			WHERE cgr.ConversationGroupId = @___GroupId

			SELECT @___NumberOfHeadline = COUNT(*)
			FROM dbo.crmConversationGroupHeadline cgh WITH(NOLOCK)
			WHERE cgh.ConversationGroupId = @___GroupId

			IF NOT EXISTS(SELECT 1
					FROM dbo.crmPicManagement m WITH(NOLOCK)
						INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.SourceId = m.PicID
						INNER JOIN dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) ON cgr.RecipientId = r.RecipientId
					WHERE cgr.ConversationGroupId = @___GroupId AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
					GROUP BY m.CustID
					HAVING COUNT(PicId) = @___NumberOfRecipient)
			BEGIN
				IF @___NumberOfHeadline = 1
				BEGIN
					DELETE cgr
					FROM dbo.crmConversationGroupRecipient cgr WITH(ROWLOCK, UPDLOCK)
					WHERE cgr.ConversationGroupId = @___GroupId
				END

				DELETE dbo.crmConversationGroupHeadline WITH(ROWLOCK, UPDLOCK)
				WHERE ConversationGroupId = @___GroupId
			END

			FETCH NEXT FROM Cursor_TmpGroup INTO @___GroupId;
		END

		CLOSE Cursor_TmpGroup

		DEALLOCATE Cursor_TmpGroup
	END

END

GO