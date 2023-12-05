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
                <r MessageId="1" MsgTargetId="789" TargetId="101" BetTransId="1,2,3,4" Content_en="" Content_cs=""/>
                <r MessageId="2" MsgTargetId="256" TargetId="102" BetTransId="5,6,7,8" Content_en="" Content_cs=""/>
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
        Content_en  NVARCHAR(MAX),
        Content_cs  NVARCHAR(MAX)
    )

    INSERT INTO #Messages (MessageId, MsgTargetId, TargetId, BetTransId, Content_en, Content_cs)
    SELECT t.c.value('@MessageId',   'INT')           AS MessageId,
           t.c.value('@MsgTargetId', 'INT')           AS MsgTargetId,
           t.c.value('@TargetId',    'INT')           AS TargetId,
           t.c.value('@BetTransId',  'VARCHAR(MAX)')  AS BetTransId,
           t.c.value('@Content_en',  'NVARCHAR(MAX)') AS Content_en,
           t.c.value('@Content_cs',  'NVARCHAR(MAX)') AS Content_cs
    FROM @Messages.nodes('root/r') AS t(c)
    OPTION (OPTIMIZE FOR (@Messages = NULL))


    -------------
    -- Clean data

    -- Clean 01
    -- + All MessageId in TicketVoiding_VoidingHistory be already created Feedback on AbnormalBet/AbnormalAccount auto service
    -- + And some of them have MsgContentsType=103
    -- + And we need to remove them from XML data at this step to avoid recreate Feedback for them again
    DELETE m
    FROM #Messages m
    WHERE EXISTS (SELECT TOP 1 1 FROM bodb02.dbo.TicketVoiding_VoidingHistory v WITH (NOLOCK) WHERE v.MessageId = m.MessageId)

    -- Clean 02
    -- + We just keep data with TargetId is member (roleid=1)
    -- + We need to do this to optimoize the way to get data between different data processes (to prevent duplicate data)
    DELETE m
    FROM #Messages m
    WHERE EXISTS (SELECT TOP 1 1 FROM bodb02.dbo.Customer cus WITH (NOLOCK) WHERE cus.roleid <> 1 AND cus.custid = m.TargetId)


    --------------
    -- Return data

    ;WITH
    -- + First, get raw data
    CTE_RawData AS (
        SELECT mt.MessageId,
               mt.MsgTargetId,
               bt.BetTransId,
               mt.Content_en,
               mt.Content_cs
        FROM #Messages mt WITH (NOLOCK)
             CROSS APPLY (SELECT TRIM(value) BetTransId FROM STRING_SPLIT(mt.BetTransId, ',')) bt
    ),
    -- + Second, get MAX(MsgTargetId) for each MessageId
    CTE_MsgTargetId AS (
        SELECT MessageId,
               Content_en,
               Content_cs,
               MAX(MsgTargetId) MAXMsgTargetId
        FROM CTE_RawData
        GROUP BY MessageId,
                 Content_en,
                 Content_cs
    ),
    -- + Third, get all BetTransId belong to MessageId
    CTE_BetTransId AS (
        SELECT MessageId,
               BetTransId
        FROM CTE_RawData
        GROUP BY MessageId,
                 BetTransId
    ),
    -- + Combine data
    CTE_CombineData AS (
        SELECT mt.MessageId,
               mt.MAXMsgTargetId,
               STRING_AGG(CAST(bt.BetTransId AS VARCHAR(MAX)), ',') ListBetTransId,
               mt.Content_en,
               mt.Content_cs
        FROM CTE_MsgTargetId mt
             LEFT JOIN CTE_BetTransId bt ON mt.MessageId = bt.MessageId
        GROUP BY mt.MessageId,
                 mt.MAXMsgTargetId,
                 mt.Content_en,
                 mt.Content_cs
    )
    -- + Return final data
    SELECT MessageId,
           MAXMsgTargetId,
           ListBetTransId,
           Content_en,
           Content_cs
    FROM CTE_CombineData


    -------------------
    -- Drop temp tables

    DROP TABLE #Messages

END
GO