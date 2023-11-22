/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/

USE bodb02
GO

ALTER PROCEDURE dbo.Acc_CRM_AutoFB_VoidByBetID_CleanMessage @Messages XML
AS

/*
    Created: 20231115@Ned.Le
    Task:    Clean message data
    DB:      DBACC/bodb02

    Revisions:
        20231115@Ned.Le: CRM - Auto generate Feedback and send Headline Notification for voiding Abnormal Bets by Void By BetID (#196660)

    Param's Explanation:
        @Message:
            <root>
                <r MessageId="1" MAXMsgTargetId="789" ListBetTransId="1,2,3,4" Content_en="" Content_cs=""/>
                <r MessageId="2" MAXMsgTargetId="256" ListBetTransId="5,6,7,8" Content_en="" Content_cs=""/>
            </root>
*/

BEGIN

    SET NOCOUNT ON


    -------------
    -- Parse data

    CREATE TABLE #Messages (
        MessageId      INT,
        MAXMsgTargetId INT,
        ListBetTransId VARCHAR(MAX),
        Content_en     NVARCHAR(MAX),
        Content_cs     NVARCHAR(MAX)
    )

    INSERT INTO #Messages (MessageId, MAXMsgTargetId, ListBetTransId, Content_en, Content_cs)
    SELECT t.c.value('@MessageId',      'INT')           AS MessageId,
           t.c.value('@MAXMsgTargetId', 'INT')           AS MAXMsgTargetId,
           t.c.value('@ListBetTransId', 'VARCHAR(MAX)')  AS ListBetTransId,
           t.c.value('@Content_en',     'NVARCHAR(MAX)') AS Content_en,
           t.c.value('@Content_cs',     'NVARCHAR(MAX)') AS Content_cs
    FROM @Messages.nodes('root/r') AS t(c)
    OPTION (OPTIMIZE FOR (@Messages = NULL))


    -------------
    -- Clean data
    -- + All MessageId in TicketVoiding_VoidingHistory be already created Feedback on AbnormalBet/AbnormalAccount auto service
    -- + And some of them have MsgContentsType=103
    -- + And we need to remove them from XML data at this step to avoid recreate Feedback for them again

    DELETE m
    FROM #Messages m
    WHERE EXISTS (SELECT TOP 1 1 FROM bodb02.dbo.TicketVoiding_VoidingHistory v WITH (NOLOCK) WHERE v.MessageId = m.MessageId)


    --------------
    -- Return data

    SELECT MessageId,
           MAXMsgTargetId,
           ListBetTransId,
           Content_en,
           Content_cs
    FROM #Messages


    -------------------
    -- Drop temp tables

    DROP TABLE #Messages

END
GO