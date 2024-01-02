/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/

USE bodb02
GO

ALTER PROCEDURE dbo.Acc_CRM_Chatbot_AbnormalBets_GetMessage @LastVoidingHistoryCollectionId INT,
                                                            @BatchSize                      INT = 10
AS

/*
    Created: 20200811@Percy
    DB: DBACC.bodb02
    Task: CRM - ChatBot - Get Message List of Voiding Abnormal Bets from special delete site

    Revisions:
        - 20200811@Percy: Initialize SP [RedmineID: #130544]
        - 20210415@Malcolm: Notify Tickets of AB (Real Member) [RedmineId : #153259]
        - 20210415@Malcolm: Integrate Abnormal Accounts [RedmineId : #157303]
        - 20220112@Malcolm: Scale Out for CRM [RedmineId : #181906]
        - 20230731@Malcolm: Exclude Issue type = 20 [RedmineId : #191355]
        - 20240102@Ned.Le: CRM/Chatbot - Message Notifications for Voiding Tickets of Special Sites (ChinaView, JollySports) [RedmineId : #198905]
*/

BEGIN

    SET NOCOUNT ON

    -- Notes
    -- + We get data by following @LastVoidingHistoryCollectionId and @BatchSize
    -- + We just get VoidingHistoryCollectionId that be done on processing [IsProcessing = 0]
    -- + We not get data of Duplicate Tickets [IssueTypeId NOT IN (20)]
    ;WITH CTE_Data AS (
        SELECT DISTINCT TOP(@BatchSize) c.VoidingHistoryCollectionId
        FROM bodb02.dbo.VoidingHistoryCollection c WITH (NOLOCK)
             INNER JOIN bodb02.dbo.VoidingHistoryCollectionDetail cd WITH (NOLOCK) ON c.VoidingHistoryCollectionId = cd.VoidingHistoryCollectionId
        WHERE c.VoidingHistoryCollectionId > @LastVoidingHistoryCollectionId
              AND c.IsProcessing = 0
              AND cd.IssueTypeId NOT IN (20)
        ORDER BY c.VoidingHistoryCollectionId ASC
    )
    SELECT DISTINCT
           VoidingHistoryCollectionId,
           MessageId,
           IssueTypeId,
           TrasnIdList,
           UsernameList,
           FilterBy
    FROM bodb02.dbo.VoidingHistoryCollectionDetail WITH (NOLOCK)
    WHERE VoidingHistoryCollectionId IN (SELECT VoidingHistoryCollectionId FROM CTE_Data)

END
GO