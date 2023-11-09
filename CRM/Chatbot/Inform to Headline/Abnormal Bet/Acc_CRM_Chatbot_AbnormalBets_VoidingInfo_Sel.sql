/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/

USE bodb02
GO

ALTER PROCEDURE dbo.Acc_CRM_Chatbot_AbnormalBets_VoidingInfo_Sel @Messages                      XML,
                                                                 @Messages_VoidByBetID          XML,
                                                                 @Environment                   VARCHAR(50) = '',
                                                                 @IncludeUUSCurrency            BIT         = 1,
                                                                 @MAXVoidingHistoryCollectionId INT OUTPUT,
                                                                 @MAXMsgTargetId                INT OUTPUT
AS

/*
    Created: 20200811@Percy
    DB: DBACC-bodb02
    Task: CRM - ChatBot - Get Voiding Information

    Revisions:
        - 20200811@Percy: Initialize SP [RedmineID: #130544]
        - 20210415@Malcolm: Notify Tickets of AB (Real Member) [RedmineId : #153259]
        - 20210415@Malcolm: Integrate Abnormal Accounts [RedmineId : #157303]
        - 20211125@Malcolm: Notify Tickets of Abnormal Mix Parlay [RedmineId : #163833]
        - 20220115@Malcolm: Scale out for CRM [RedmineId : #181906]
        - 20230330@Ned.Le: CRM - Enhance for Displaying Relevant MessageIDs [RedmineId : #186119]
        - 20231110@Ned.Le: CRM - Auto generate Feedback and send Headline Notification for voiding Abnormal Bets by Void By BetID [RedmineId : #196660]

    Param's Explanation:
        @Messages:
            + Data
                <root>
                    <r VoidingHistoryCollectionId = "1" VoidingHistoryID = "" UsernameList=""/>
                    <r VoidingHistoryCollectionId = "2" VoidingHistoryID = "456" UsernameList="xxx,u1"/>
                    <r VoidingHistoryCollectionId = "3" VoidingHistoryID = "789" UsernameList="xxx,u1"/>
                    <r VoidingHistoryCollectionId = "4" VoidingHistoryID = "234" UsernameList="xxx,u1"/>
                </root>
            + Description
                * UsernameList: SMA list enter to void tickets
        @Messages_VoidByBetID:
            + Data
                <root>
                    <r VoidingHistoryCollectionId="-1" MessageId="1807390" MAXMsgTargetId="40858531" ListBetTransId="184182641631690829,184183199977439303"/>
                    <r VoidingHistoryCollectionId="-2" MessageId="1807391" MAXMsgTargetId="40858539" ListBetTransId="184360135450165263,184360221349511202"/>
                    <r VoidingHistoryCollectionId="-3" MessageId="1807421" MAXMsgTargetId="40863579" ListBetTransId="180155714654699700"/>
                    <r VoidingHistoryCollectionId="-4" MessageId="1807422" MAXMsgTargetId="40863583" ListBetTransId="180155714654699702"/>
                </root>
*/

