/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" isFunction="0" isNested="0"></info>*/

USE bodb02
GO

ALTER PROCEDURE dbo.Task_CRM_VoidingHistoryCollection_Ins
AS

/*
    Created: 20230104@Malcolm
    Task   : Synthesize, classify and group messages
    DB     : DBACC/bodb02

    Revisions:
        20230104@Malcolm: Initialize SPs [Redmine: #181906]
        20230802@Malcolm: Incorporate voiding duplicated bet tickets with TVS [Redmine: #191355]
        20240102@Ned.Le: CRM/Chatbot - Message Notifications for Voiding Tickets of Special Sites (ChinaView, JollySports) [Redmine: #198905]
        20240515@Ned.Le: CRM/Chatboot - Support Auto Feedback/ Headline Noti and Chatbot for Licensee for TVS - Void abnormal bet (issuetypeid = 11) for many matches (#204823)

    Example:
        EXEC bodb02.dbo.Task_CRM_VoidingHistoryCollection_Ins
*/

BEGIN

    SET NOCOUNT ON


    -----------------------------------------------------------------------------------------------
    -- CODE LAYOUT                                                                               --
    -----------------------------------------------------------------------------------------------
    --                                                                                           --
    -- [01] Declare variables                                                                    --
    --      + Declare all necessary variables that be used later in code                         --
    --                                                                                           --
    -- [02] Check to aware that there is any VoidingHistoryCollectionId be in processing         --
    --      + Just be a defense mechanism to ensure the data processing always operate correctly --
    --                                                                                           --
    -- [03] Prepare data from table TicketVoiding_VoidingHistory                                 --
    --      + Need to parse to row for two column MessageId and MessageIdSpecial                 --
    --                                                                                           --
    -- [04] Process to collect data of Abnormal Account (IssueTypeId=13)                         --
    --                                                                                           --
    -- [05] Process to collect data of Duplicate Ticket (IssueTypeId=20)                         --
    --                                                                                           --
    -- [06] Process to collect data of Abnormal Bet (IssueTypeId=11,15)                          --
    --                                                                                           --
    -- [07] Centralize data and clean data and insert data to main table                         --
    --      + Centralize data: input all data to one temp table                                  --
    --      + Clean data: remove all data that not satify the requirement                        --
    --      + Insert data to main table: finalize to insert satified data to main table          --
    --                                                                                           --
    -- [08] Clean old data and keep data for 2 month                                             --
    --      + Just keep data on main table for 2 month                                           --
    --                                                                                           --
    -- [09] Drop temp tables                                                                     --
    --                                                                                           --
    -----------------------------------------------------------------------------------------------


    --------------------
    -- Declare variables

    DECLARE @CurrentDate                DATETIME = GETDATE()
    DECLARE @TimePoint                  DATETIME
    DECLARE @ErrMsg                     NVARCHAR(MAX)
    DECLARE @Id                         INT
    DECLARE @VoidingHistoryCollectionId INT


    -------------------------------------------------------------------------------
    -- Check to aware that there is any VoidingHistoryCollectionId be in processing
    -- + If the duration (compare to current) is more than 5mi
    --   --> update the process done and raise error
    -- + In real case, this situation still not happen

    IF EXISTS (SELECT 1 FROM bodb02.dbo.VoidingHistoryCollection WITH (NOLOCK) WHERE IsProcessing = 1)
    BEGIN
        SELECT @TimePoint = MIN(CreatedDate)
        FROM bodb02.dbo.VoidingHistoryCollection WITH (NOLOCK)
        WHERE IsProcessing = 1

        IF DATEDIFF(MINUTE, @TimePoint, @CurrentDate) >= 5
        BEGIN
            UPDATE bodb02.dbo.VoidingHistoryCollection WITH (ROWLOCK, UPDLOCK)
            SET IsProcessing = 0
            WHERE IsProcessing = 1

            SELECT @ErrMsg = 'SQL Server Job System: ''bodb02: Collect Ticketvoiding_VoidingHistory for CRM-ChatBot'' failed on ' + @@SERVERNAME
            RAISERROR(@ErrMsg, 16, 1)
        END

        RETURN
    END


    -------------------------------------------------------
    -- Prepare data from table TicketVoiding_VoidingHistory

    -- Create temp table
    CREATE TABLE #tmpTicketVoiding_VoidingHistory (
        BroadcastSessionId VARCHAR(100),
        RequestId          INT,
        VoidingHistoryId   INT,
        MessageId          INT,
        MessageIdGroup     INT,
        SiteDBGroupID      SMALLINT,
        StatusId           TINYINT,
        VoIdBy             NVARCHAR(200),
        ModifiedDate       DATETIME
    )

    -- Process to get data to temp table
    ;WITH
    -- + Get initial data | Get data from yesterday
    --                    | Get data that not exists on table VoidingHistoryCollectionDetail
    --                    | Pay more attention to the condition #3
    --                    | --> We need this condition to deal with case VoidingHistoryId be voided and after that be recovered
    --                    | --> VoidingHistoryId be voided successfully must exist in both table TicketVoiding_VoidingHistory and TicketVoiding_VoidedTransaction and have StatusId=2
    --                    | --> We need to take all StatusId to handle the problem of collecting data within 1 minute in the next code section
    CTE_initial AS (
        SELECT vh.BroadcastSessionId,
               vh.RequestId,
               vh.VoidingHistoryId,
               ISNULL(vh.MessageId, 0) MessageId,
               ISNULL(vh.MessageIdSpecial, 0) MessageIdSpecial,
               vh.SiteDBGroupID,
               vh.StatusId,
               cvb.username VoIdBy,
               vh.ModifiedDate,
               vh.CreatedDate
        FROM bodb02.dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK)
             LEFT JOIN bodb02.dbo.Customer cvb WITH (NOLOCK) ON vh.UserId = cvb.custid
        WHERE vh.CreatedDate >= DATEADD(DAY, -1, @CurrentDate)
              AND NOT EXISTS (SELECT TOP 1 1 FROM bodb02.dbo.VoidingHistoryCollectionDetail d WITH (NOLOCK) WHERE d.VoidingHistoryId = vh.VoidingHistoryId)
              AND (
                   (StatusId = 2 AND EXISTS (SELECT TOP 1 1 FROM bodb02.dbo.TicketVoiding_VoidedTransaction vt WITH (NOLOCK) WHERE vt.VoidingHistoryId = vh.VoidingHistoryId))
                   OR
                   (StatusId <> 2)
                  )
    ),
    -- + Just get data of normal message
    CTE_normal AS (
        SELECT BroadcastSessionId,
               RequestId,
               VoidingHistoryId,
               MessageId,
               1 MessageIdGroup,
               SiteDBGroupID,
               StatusId,
               VoIdBy,
               ModifiedDate,
               CreatedDate
        FROM CTE_initial
    ),
    -- + Just get data of special message
    CTE_special AS (
        SELECT BroadcastSessionId,
               RequestId,
               VoidingHistoryId,
               MessageIdSpecial MessageId,
               2 MessageIdGroup,
               SiteDBGroupID,
               StatusId,
               VoIdBy,
               ModifiedDate,
               CreatedDate
        FROM CTE_initial
    ),
    -- + Union data of normal message and special message
    CTE_union AS (
        SELECT BroadcastSessionId,
               RequestId,
               VoidingHistoryId,
               MessageId,
               MessageIdGroup,
               SiteDBGroupID,
               StatusId,
               VoIdBy,
               ModifiedDate,
               CreatedDate
        FROM CTE_normal
        UNION ALL
        SELECT BroadcastSessionId,
               RequestId,
               VoidingHistoryId,
               MessageId,
               MessageIdGroup,
               SiteDBGroupID,
               StatusId,
               VoIdBy,
               ModifiedDate,
               CreatedDate
        FROM CTE_special
    ),
    -- + Clean data | Get BroadcastSessionId be created on around 5 seconds from the current time
    --              | Later they will be removed to sure that not get sessions that have not yet been voided
    CTE_clean AS (
        SELECT BroadcastSessionId BroadcastSessionId,
               MIN(CreatedDate)   CreatedDate
        FROM CTE_union
        GROUP BY BroadcastSessionId
        HAVING MIN(CreatedDate) > DATEADD(SECOND, -5, @CurrentDate)
    )
    -- + Finalize to insert data to temp table
    INSERT INTO #tmpTicketVoiding_VoidingHistory (
        BroadcastSessionId,
        RequestId,
        VoidingHistoryId,
        MessageId,
        MessageIdGroup,
        SiteDBGroupID,
        StatusId,
        VoIdBy,
        ModifiedDate
    )
    SELECT BroadcastSessionId,
           RequestId,
           VoidingHistoryId,
           MessageId,
           MessageIdGroup,
           SiteDBGroupID,
           StatusId,
           VoIdBy,
           ModifiedDate
    FROM CTE_union
    WHERE BroadcastSessionId NOT IN (SELECT BroadcastSessionId FROM CTE_clean)


    ---------------------------------------------------------------
    -- Process to collect data of Abnormal Account (IssueTypeId=13)

    -- Create temp table
    CREATE TABLE #tmpAbnormalAccount (
        Support_BroadcastSessionId VARCHAR(100),
        Support_MatchId            INT,
        Support_MessageIdGroup     INT,
        Support_StatusId           TINYINT,
        Support_ModifiedDate       DATETIME,
        Support_IsCollect          BIT DEFAULT(1),
        Using_VoidingHistoryId     INT,
        Using_RequestId            INT,
        Using_MessageId            INT,
        Using_SiteDBGroupID        SMALLINT,
        Using_IssueTypeId          TINYINT,
        Using_RequestBy            NVARCHAR(200),
        Using_DecidedBy            NVARCHAR(200),
        Using_VoIdBy               NVARCHAR(200),
        Using_UsernameList         NVARCHAR(MAX),
        Using_MinWinlostdate       DATETIME,
        Using_MaxWinlostdate       DATETIME
    )

    -- Gen data to temp table
    ;WITH
    -- + Data on table TicketVoiding_RequestDetail maybe exist on multiple rows and we need to care about the duplicate data
    CTE_RequestDetail AS (
        SELECT rd.RequestId, rd.Usernames
        FROM bodb02.dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
        GROUP BY rd.RequestId, rd.Usernames
    )
    INSERT INTO #tmpAbnormalAccount (
        Support_BroadcastSessionId,
        Support_MatchId,
        Support_MessageIdGroup,
        Support_StatusId,
        Support_ModifiedDate,
        Using_VoidingHistoryId,
        Using_RequestId,
        Using_MessageId,
        Using_SiteDBGroupID,
        Using_IssueTypeId,
        Using_RequestBy,
        Using_DecidedBy,
        Using_VoIdBy,
        Using_UsernameList
    )
    SELECT vh.BroadcastSessionId Support_BroadcastSessionId,
           0                     Support_MatchId,
           vh.MessageIdGroup     Support_MessageIdGroup,
           vh.StatusId           Support_StatusId,
           vh.ModifiedDate       Support_ModifiedDate,
           vh.VoidingHistoryId   Using_VoidingHistoryId,
           rq.RequestId          Using_RequestId,
           vh.MessageId          Using_MessageId,
           vh.SiteDBGroupID      Using_SiteDBGroupID,
           rq.IssueTypeId        Using_IssueTypeId,
           crb.username          Using_RequestBy,
           rq.DecidedBy          Using_DecidedBy,
           vh.VoIdBy             Using_VoIdBy,
           rd.Usernames          Using_UsernameList
    FROM bodb02.dbo.TicketVoiding_Request rq WITH (NOLOCK)
         INNER JOIN #tmpTicketVoiding_VoidingHistory vh ON rq.RequestId = vh.RequestId
         LEFT JOIN bodb02.dbo.Customer crb WITH (NOLOCK) ON rq.UserId = crb.custid
         LEFT JOIN CTE_RequestDetail rd ON rq.RequestId = rd.RequestId
    WHERE rq.IssueTypeId IN (13)

    -- Transform temp table (check UsernameList to just keep Username that have void ticket)
    ;WITH
    CTE_sourcedata AS (
        SELECT b.Using_RequestId        RequestId,
               b.Using_VoidingHistoryId VoidingHistoryId,
               b.Using_MessageId        MessageId,
               u.Username               Username,
               c.custid                 CustId
        FROM #tmpAbnormalAccount b
             CROSS APPLY (SELECT value Username FROM STRING_SPLIT(b.Using_UsernameList, ',')) u
             LEFT JOIN bodb02.dbo.Customer c WITH (NOLOCK) ON u.Username = c.username
    ),
    CTE_checkdata AS (
        SELECT vt.VoidingHistoryId,
               vt.MessageId,
               vt.winlostdate,
               c.custid,
               c.recommend,
               c.mrecommend,
               c.srecommend
        FROM bodb02.dbo.TicketVoiding_VoidedTransaction vt WITH (NOLOCK)
             LEFT JOIN bodb02.dbo.Customer c WITH (NOLOCK) ON vt.CustID = c.custid
        WHERE EXISTS (SELECT TOP 1 1
                      FROM CTE_sourcedata s
                      WHERE s.VoidingHistoryId = vt.VoidingHistoryId AND s.MessageId = vt.MessageId)
    ),
    CTE_mapingdata AS (
        SELECT cte_s.RequestId,
               cte_s.VoidingHistoryId,
               cte_s.MessageId,
               cte_s.Username,
               cte_c.winlostdate
        FROM CTE_sourcedata cte_s
             INNER JOIN CTE_checkdata cte_c ON cte_s.VoidingHistoryId = cte_c.VoidingHistoryId
                                               AND cte_s.MessageId = cte_c.MessageId
                                               AND cte_s.CustId IN (cte_c.custid, cte_c.recommend, cte_c.mrecommend, cte_c.srecommend)
    ),
    CTE_usernamedata AS (
        SELECT RequestId,
               VoidingHistoryId,
               MessageId,
               STRING_AGG(CAST(Username AS NVARCHAR(MAX)), ',') UsernameList
        FROM (SELECT DISTINCT RequestId, VoidingHistoryId, MessageId, Username FROM CTE_mapingdata) cte
        GROUP BY RequestId,
                 VoidingHistoryId,
                 MessageId
    ),
    CTE_winlostdatedata AS (
        SELECT RequestId,
               VoidingHistoryId,
               MessageId,
               MIN(winlostdate) MinWinlostdate,
               MAX(winlostdate) MaxWinlostdate
        FROM CTE_mapingdata
        GROUP BY RequestId,
                 VoidingHistoryId,
                 MessageId
    ),
    CTE_finaldata AS (
        SELECT u.RequestId,
               u.VoidingHistoryId,
               u.MessageId,
               u.UsernameList,
               w.MinWinlostdate,
               w.MaxWinlostdate
        FROM CTE_usernamedata u
             LEFT JOIN CTE_winlostdatedata w ON u.RequestId = w.RequestId
                                                AND u.VoidingHistoryId = w.VoidingHistoryId
                                                AND u.MessageId = w.MessageId
    )
    UPDATE tmp
    SET tmp.Using_UsernameList = cte.UsernameList,
        tmp.Using_MinWinlostdate = cte.MinWinlostdate,
        tmp.Using_MaxWinlostdate = cte.MaxWinlostdate
    FROM #tmpAbnormalAccount tmp
         INNER JOIN CTE_finaldata cte ON tmp.Using_RequestId = cte.RequestId
                                         AND tmp.Using_VoidingHistoryId = cte.VoidingHistoryId
                                         AND tmp.Using_MessageId = cte.MessageId


    ---------------------------------------------------------------
    -- Process to collect data of Duplicate Ticket (IssueTypeId=20)

    -- Create temp table
    CREATE TABLE #tmpDuplicateTicket (
        Support_BroadcastSessionId VARCHAR(100),
        Support_MatchId            INT,
        Support_MessageIdGroup     INT,
        Support_StatusId           TINYINT,
        Support_ModifiedDate       DATETIME,
        Support_IsCollect          BIT DEFAULT(1),
        Using_VoidingHistoryId     INT,
        Using_RequestId            INT,
        Using_MessageId            INT,
        Using_SiteDBGroupID        SMALLINT,
        Using_IssueTypeId          TINYINT,
        Using_RequestBy            NVARCHAR(200),
        Using_DecidedBy            NVARCHAR(200),
        Using_VoIdBy               NVARCHAR(200),
        Using_MatchId              INT,
        Using_OriginalTransId      VARCHAR(MAX),
        Using_FilterBy             TINYINT
    )

    -- Gen data to temp table
    ;WITH
    -- + Just get necessary data and convert column TransIds to XML datatype
    CTE_RawData_RequestDetail_01 AS (
        SELECT rd.RequestId,
               rd.FilterBy,
               CAST(rd.TransIds AS XML) TransIds
        FROM bodb02.dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
        WHERE TransIds IS NOT NULL
              AND EXISTS (SELECT TOP 1 1
                          FROM bodb02.dbo.TicketVoiding_Request rq WITH (NOLOCK)
                          WHERE rq.IssueTypeId = 20
                                AND rq.RequestId = rd.RequestId)
        GROUP BY rd.RequestId, rd.FilterBy, rd.TransIds
    ),
    -- + Parse XML data to column
    CTE_RawData_RequestDetail_02 AS (
        SELECT RequestId                                    RequestId,
               FilterBy                                     FilterBy,
               t.c.value('@OrgTransIds',    'VARCHAR(MAX)') OrgTransIds,
               t.c.value('@VoidedTransIds', 'VARCHAR(MAX)') VoidedTransIds
        FROM CTE_RawData_RequestDetail_01
             CROSS APPLY TransIds.nodes('root/r') AS t(c)
    ),
    -- + Split data to column to use in mapping later
    CTE_RawData_RequestDetail AS (
        SELECT r.RequestId,
               r.FilterBy,
               r.OrgTransIds,
               v.VoidedTransIds
        FROM CTE_RawData_RequestDetail_02 r
             CROSS APPLY (SELECT CAST(value AS BIGINT) VoidedTransIds
                          FROM STRING_SPLIT(r.VoidedTransIds, ',')) v
    ),
    -- + Get data from TicketVoiding_VoidedTransaction
    CTE_RawData_VoidTransaction AS (
        SELECT vt.VoidingHistoryId,
               vt.MessageId,
               vt.MatchId,
               vt.TransId
        FROM bodb02.dbo.TicketVoiding_VoidedTransaction vt WITH (NOLOCK)
        GROUP BY vt.VoidingHistoryId, vt.MessageId, vt.MatchId, vt.TransId
    ),
    -- + Mapping and union data
    CTE_UnionData AS (
        SELECT rd.RequestId,
               rd.FilterBy,
               vt.VoidingHistoryId,
               vt.MessageId,
               vt.MatchId,
               rd.OrgTransIds,
               STRING_AGG(CAST(rd.VoidedTransIds AS VARCHAR(MAX)), ',') VoidedTransIds
        FROM CTE_RawData_RequestDetail rd
             LEFT JOIN CTE_RawData_VoidTransaction vt ON rd.VoidedTransIds = vt.TransId
        GROUP BY rd.RequestId, rd.FilterBy, vt.VoidingHistoryId, vt.MessageId, vt.MatchId, rd.OrgTransIds
    ),
    -- + Finalize to convert data to the expected format
    CTE_FinalData AS (
        SELECT n.RequestId,
               n.FilterBy,
               n.VoidingHistoryId,
               n.MessageId,
               n.MatchId,
               z.TransIds
        FROM (SELECT DISTINCT RequestId, FilterBy, VoidingHistoryId, MessageId, MatchId
              FROM CTE_UnionData) As n
             CROSS APPLY
             (SELECT U.OrgTransIds AS '@OrgTransIds', U.VoidedTransIds AS '@VoidedTransIds'
              FROM CTE_UnionData u
              WHERE u.RequestId = n.RequestId AND u.VoidingHistoryId = n.VoidingHistoryId AND u.MessageId = n.MessageId
              FOR XML PATH ('r'), ROOT ('root')) AS z(TransIds)
    )
    -- + Insert data to temp table
    INSERT INTO #tmpDuplicateTicket (
        Support_BroadcastSessionId,
        Support_MatchId,
        Support_MessageIdGroup,
        Support_StatusId,
        Support_ModifiedDate,
        Using_VoidingHistoryId,
        Using_RequestId,
        Using_MessageId,
        Using_SiteDBGroupID,
        Using_IssueTypeId,
        Using_RequestBy,
        Using_DecidedBy,
        Using_VoIdBy,
        Using_MatchId,
        Using_OriginalTransId,
        Using_FilterBy
    )
    SELECT vh.BroadcastSessionId Support_BroadcastSessionId,
           0                     Support_MatchId,
           vh.MessageIdGroup     Support_MessageIdGroup,
           vh.StatusId           Support_StatusId,
           vh.ModifiedDate       Support_ModifiedDate,
           vh.VoidingHistoryId   Using_VoidingHistoryId,
           rq.RequestId          Using_RequestId,
           vh.MessageId          Using_MessageId,
           vh.SiteDBGroupID      Using_SiteDBGroupID,
           rq.IssueTypeId        Using_IssueTypeId,
           crb.username          Using_RequestBy,
           rq.DecidedBy          Using_DecidedBy,
           vh.VoIdBy             Using_VoIdBy,
           fd.MatchId            Using_MatchId,
           fd.TransIds           Using_OriginalTransId,
           fd.FilterBy           Using_FilterBy
    FROM bodb02.dbo.TicketVoiding_Request rq WITH (NOLOCK)
         INNER JOIN #tmpTicketVoiding_VoidingHistory vh ON rq.RequestId = vh.RequestId
         LEFT JOIN bodb02.dbo.Customer crb WITH (NOLOCK) ON rq.UserId = crb.custid
         LEFT JOIN CTE_FinalData fd ON rq.RequestId = fd.RequestId AND vh.VoidingHistoryId = fd.VoidingHistoryId AND vh.MessageId = fd.MessageId
    WHERE rq.IssueTypeId IN (20)


    --------------------------------------------------------------
    -- Process to collect data of Abnormal Bet (IssueTypeId=11,15)

    -- Create temp table
    CREATE TABLE #tmpAbnormalBet (
        Support_BroadcastSessionId VARCHAR(100),
        Support_MatchId            INT,
        Support_MessageIdGroup     INT,
        Support_StatusId           TINYINT,
        Support_ModifiedDate       DATETIME,
        Support_IsCollect          BIT DEFAULT(1),
        Using_VoidingHistoryId     INT,
        Using_RequestId            INT,
        Using_MessageId            INT,
        Using_SiteDBGroupID        SMALLINT,
        Using_IssueTypeId          TINYINT,
        Using_RequestBy            NVARCHAR(200),
        Using_DecidedBy            NVARCHAR(200),
        Using_VoIdBy               NVARCHAR(200),
        Using_MatchId              INT,
        Using_TransIdList          VARCHAR(MAX),
        Using_ReasonList           NVARCHAR(MAX),
        Using_FilterBy             TINYINT
    )

    -- Gen data to temp table
    ;WITH
    CTE_RequestDetail AS (
        SELECT rd.RequestId, rd.MatchId, rd.FilterBy, STRING_AGG(CAST(si.SubIssueTypeName AS NVARCHAR(MAX)), ',') ReasonList
        FROM bodb02.dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
             LEFT JOIN bodb02.dbo.TicketVoiding_SubIssueType si WITH (NOLOCK) ON rd.SubIssueTypeId = si.SubIssueTypeId
        GROUP BY rd.RequestId, rd.MatchId, rd.FilterBy
    ),
    CTE_VoidTransaction AS (
        SELECT vt.VoidingHistoryId, vt.MessageId, vt.MatchId, STRING_AGG(CAST(vt.TransId AS VARCHAR(MAX)), ',') TransIdList
        FROM bodb02.dbo.TicketVoiding_VoidedTransaction vt WITH (NOLOCK)
        GROUP BY vt.VoidingHistoryId, vt.MessageId, vt.MatchId
    )
    INSERT INTO #tmpAbnormalBet (
        Support_BroadcastSessionId,
        Support_MatchId,
        Support_MessageIdGroup,
        Support_StatusId,
        Support_ModifiedDate,
        Using_VoidingHistoryId,
        Using_RequestId,
        Using_MessageId,
        Using_SiteDBGroupID,
        Using_IssueTypeId,
        Using_RequestBy,
        Using_DecidedBy,
        Using_VoIdBy,
        Using_MatchId,
        Using_TransIdList,
        Using_ReasonList,
        Using_FilterBy
    )
    SELECT vh.BroadcastSessionId Support_BroadcastSessionId,
           rd.MatchId            Support_MatchId,
           vh.MessageIdGroup     Support_MessageIdGroup,
           vh.StatusId           Support_StatusId,
           vh.ModifiedDate       Support_ModifiedDate,
           vh.VoidingHistoryId   Using_VoidingHistoryId,
           rq.RequestId          Using_RequestId,
           vh.MessageId          Using_MessageId,
           vh.SiteDBGroupID      Using_SiteDBGroupID,
           rq.IssueTypeId        Using_IssueTypeId,
           crb.username          Using_RequestBy,
           rq.DecidedBy          Using_DecidedBy,
           vh.VoIdBy             Using_VoIdBy,
           rd.MatchId            Using_MatchId,
           vt.TransIdList        Using_TransIdList,
           rd.ReasonList         Using_ReasonList,
           rd.FilterBy           Using_FilterBy
    FROM bodb02.dbo.TicketVoiding_Request rq WITH (NOLOCK)
         INNER JOIN #tmpTicketVoiding_VoidingHistory vh ON rq.RequestId = vh.RequestId
         INNER JOIN bodb02.dbo.Customer crb WITH (NOLOCK) ON rq.UserId = crb.custid
         INNER JOIN CTE_RequestDetail rd WITH (NOLOCK) ON rq.RequestId = rd.RequestId
         INNER JOIN CTE_VoidTransaction vt WITH (NOLOCK) ON vh.VoidingHistoryId = vt.VoidingHistoryId AND vh.MessageId = vt.MessageId AND rd.MatchId = vt.MatchId
    WHERE rq.IssueTypeId IN (11, 15)


    ---------------------------------------------------------------
    -- Centralize data and clean data and insert data to main table

    -- Centralize data to final  table
    -- + Create temp table
    CREATE TABLE #tmpFinal (
        Support_Id                 INT,
        Support_BroadcastSessionId VARCHAR(100),
        Support_MatchId            INT,
        Support_MessageIdGroup     INT,
        Support_StatusId           TINYINT,
        Support_ModifiedDate       DATETIME,
        Support_IsCollect          BIT DEFAULT(1),
        Using_VoidingHistoryId     INT,
        Using_RequestId            INT,
        Using_MessageId            INT,
        Using_SiteDBGroupID        SMALLINT,
        Using_IssueTypeId          TINYINT,
        Using_RequestBy            NVARCHAR(200),
        Using_DecidedBy            NVARCHAR(200),
        Using_VoIdBy               NVARCHAR(200),
        Using_MatchId              INT,
        Using_TransIdList          VARCHAR(MAX),
        Using_UsernameList         NVARCHAR(MAX),
        Using_ReasonList           NVARCHAR(MAX),
        Using_OriginalTransId      VARCHAR(MAX),
        Using_FilterBy             TINYINT,
        Using_MinWinlostdate       DATETIME,
        Using_MaxWinlostdate       DATETIME
    )
    -- + Gen data to temp table
    --   --> From #tmpAbnormalAccount
    INSERT INTO #tmpFinal (
        Support_BroadcastSessionId,
        Support_MatchId,
        Support_MessageIdGroup,
        Support_StatusId,
        Support_ModifiedDate,
        Support_IsCollect,
        Using_VoidingHistoryId,
        Using_RequestId,
        Using_MessageId,
        Using_SiteDBGroupID,
        Using_IssueTypeId,
        Using_RequestBy,
        Using_DecidedBy,
        Using_VoIdBy,
        Using_MatchId,
        Using_TransIdList,
        Using_UsernameList,
        Using_ReasonList,
        Using_OriginalTransId,
        Using_FilterBy,
        Using_MinWinlostdate,
        Using_MaxWinlostdate
    )
    SELECT Support_BroadcastSessionId,
           Support_MatchId,
           Support_MessageIdGroup,
           Support_StatusId,
           Support_ModifiedDate,
           Support_IsCollect,
           Using_VoidingHistoryId,
           Using_RequestId,
           Using_MessageId,
           Using_SiteDBGroupID,
           Using_IssueTypeId,
           Using_RequestBy,
           Using_DecidedBy,
           Using_VoIdBy,
           NULL Using_MatchId,
           NULL Using_TransIdList,
           Using_UsernameList,
           NULL Using_ReasonList,
           NULL Using_OriginalTransId,
           NULL Using_FilterBy,
           Using_MinWinlostdate,
           Using_MaxWinlostdate
    FROM #tmpAbnormalAccount
    --   --> From #tmpDuplicateTicket
    INSERT INTO #tmpFinal (
        Support_BroadcastSessionId,
        Support_MatchId,
        Support_MessageIdGroup,
        Support_StatusId,
        Support_ModifiedDate,
        Support_IsCollect,
        Using_VoidingHistoryId,
        Using_RequestId,
        Using_MessageId,
        Using_SiteDBGroupID,
        Using_IssueTypeId,
        Using_RequestBy,
        Using_DecidedBy,
        Using_VoIdBy,
        Using_MatchId,
        Using_TransIdList,
        Using_UsernameList,
        Using_ReasonList,
        Using_OriginalTransId,
        Using_FilterBy,
        Using_MinWinlostdate,
        Using_MaxWinlostdate
    )
    SELECT Support_BroadcastSessionId,
           Support_MatchId,
           Support_MessageIdGroup,
           Support_StatusId,
           Support_ModifiedDate,
           Support_IsCollect,
           Using_VoidingHistoryId,
           Using_RequestId,
           Using_MessageId,
           Using_SiteDBGroupID,
           Using_IssueTypeId,
           Using_RequestBy,
           Using_DecidedBy,
           Using_VoIdBy,
           Using_MatchId,
           NULL Using_TransIdList,
           NULL Using_UsernameList,
           NULL Using_ReasonList,
           Using_OriginalTransId,
           Using_FilterBy,
           NULL Using_MinWinlostdate,
           NULL Using_MaxWinlostdate
    FROM #tmpDuplicateTicket
    --   --> From #tmpAbnormalBet
    INSERT INTO #tmpFinal (
        Support_BroadcastSessionId,
        Support_MatchId,
        Support_MessageIdGroup,
        Support_StatusId,
        Support_ModifiedDate,
        Support_IsCollect,
        Using_VoidingHistoryId,
        Using_RequestId,
        Using_MessageId,
        Using_SiteDBGroupID,
        Using_IssueTypeId,
        Using_RequestBy,
        Using_DecidedBy,
        Using_VoIdBy,
        Using_MatchId,
        Using_TransIdList,
        Using_UsernameList,
        Using_ReasonList,
        Using_OriginalTransId,
        Using_FilterBy,
        Using_MinWinlostdate,
        Using_MaxWinlostdate
    )
    SELECT Support_BroadcastSessionId,
           Support_MatchId,
           Support_MessageIdGroup,
           Support_StatusId,
           Support_ModifiedDate,
           Support_IsCollect,
           Using_VoidingHistoryId,
           Using_RequestId,
           Using_MessageId,
           Using_SiteDBGroupID,
           Using_IssueTypeId,
           Using_RequestBy,
           Using_DecidedBy,
           Using_VoIdBy,
           Using_MatchId,
           Using_TransIdList,
           NULL Using_UsernameList,
           Using_ReasonList,
           NULL Using_OriginalTransId,
           Using_FilterBy,
           NULL Using_MinWinlostdate,
           NULL Using_MaxWinlostdate
    FROM #tmpAbnormalBet

    -- Clean data | If all rows have StatusId=2, they will be collected immediately, no need to wait
    --            | If there are some rows with StatusId<>2 (A) and some rows with StatusId=2 (B) then at time >= MIN(ModifiedDate of rows B) + 1 minute will only collect all rows B
    -- + Manipulate data
    ;WITH
    CTE_Session AS (
        SELECT Support_BroadcastSessionId,
               Support_MatchId,
               Support_MessageIdGroup,
               MAX(CASE WHEN Support_StatusId <> 2 THEN 1 ELSE 0 END) + MAX(CASE WHEN Support_StatusId = 2 THEN 2 ELSE 0 END) AS StatusSum, --StatusSum have 3 value: 1_all row not finish | 2_all row finish | 3_some not finish and some finish
               MIN(CASE WHEN Support_StatusId = 2 THEN Support_ModifiedDate ELSE NULL END) AS ModifiedDate                                  --ModifiedDate: just need the min value of all row
        FROM #tmpFinal
        GROUP BY Support_BroadcastSessionId,
                 Support_MatchId,
                 Support_MessageIdGroup
    ),
    CTE_SessionCollection AS (
        SELECT Support_BroadcastSessionId, Support_MatchId, Support_MessageIdGroup
        FROM CTE_Session s
        WHERE StatusSum = 2 OR (StatusSum = 3 AND @CurrentDate >= DATEADD(MINUTE, 1, ModifiedDate)) --Just keep request that all row finish or request that already operate for more than 1 minute (just keep row already finish)
    )
    UPDATE fi
    SET fi.Support_IsCollect = 0 
    FROM #tmpFinal fi
         LEFT JOIN CTE_SessionCollection sc ON fi.Support_BroadcastSessionId = sc.Support_BroadcastSessionId
                                               AND fi.Support_MatchId = sc.Support_MatchId 
                                               AND fi.Support_MessageIdGroup = sc.Support_MessageIdGroup
    WHERE sc.Support_BroadcastSessionId IS NULL
    -- + Delete data
    DELETE FROM #tmpFinal WHERE Support_StatusId <> 2 OR Support_IsCollect = 0 OR Using_MessageId = 0

    -- Insert data to main table
    -- + Update Id
    UPDATE fi
    SET fi.Support_Id = fi.rn
    FROM (
        SELECT Support_Id,
               DENSE_RANK() OVER (ORDER BY Support_BroadcastSessionId, Support_MatchId, Support_MessageIdGroup) AS rn
        FROM #tmpFinal
    ) fi
    -- + Run loop to insert data to main table
    SET @Id = 1
    WHILE EXISTS (SELECT 1 FROM #tmpFinal r WHERE r.Support_Id = @Id)
    BEGIN
        INSERT INTO bodb02.dbo.VoidingHistoryCollection (IsProcessing) VALUES (1)

        SELECT @VoidingHistoryCollectionId = SCOPE_IDENTITY()

        INSERT INTO bodb02.dbo.VoidingHistoryCollectionDetail (
            VoidingHistoryCollectionId,
            VoidingHistoryId,
            RequestId,
            MessageId,
            SiteDBGroupID,
            IssueTypeId,
            RequestBy,
            DecidedBy,
            VoidBy,
            MatchId,
            TransIdList,
            UsernameList,
            ReasonList,
            OriginalTransId,
            FilterBy,
            MinWinlostdate,
            MaxWinlostdate
        )
        SELECT @VoidingHistoryCollectionId VoidingHistoryCollectionId,
               fi.Using_VoidingHistoryId   VoidingHistoryId,
               fi.Using_RequestId          RequestId,
               fi.Using_MessageId          Using_MessageId,
               fi.Using_SiteDBGroupID      SiteDBGroupID,
               fi.Using_IssueTypeId        IssueTypeId,
               fi.Using_RequestBy          RequestBy,
               fi.Using_DecidedBy          DecidedBy,
               fi.Using_VoidBy             VoidBy,
               fi.Using_MatchId            MatchId,
               fi.Using_TransIdList        TransIdList,
               fi.Using_UsernameList       UsernameList,
               fi.Using_ReasonList         ReasonList,
               fi.Using_OriginalTransId    OriginalTransId,
               fi.Using_FilterBy           FilterBy,
               fi.Using_MinWinlostdate     MinWinlostdate,
               fi.Using_MaxWinlostdate     MaxWinlostdate
        FROM #tmpFinal fi
        WHERE fi.Support_Id = @Id

        UPDATE bodb02.dbo.VoidingHistoryCollection WITH (ROWLOCK, UPDLOCK)
        SET IsProcessing = 0
        WHERE VoidingHistoryCollectionId = @VoidingHistoryCollectionId

        SET @Id += 1
    END


    -------------------------------------------
    -- Clean old data and keep data for 2 month

    DECLARE @VoidingHistoryCollectionId_DeletePoint INT
    SELECT  @VoidingHistoryCollectionId_DeletePoint = MAX(VoidingHistoryCollectionId) FROM bodb02.dbo.VoidingHistoryCollection WITH (NOLOCK) WHERE CreatedDate <= DATEADD(MONTH, -2 , @CurrentDate)

    IF (ISNULL(@VoidingHistoryCollectionId_DeletePoint, 0) <> 0)
    BEGIN
        DELETE bodb02.dbo.VoidingHistoryCollectionDetail WITH (ROWLOCK, UPDLOCK)
        WHERE VoidingHistoryCollectionId <= @VoidingHistoryCollectionId_DeletePoint

        DELETE bodb02.dbo.VoidingHistoryCollection WITH (ROWLOCK, UPDLOCK)
        WHERE VoidingHistoryCollectionId <= @VoidingHistoryCollectionId_DeletePoint
    END


    -------------------
    -- Drop temp tables

    DROP TABLE #tmpTicketVoiding_VoidingHistory
    DROP TABLE #tmpAbnormalAccount
    DROP TABLE #tmpDuplicateTicket
    DROP TABLE #tmpAbnormalBet
    DROP TABLE #tmpFinal

END
GO