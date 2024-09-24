/*<info serverAlias="DBMSG-bodb_Message" executers="wsv_nap" isFunction="0" isNested="0"></info>*/

USE bodb_Message
GO

ALTER PROCEDURE dbo.Acc_CRM_AutoFB_VoidByBetID_GetMessage @LastMsgTargetId INT,
                                                          @BatchSize       INT = 10
AS

/*
    Created: 20231115@Ned.Le
    Task:    Get information for Void By BetID
    DB:      DBMSG/bodb_Message

    Revisions:
        - 20231115@Ned.Le: CRM - Auto generate Feedback and send Headline Notification for voiding Abnormal Bets by Void By BetID (#196660)
        - 20240823@Ned.Le: CRM - Void by BetID - Support Auto FB and notificaitons for voiding Parlay Ticket of Sportsbook [RedmineId : #209707]

    Param's Explanation:
        - @LastMsgTargetId: the last MsgTargetId
        - @BatchSize:       total record to return
*/

BEGIN

    SET NOCOUNT ON


    -----------
    -- Get data

    -- Get MAX(MsgTargetId) that be used to limit data
    DECLARE @MaxMsgTargetId INT
    SELECT  @MaxMsgTargetId = MAX(MsgTargetId) FROM bodb_Message.dbo.MsgTarget WITH (NOLOCK)

    -- We need to wait for 4s to sure that data be already stable
    WAITFOR DELAY '00:00:04'

    -- Get all suitable message data
    -- + We just get all data first
    -- + And we also need build a mechanism that help to limit data later
    CREATE TABLE #tmpMessageData (
        MessageId      INT,
        MINMsgTargetId INT,
        RowRank        INT)

    ;WITH
    CTE_Data AS (
        SELECT m.MessageId,
               MIN(mt.MsgTargetId) MINMsgTargetId
        FROM bodb_Message.dbo.MsgTarget mt WITH (NOLOCK)
             INNER JOIN bodb_Message.dbo.Msg m WITH(NOLOCK) ON m.MsgContentsType = 103
                                                               AND m.MsgType = 1
                                                               AND mt.MessageId = m.MessageId
        WHERE mt.MsgTargetId > @LastMsgTargetId
              AND mt.MsgTargetId <= @MaxMsgTargetId
        GROUP BY m.MessageId
    ),
    CTE_Rank AS (
        SELECT MessageId,
               MINMsgTargetId,
               ROW_NUMBER() OVER (ORDER BY MINMsgTargetId) RowRank
        FROM CTE_Data
    )
    INSERT INTO #tmpMessageData (MessageId, MINMsgTargetId, RowRank)
    SELECT MessageId, MINMsgTargetId, RowRank
    FROM CTE_Rank
    OPTION (RECOMPILE)

    CREATE CLUSTERED INDEX CIX_MessageId ON #tmpMessageData(MessageId)

    -- Update value MAX(MsgTargetId) in the way to be suitable with @BatchSize
    -- + If total MessageId over the @BatchSize, get the MAX(MsgTargetId) of the 10th MessageId
    -- + If total MessageId under the @BatchSize, the MAX(MsgTargetId) will remain the same as before
    SELECT @MaxMsgTargetId = (MINMsgTargetId - 1) FROM #tmpMessageData WHERE RowRank = (@BatchSize + 1)


    --------------
    -- Return data

    SELECT mt.MessageId,
           mt.MsgTargetId,
           mt.TargetId,
           mt.BetTransId,
           m.CreatorName,
           m.Content_en,
           m.Content_cs
    FROM bodb_Message.dbo.MsgTarget mt WITH (NOLOCK)
         LEFT JOIN bodb_Message.dbo.Msg m ON mt.MessageId = m.MessageId
    WHERE mt.MessageId IN (SELECT MessageId FROM #tmpMessageData)
          AND mt.MsgTargetId > @LastMsgTargetId
          AND mt.MsgTargetId <= @MaxMsgTargetId


    ------------------
    -- Drop temp table

    DROP TABLE #tmpMessageData

END
GO