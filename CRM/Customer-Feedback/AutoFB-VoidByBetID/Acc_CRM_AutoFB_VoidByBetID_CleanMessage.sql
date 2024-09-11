/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" isFunction="0" isNested="0"></info>*/

USE bodb02
GO

ALTER PROCEDURE dbo.Acc_CRM_AutoFB_VoidByBetID_CleanMessage @Messages       XML,
                                                            @MAXMsgTargetId INT OUTPUT
AS

/*
    Created: 20231115@Ned.Le
    Task:    Clean message data
    DB:      DBACC/bodb02

    Revisions:
        20231115@Ned.Le: CRM - Auto generate Feedback and send Headline Notification for voiding Abnormal Bets by Void By BetID (#196660)
        20231218@Ned.Le: CRM - Auto generate Feedback and Headline Notification were created and sent for non-today matches [HotFix : #198492]
        20240102@Ned.Le: CRM/Chatbot - Message Notifications for Voiding Tickets of Special Sites (ChinaView, JollySports) [RedmineId : #198905]
        20240823@Ned.Le: CRM - Void by BetID - Support Auto FB and notificaitons for voiding Parlay Ticket of Sportsbook [RedmineId : #209707]

    Param's Explanation:
        @Message:
            <root>
                <r MessageId="1" MsgTargetId="789" TargetId="101" BetTransId="1,2,3,4" CreatorName="" Content_en="" Content_cs=""/>
                <r MessageId="2" MsgTargetId="256" TargetId="102" BetTransId="5,6,7,8" CreatorName="" Content_en="" Content_cs=""/>
            </root>
*/

BEGIN

    SET NOCOUNT ON


    -------------
    -- Parse data

    CREATE TABLE #Messages (
        MessageId   INT,
        MsgTargetId INT,
        TargetId    INT,
        BetTransId  VARCHAR(MAX),
        CreatorName NVARCHAR(200),
        Content_en  NVARCHAR(MAX),
        Content_cs  NVARCHAR(MAX)
    )

    INSERT INTO #Messages (MessageId, MsgTargetId, TargetId, BetTransId, CreatorName, Content_en, Content_cs)
    SELECT t.c.value('@MessageId',   'INT')           AS MessageId,
           t.c.value('@MsgTargetId', 'INT')           AS MsgTargetId,
           t.c.value('@TargetId',    'INT')           AS TargetId,
           t.c.value('@BetTransId',  'VARCHAR(MAX)')  AS BetTransId,
           t.c.value('@CreatorName', 'NVARCHAR(200)') AS CreatorName,
           t.c.value('@Content_en',  'NVARCHAR(MAX)') AS Content_en,
           t.c.value('@Content_cs',  'NVARCHAR(MAX)') AS Content_cs
    FROM @Messages.nodes('root/r') AS t(c)
    OPTION (OPTIMIZE FOR (@Messages = NULL))


    ------------------------
    -- Output parameter data

    SELECT @MAXMsgTargetId = MAX(MsgTargetId) FROM #Messages


    -------------
    -- Clean data

    -- Clean 01
    -- + All MessageId in TicketVoiding_VoidingHistory be already created Feedback on AbnormalBet/AbnormalAccount auto service
    -- + And some of them have MsgContentsType=103
    -- + And we need to remove them from XML data at this step to avoid recreate Feedback for them again
    ;WITH
    CTE_VoidingHistory AS (
        SELECT ISNULL(MessageId, 0) MessageId FROM bodb02.dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
        UNION
        SELECT ISNULL(MessageIdSpecial, 0) MessageId FROM bodb02.dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
    )
    DELETE m
    FROM #Messages m
    WHERE EXISTS (SELECT TOP 1 1 FROM CTE_VoidingHistory v WHERE v.MessageId = m.MessageId)

    -- Clean 02
    -- + We just keep data with TargetId is member (roleid=1)
    -- + We need to do this to optimoize the way to get data between different data processes (to prevent duplicate data)
    DELETE m
    FROM #Messages m
    WHERE EXISTS (SELECT TOP 1 1 FROM bodb02.dbo.Customer cus WITH (NOLOCK) WHERE cus.roleid <> 1 AND cus.custid = m.TargetId)


    --------------
    -- Return data

    ;WITH
    -- + First, parse BetTransId to row
    CTE_first AS (
        SELECT mt.MessageId,
               bt.BetTransId,
               mt.CreatorName,
               mt.Content_en,
               mt.Content_cs
        FROM #Messages mt WITH (NOLOCK)
             CROSS APPLY (SELECT TRIM(value) BetTransId FROM STRING_SPLIT(mt.BetTransId, ',')) bt
    ),
    -- + Second, distinct BetTransId by MessageId
    CTE_second AS (
        SELECT MessageId,
               CreatorName,
               Content_en,
               Content_cs,
               BetTransId
        FROM CTE_first
        GROUP BY MessageId,
                 CreatorName,
                 Content_en,
                 Content_cs,
                 BetTransId
    ),
    -- + Final, concat BetTransId together
    CTE_final AS (
        SELECT MessageId,
               CreatorName,
               Content_en,
               Content_cs,
               STRING_AGG(CAST(BetTransId AS VARCHAR(MAX)), ',') ListBetTransId
        FROM CTE_second
        GROUP BY MessageId,
                 CreatorName,
                 Content_en,
                 Content_cs
    )
    -- + Return final data
    SELECT MessageId,
           ListBetTransId,
           CreatorName,
           Content_en,
           Content_cs
    FROM CTE_final


    -------------------
    -- Drop temp tables

    DROP TABLE #Messages

END
GO