BEGIN

    SET NOCOUNT ON


    -------------------------------
    -- Parse XML data to temp table

    -- #Messages
    CREATE TABLE #Messages (VoidingHistoryCollectionId INT, VoidingHistoryID INT, UsernameList NVARCHAR(MAX))

    INSERT INTO #Messages (VoidingHistoryCollectionId, VoidingHistoryID, UsernameList)
    SELECT t.c.value('@VoidingHistoryCollectionId', 'INT') AS VoidingHistoryCollectionId,
           t.c.value('@VoidingHistoryID', 'INT') AS VoidingHistoryID,
           t.c.value('@UsernameList', 'NVARCHAR(MAX)') AS UsernameList
    FROM @Messages.nodes('root/r') AS t(c)
    OPTION (OPTIMIZE FOR (@Messages = NULL))

    -- #Messages_VoidByBetID
    CREATE TABLE #Messages_VoidByBetID (VoidingHistoryCollectionId INT, MessageId INT, MAXMsgTargetId INT, ListBetTransId VARCHAR(MAX))

    INSERT INTO #Messages_VoidByBetID (VoidingHistoryCollectionId, MessageId, MAXMsgTargetId, ListBetTransId)
    SELECT t.c.value('@VoidingHistoryCollectionId', 'INT') AS VoidingHistoryCollectionId,
           t.c.value('@MessageId', 'INT') AS MessageId,
           t.c.value('@MAXMsgTargetId', 'INT') AS MAXMsgTargetId,
           t.c.value('@ListBetTransId', 'VARCHAR(MAX)') AS ListBetTransId
    FROM @Messages_VoidByBetID.nodes('root/r') AS t(c)
    OPTION (OPTIMIZE FOR (@Messages_VoidByBetID = NULL))


    --------------------------------------------------
    -- Centralize data from many different source data

    -- Create final temp table to centralize data
    CREATE TABLE #Result (
        VoidingHistoryCollectionId INT,
        MessageId                  INT,
        CustId                     INT,
        UsernameList               NVARCHAR(MAX),
        Recommend                  INT,
        Mrecommend                 INT,
        Srecommend                 INT,
        IsTest                     BIT,
        [Type]                     TINYINT
    )

    CREATE CLUSTERED INDEX CIX_VoidingHistoryCollectionId ON #Result(VoidingHistoryCollectionId)

    -- Get data for Abnormal Bets (IssueTypeId=11)
    --              AB            (IssueTypeId=15)
    --              VoidByBetID   (MsgContentsType=103)
    BEGIN
        -- Create support temp table
        CREATE TABLE #AbnormalBetsInfo (
            VoidingHistoryCollectionId INT,
            TransId                    BIGINT,
            MessageId                  INT,
            Username                   VARCHAR(30),
            CustId                     INT,
            Recommend                  INT,
            Mrecommend                 INT,
            Srecommend                 INT,
            IsTest                     BIT,
            [Type]                     TINYINT
        )

        -- Insert base data of Abnormal Bets (IssueTypeId=11) and AB (IssueTypeId=15) to support temp table
        INSERT INTO #AbnormalBetsInfo (
            VoidingHistoryCollectionId,
            TransId,
            MessageId,
            [Type]
        )
        SELECT vc.VoidingHistoryCollectionId,
               t.TransId,
               vh.MessageId,
               CASE WHEN rq.IssueTypeId = 11 AND ISNULL(f.FilterBy, 0) = 1 THEN 3 ELSE 1 END AS [Type]
        FROM bodb02.dbo.VoidingHistoryCollection vc WITH (NOLOCK)
             INNER JOIN bodb02.dbo.VoidingHistoryCollectionDetail vcd WITH (NOLOCK) ON vcd.VoidingHistoryCollectionId = vc.VoidingHistoryCollectionId
             INNER JOIN bodb02.dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK) ON vh.VoidingHistoryId = vcd.VoidingHistoryId
             INNER JOIN bodb02.dbo.TicketVoiding_Request rq WITH (NOLOCK) ON rq.RequestId = vh.RequestId AND rq.IssueTypeId IN (11, 15)
             OUTER APPLY (SELECT TOP(1) rd.FilterBy 
                          FROM bodb02.dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) 
                          WHERE rd.RequestId = vh.RequestId) f(FilterBy)
             CROSS APPLY (SELECT value AS TransId 
                          FROM STRING_SPLIT(vh.TransIds, ',')) t
        WHERE EXISTS (SELECT 1 FROM #Messages m WHERE m.VoidingHistoryCollectionId = vc.VoidingHistoryCollectionId)

        -- Insert base data of VoidByBetID (MsgContentsType=103) to support temp table
        INSERT INTO #AbnormalBetsInfo (
            VoidingHistoryCollectionId,
            TransId,
            MessageId,
            [Type]
        )
        SELECT vb.VoidingHistoryCollectionId,
               bt.TransId,
               vb.MessageId,
               1 [Type]
        FROM #Messages_VoidByBetID vb
             CROSS APPLY (SELECT value TransId
                          FROM STRING_SPLIT(vb.ListBetTransId, ',')) bt
        WHERE vb.MessageId NOT IN (SELECT MessageId FROM bodb02.dbo.TicketVoiding_VoidingHistory WITH (NOLOCK))

        -- Update data on support temp table with information from bettrans
        UPDATE a
        SET a.CustId     = b.CustId,
            a.Username   = b.Username,
            a.Srecommend = b.Srecommend,
            a.Mrecommend = b.Mrecommend,
            a.Recommend  = b.Recommend,
            a.IsTest     = b.IsTest
        FROM #AbnormalBetsInfo a
             CROSS APPLY (SELECT TOP 1 b.CustId, b.Username, b.Srecommend, b.Mrecommend, b.Recommend, CASE WHEN b.Currency = 20 THEN 1 ELSE 0 END AS IsTest
                          FROM bodb02.dbo.bettrans b WITH (NOLOCK)
                          WHERE b.transid = a.TransId) b

        -- Update data on support temp table with information from bettrans14
        UPDATE a
        SET a.CustId     = b.CustId,
            a.Username   = b.Username,
            a.Srecommend = b.Srecommend,
            a.Mrecommend = b.Mrecommend,
            a.Recommend  = b.Recommend,
            a.IsTest     = b.IsTest
        FROM #AbnormalBetsInfo a
             CROSS APPLY (SELECT TOP 1 b.CustId, b.Username, b.Srecommend, b.Mrecommend, b.Recommend, CASE WHEN b.Currency = 20 THEN 1 ELSE 0 END AS IsTest
                          FROM bodb02.dbo.bettrans14 b WITH (NOLOCK)
                          WHERE b.transid = a.TransId) b

        -- Gen data to final temp table
        INSERT INTO #Result (
            VoidingHistoryCollectionId,
            MessageId,
            CustId,
            UsernameList,
            Recommend,
            Mrecommend,
            Srecommend,
            IsTest,
            [Type]
        )
        SELECT a.VoidingHistoryCollectionId,
               a.MessageId,
               a.CustId,
               a.Username,
               a.Recommend,
               a.Mrecommend,
               a.Srecommend,
               MIN(CONVERT(TINYINT, a.IsTest)) AS IsTest,
               MAX(a.[Type]) AS [Type]
        FROM #AbnormalBetsInfo a
        GROUP BY a.VoidingHistoryCollectionId,
                 a.MessageId,
                 a.CustId,
                 a.Username,
                 a.Srecommend,
                 a.Mrecommend,
                 a.Recommend
    END

    -- Get data for Abnormal Accounts (IssueTypeId=13)
    --                                (only get direct account of member who have tickets voided)
    BEGIN
        -- Create support temp table
        CREATE TABLE #AbnormalAccountsInfo (
            VoidingHistoryCollectionId INT,
            MessageId                  INT,
            Username                   VARCHAR(30),
            CustId                     INT,
            Recommend                  INT,
            Mrecommend                 INT,
            Srecommned                 INT,
            IsTest                     BIT,
            DirectAccount              INT
        )

        -- Gen data to support temp table
        INSERT INTO #AbnormalAccountsInfo (
            VoidingHistoryCollectionId,
            MessageId,
            Username,
            CustId,
            Recommend,
            Mrecommend,
            Srecommned,
            DirectAccount,
            IsTest
        )
        SELECT m.VoidingHistoryCollectionId,
               vh.MessageId,
               f.Username,
               c.custid,
               c.recommend,
               c.mrecommend,
               c.srecommend,
               cda.CustID DirectAccount,
               CASE WHEN c.Currency = 20 THEN 1 ELSE 0 END AS IsTest
        FROM #Messages m
             INNER JOIN bodb02.dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK) ON m.VoidingHistoryID = vh.VoidingHistoryId
             CROSS APPLY (SELECT CONVERT(VARCHAR(30), f.value) AS Username
                          FROM STRING_SPLIT(m.UsernameList, ',') f
                          WHERE f.value <> '') AS f(Username)
             INNER JOIN bodb02.dbo.Customer c WITH (NOLOCK) ON c.username = f.Username
             LEFT JOIN bodb02.dbo.CustDirectAccount cda WITH (NOLOCK) ON cda.CustID IN (c.custid, c.recommend, c.mrecommend, c.srecommend)
        WHERE m.UsernameList <> ''
              AND cda.CustID IS NOT NULL

        CREATE INDEX ix_MessageId ON #AbnormalAccountsInfo (VoidingHistoryCollectionId, MessageId, DirectAccount)

        -- Gen data to final temp table
        ;WITH CTE AS (
            SELECT ai.VoidingHistoryCollectionId,
                   ai.MessageId,
                   ai.DirectAccount,
                   MIN(CONVERT(TINYINT, ai.IsTest)) AS IsTest,
                   STRING_AGG(CAST(ai.Username AS VARCHAR(MAX)), ',') AS UsernameList
            FROM #AbnormalAccountsInfo ai
            GROUP BY ai.VoidingHistoryCollectionId,
                     ai.MessageId,
                     ai.DirectAccount
        )
        INSERT INTO #Result (
            VoidingHistoryCollectionId,
            MessageId,
            CustId,
            UsernameList,
            Recommend,
            Mrecommend,
            Srecommend,
            IsTest,
            [Type]
        )
        SELECT e.VoidingHistoryCollectionId,
               e.MessageId,
               e.DirectAccount,
               e.UsernameList,
               c.Recommend,
               c.Mrecommend,
               c.Srecommend,
               e.IsTest,
               2 AS [Type]
        FROM CTE e
             INNER JOIN bodb02.dbo.Customer c WITH (NOLOCK) ON c.custid = e.DirectAccount
    END


    ---------------------------
    -- Keep data by environment

    IF (@Environment = 'UAT')
    BEGIN
        DELETE r
        FROM #Result r
        WHERE r.IsTest = 0
    END

    IF (@Environment = 'LIVE' AND @IncludeUUSCurrency = 0)
    BEGIN
        DELETE r
        FROM #Result r
        WHERE r.IsTest = 1
    END


    -----------------------------------
    -- Return data for output parameter

    SELECT @MAXVoidingHistoryCollectionId = MAX(VoidingHistoryCollectionId) FROM #Messages

    SELECT @MAXMsgTargetId = MAX(MAXMsgTargetId) FROM #Messages_VoidByBetID


    -------------------------
    -- Return result data set

    -- The dataset that contain data relate to Headline
    SELECT VoidingHistoryCollectionId,
           MessageId,
           ISNULL(CustId, 0) AS CustId ,
           ISNULL(UsernameList, '') AS UsernameList,
           ISNULL(Recommend, 0) AS Recommend,
           ISNULL(Mrecommend, 0) AS Mrecommend,
           ISNULL(Srecommend, 0) AS Srecommend,
           ISNULL(IsTest, 1) AS IsTest,
           [Type]
    FROM #Result

    -- The dataset that contain data to be used to get message content
    SELECT DISTINCT
           VoidingHistoryCollectionId,
           MessageId,
           -1 RequestId
    FROM #Result


    -------------------
    -- Drop temp tables

    DROP TABLE #Messages
    DROP TABLE #Messages_VoidByBetID
    DROP TABLE #Result
    DROP TABLE #AbnormalBetsInfo
    DROP TABLE #AbnormalAccountsInfo

END
GO