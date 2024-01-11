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
        - 20231218@Ned.Le: CRM - Auto generate Feedback and Headline Notification were created and sent for non-today matches [HotFix : #198492]
        - 20240102@Ned.Le: CRM/Chatbot - Message Notifications for Voiding Tickets of Special Sites (ChinaView, JollySports) [RedmineId : #198905]

    Param's Explanation:
        @Messages:
            + Data
                <root>
                    <r VoidingHistoryCollectionId="1" MessageId="1" IssueTypeId="11" TrasnIdList="1,2,3,4" UsernameList="" FilterBy="1"/>
                    <r VoidingHistoryCollectionId="1" MessageId="1" IssueTypeId="11" TrasnIdList="5,6,7,8" UsernameList="" FilterBy="-1"/>
                    <r VoidingHistoryCollectionId="2" MessageId="2" IssueTypeId="15" TrasnIdList="9,10,11,12" UsernameList="" FilterBy="-1"/>
                    <r VoidingHistoryCollectionId="3" MessageId="3" IssueTypeId="13" TrasnIdList="" UsernameList="a1,a2,a3,a4" FilterBy="-1"/>
                </root>
            + Description
                * UsernameList: SMA list enter to void tickets
        @Messages_VoidByBetID:
            + Data
                <root>
                    <r VoidingHistoryCollectionId="-1" MessageId="1822833" MsgTargetId="41423853" TargetId="43454879" BetTransId="191740199233912877, 191740225003716680, 191740246478553114, 191740267953389608, 191740405392343154, 191740426867179563, 191740452636983362, 191740469816852488"/>
                    <r VoidingHistoryCollectionId="-1" MessageId="1822833" MsgTargetId="41423854" TargetId="43454880" BetTransId="191740199233912877, 191740225003716680, 191740246478553114, 191740267953389608, 191740405392343154, 191740426867179563, 191740452636983362, 191740469816852488"/>
                    <r VoidingHistoryCollectionId="-1" MessageId="1822833" MsgTargetId="41423855" TargetId="45532870" BetTransId="191740199233912877, 191740225003716680, 191740246478553114, 191740267953389608, 191740405392343154, 191740426867179563, 191740452636983362, 191740469816852488"/>
                    <r VoidingHistoryCollectionId="-1" MessageId="1822833" MsgTargetId="41423856" TargetId="103465927" BetTransId="191740405392343154, 191740426867179563, 191740452636983362, 191740469816852488"/>
                    <r VoidingHistoryCollectionId="-1" MessageId="1822833" MsgTargetId="41423857" TargetId="103757148" BetTransId="191740199233912877, 191740225003716680, 191740246478553114, 191740267953389608"/>
                </root>
*/

BEGIN

    SET NOCOUNT ON


    -------------------------------
    -- Parse XML data to temp table

    -- #Messages
    CREATE TABLE #tmpInput_Messages (VoidingHistoryCollectionId INT, MessageId INT, IssueTypeId INT, TrasnIdList VARCHAR(MAX), UsernameList NVARCHAR(MAX), FilterBy INT)

    INSERT INTO #tmpInput_Messages (VoidingHistoryCollectionId, MessageId, IssueTypeId, TrasnIdList, UsernameList, FilterBy)
    SELECT t.c.value('@VoidingHistoryCollectionId', 'INT')           AS VoidingHistoryCollectionId,
           t.c.value('@MessageId',                  'INT')           AS MessageId,
           t.c.value('@IssueTypeId',                'INT')           AS IssueTypeId,
           t.c.value('@TrasnIdList',                'VARCHAR(MAX)')  AS TrasnIdList,
           t.c.value('@UsernameList',               'NVARCHAR(MAX)') AS UsernameList,
           t.c.value('@UsernameList',               'INT')           AS FilterBy
    FROM @Messages.nodes('root/r') AS t(c)
    OPTION (OPTIMIZE FOR (@Messages = NULL))

    -- #Messages_VoidByBetID
    CREATE TABLE #tmpInput_Messages_VoidByBetID (VoidingHistoryCollectionId INT, MessageId INT, MsgTargetId INT, TargetId INT, BetTransId VARCHAR(MAX))

    INSERT INTO #tmpInput_Messages_VoidByBetID (VoidingHistoryCollectionId, MessageId, MsgTargetId, TargetId, BetTransId)
    SELECT t.c.value('@VoidingHistoryCollectionId', 'INT')          AS VoidingHistoryCollectionId,
           t.c.value('@MessageId',                  'INT')          AS MessageId,
           t.c.value('@MsgTargetId',                'INT')          AS MsgTargetId,
           t.c.value('@TargetId',                   'INT')          AS TargetId,
           t.c.value('@BetTransId',                 'VARCHAR(MAX)') AS BetTransId
    FROM @Messages_VoidByBetID.nodes('root/r') AS t(c)
    OPTION (OPTIMIZE FOR (@Messages_VoidByBetID = NULL))


    --------------------------------
    -- Get data for output parameter

    SELECT @MAXVoidingHistoryCollectionId = MAX(VoidingHistoryCollectionId) FROM #tmpInput_Messages

    SELECT @MAXMsgTargetId = MAX(MsgTargetId) FROM #tmpInput_Messages_VoidByBetID


    -------------------------------------------
    -- Clean and transform data for VoidByBetID

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
    FROM #tmpInput_Messages_VoidByBetID m
    WHERE EXISTS (SELECT TOP 1 1 FROM CTE_VoidingHistory v WHERE v.MessageId = m.MessageId)

    -- Clean 02
    -- + We just keep data with TargetId is member (roleid=1)
    -- + We need to do this to optimoize the way to get data between different data processes (to prevent duplicate data)
    DELETE m
    FROM #tmpInput_Messages_VoidByBetID m
    WHERE EXISTS (SELECT TOP 1 1 FROM bodb02.dbo.Customer cus WITH (NOLOCK) WHERE cus.roleid <> 1 AND cus.custid = m.TargetId)

    -- Transform data to get the final suitable format for further process
    -- + Create temp table
    CREATE TABLE #tmpData_VoidByBetID (
        VoidingHistoryCollectionId INT,
        MessageId INT,
        ListBetTransId VARCHAR(MAX)
    )
    ;WITH
    -- + First, parse BetTransId to row
    CTE_first AS (
        SELECT mt.VoidingHistoryCollectionId,
               mt.MessageId,
               bt.BetTransId
        FROM #tmpInput_Messages_VoidByBetID mt WITH (NOLOCK)
             CROSS APPLY (SELECT value BetTransId FROM STRING_SPLIT(mt.BetTransId, ',')) bt
    ),
    -- + Second, distinct BetTransId by MessageId
    CTE_second AS (
        SELECT VoidingHistoryCollectionId,
               MessageId,
               BetTransId
        FROM CTE_first
        GROUP BY VoidingHistoryCollectionId,
                 MessageId,
                 BetTransId
    ),
    -- + Final, concat BetTransId together
    CTE_final AS (
        SELECT VoidingHistoryCollectionId,
               MessageId,
               STRING_AGG(CAST(BetTransId AS VARCHAR(MAX)), ',') ListBetTransId
        FROM CTE_second
        GROUP BY VoidingHistoryCollectionId,
                 MessageId
    )
    -- + Return final data
    INSERT INTO #tmpData_VoidByBetID (
        VoidingHistoryCollectionId,
        MessageId,
        ListBetTransId
    )
    SELECT VoidingHistoryCollectionId,
           MessageId,
           ListBetTransId
    FROM CTE_final


    -----------------------------------------------------------------------------------------
    -- Clean and transform data for Abnormal Bet Group | Abnormal Bet   (IssueTypeId=11)
    --                                                 | AB Real Member (IssueTypeId=15)
    --                                                 | VoidByBetID    (MsgContentsType=103)

    -- Create support temp table
    CREATE TABLE #tmpData_AbnormalBet (
        VoidingHistoryCollectionId INT,
        MessageId                  INT,
        TransId                    BIGINT,
        CustId                     INT,
        Username                   NVARCHAR(100),
        Srecommend                 INT,
        Mrecommend                 INT,
        Recommend                  INT,
        IsTest                     BIT,
        [Type]                     TINYINT
    )

    -- Insert base data of Abnormal Bets (IssueTypeId=11) and AB (IssueTypeId=15) to support temp table
    INSERT INTO #tmpData_AbnormalBet (
        VoidingHistoryCollectionId,
        MessageId,
        TransId,
        [Type]
    )
    SELECT ab.VoidingHistoryCollectionId,
           ab.MessageId,
           t.TransId,
           CASE WHEN ab.IssueTypeId = 11 AND ab.FilterBy = 1 THEN 3 ELSE 1 END [Type]
    FROM #tmpInput_Messages ab
         CROSS APPLY (SELECT value TransId FROM STRING_SPLIT(ab.TrasnIdList, ',')) t
    WHERE ab.IssueTypeId IN (11, 15)

    -- Insert base data of VoidByBetID (MsgContentsType=103) to support temp table
    INSERT INTO #tmpData_AbnormalBet (
        VoidingHistoryCollectionId,
        MessageId,
        TransId,
        [Type]
    )
    SELECT vb.VoidingHistoryCollectionId,
           vb.MessageId,
           t.TransId,
           1 [Type]
    FROM #tmpData_VoidByBetID vb
         CROSS APPLY (SELECT value TransId FROM STRING_SPLIT(vb.ListBetTransId, ',')) t

    -- Update data on support temp table with information from bettrans
    UPDATE ab
    SET ab.CustId     = b.custid,
        ab.Username   = b.Username,
        ab.Srecommend = b.srecommend,
        ab.Mrecommend = b.mrecommend,
        ab.Recommend  = b.recommend,
        ab.IsTest     = b.IsTest
    FROM #tmpData_AbnormalBet ab
         CROSS APPLY (SELECT TOP 1 b.custid, b.Username, b.srecommend, b.mrecommend, b.recommend, CASE WHEN b.currency = 20 THEN 1 ELSE 0 END AS IsTest
                      FROM bodb02.dbo.bettrans b WITH (NOLOCK)
                      WHERE b.transid = ab.TransId) b

    -- Update data on support temp table with information from bettrans14
    UPDATE ab
    SET ab.CustId     = b.custid,
        ab.Username   = b.Username,
        ab.Srecommend = b.srecommend,
        ab.Mrecommend = b.mrecommend,
        ab.Recommend  = b.recommend,
        ab.IsTest     = b.IsTest
    FROM #tmpData_AbnormalBet ab
         CROSS APPLY (SELECT TOP 1 b.custid, b.Username, b.srecommend, b.mrecommend, b.recommend, CASE WHEN b.currency = 20 THEN 1 ELSE 0 END AS IsTest
                      FROM bodb02.dbo.bettrans14 b WITH (NOLOCK)
                      WHERE b.transid = ab.TransId) b


    -----------------------------------------------------------------------------------------------------------------------------
    -- Clean and transform data for Abnormal Account (IssueTypeId=13) | Only get direct account of member who have tickets voided

    -- Create support temp table
    CREATE TABLE #tmpData_AbnormalAccount (
        VoidingHistoryCollectionId INT,
        MessageId                  INT,
        CustId                     INT,
        Username                   NVARCHAR(100),
        Srecommned                 INT,
        Mrecommend                 INT,
        Recommend                  INT,
        IsTest                     BIT,
        DirectAccount              INT
    )

    -- Gen data to support temp table
    INSERT INTO #tmpData_AbnormalAccount (
        VoidingHistoryCollectionId,
        MessageId,
        CustId,
        Username,
        Srecommned,
        Mrecommend,
        Recommend,
        IsTest,
        DirectAccount
    )
    SELECT ac.VoidingHistoryCollectionId               VoidingHistoryCollectionId,
           ac.MessageId                                MessageId,
           c.custid                                    CustId,
           u.Username                                  Username,
           c.srecommend                                Srecommned,
           c.mrecommend                                Mrecommend,
           c.recommend                                 Recommend,
           CASE WHEN c.currency = 20 THEN 1 ELSE 0 END IsTest,
           cda.CustID                                  DirectAccount
    FROM #tmpInput_Messages ac
         CROSS APPLY (SELECT value Username FROM STRING_SPLIT(ac.UsernameList, ',')) u
         INNER JOIN bodb02.dbo.Customer c WITH (NOLOCK) ON c.username = u.Username
         LEFT JOIN bodb02.dbo.CustDirectAccount cda WITH (NOLOCK) ON cda.CustID IN (c.custid, c.srecommend, c.mrecommend, c.recommend)
    WHERE ac.IssueTypeId IN (13)
          AND cda.CustID IS NOT NULL


    --------------------------------------------------
    -- Centralize data from many different source data

    -- Create final temp table to centralize data
    CREATE TABLE #tmpData_Final (
        VoidingHistoryCollectionId INT,
        MessageId                  INT,
        CustId                     INT,
        UsernameList               NVARCHAR(MAX),
        Srecommend                 INT,
        Mrecommend                 INT,
        Recommend                  INT,
        IsTest                     BIT,
        [Type]                     TINYINT
    )

    -- Gen data from Abnormal Bet
    INSERT INTO #tmpData_Final (
        VoidingHistoryCollectionId,
        MessageId,
        CustId,
        UsernameList,
        Srecommend,
        Mrecommend,
        Recommend,        
        IsTest,
        [Type]
    )
    SELECT ab.VoidingHistoryCollectionId    VoidingHistoryCollectionId,
           ab.MessageId                     MessageId,
           ab.CustId                        CustId,
           ab.Username                      UsernameList,
           ab.Srecommend                    Srecommend,
           ab.Mrecommend                    Mrecommend,
           ab.Recommend                     Recommend,
           MIN(CONVERT(TINYINT, ab.IsTest)) IsTest,
           MAX(ab.[Type])                   [Type]
    FROM #tmpData_AbnormalBet ab
    GROUP BY ab.VoidingHistoryCollectionId,
             ab.MessageId,
             ab.CustId,
             ab.Username,
             ab.Srecommend,
             ab.Mrecommend,
             ab.Recommend

    -- Gen data from Abnormal Account
    ;WITH CTE AS (
        SELECT ac.VoidingHistoryCollectionId,
               ac.MessageId,
               ac.DirectAccount,
               MIN(CONVERT(TINYINT, ac.IsTest)) IsTest,
               STRING_AGG(CAST(ac.Username AS NVARCHAR(MAX)), ',') UsernameList
        FROM #tmpData_AbnormalAccount ac
        GROUP BY ac.VoidingHistoryCollectionId,
                 ac.MessageId,
                 ac.DirectAccount
    )
    INSERT INTO #tmpData_Final (
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

    -- Update data by environment
    IF (@Environment = 'UAT')
    BEGIN
        DELETE r
        FROM #tmpData_Final r
        WHERE r.IsTest = 0
    END
    IF (@Environment = 'LIVE' AND @IncludeUUSCurrency = 0)
    BEGIN
        DELETE r
        FROM #tmpData_Final r
        WHERE r.IsTest = 1
    END


    -------------------------------
    -- Return final result data set

    -- The dataset that contain data relate to Headline
    SELECT VoidingHistoryCollectionId   VoidingHistoryCollectionId,
           MessageId                    MessageId,
           ISNULL(CustId, 0)            CustId ,
           ISNULL(UsernameList, '')     UsernameList,
           ISNULL(Srecommend, 0)        Srecommend,
           ISNULL(Mrecommend, 0)        Mrecommend,
           ISNULL(Recommend, 0)         Recommend,
           ISNULL(IsTest, 1)            IsTest,
           [Type]                       [Type]
    FROM #tmpData_Final

    -- The dataset that contain data to be used to get message content
    SELECT DISTINCT
           VoidingHistoryCollectionId,
           MessageId
    FROM #tmpData_Final


    -------------------
    -- Drop temp tables

    DROP TABLE #tmpInput_Messages
    DROP TABLE #tmpInput_Messages_VoidByBetID
    DROP TABLE #tmpData_VoidByBetID
    DROP TABLE #tmpData_AbnormalBet
    DROP TABLE #tmpData_AbnormalAccount
    DROP TABLE #tmpData_Final

END
GO