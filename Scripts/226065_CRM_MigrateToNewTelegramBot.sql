/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/
/*
	Created: 20250505@Virgil
	Task: CRM - Migrate to new Telegram Bot [Redmine #226065]
	DB: DBCRM-bodb_CRM
*/

USE [bodb_CRM]
GO

-- Step 1: Rename Bot
UPDATE crmConversationBot WITH(ROWLOCK,UPDLOCK)
SET BotName = '247_Notification (old)'
WHERE BotId = 6331063896
	AND ChannelId = 2

-- Step 2: Update new BotID
DECLARE @tmpConversationGroupBot TABLE ([ConversationGroupId] SMALLINT)

INSERT INTO @tmpConversationGroupBot(ConversationGroupId)
SELECT ConversationGroupId
FROM crmConversationGroupBot (NOLOCK)
WHERE BotId = 6331063896

UPDATE crmConversationGroupBot WITH(ROWLOCK,UPDLOCK)
SET BotId = 7999404100  -- New BotId
WHERE ConversationGroupId IN (SELECT ConversationGroupId FROM @tmpConversationGroupBot)