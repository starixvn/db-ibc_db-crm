/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb02
GO

ALTER PROCEDURE dbo.Acc_CRM_AutoVoidingIssueType_Sel @MessageIDs VARCHAR(MAX)
AS

/*
    Created: 20231009@Malcolm
    Task: Get IssueType
    DB: DBACC/bodb02

    Revisions:
        - 20231009@Malcolm: Initialize SPs [Redmine: #191355]
        - 20240102@Ned.Le: CRM/Chatbot - Message Notifications for Voiding Tickets of Special Sites (ChinaView, JollySports) [RedmineId : #198905]

    Param's Explanation:
        @MessageIDs = '<ROOT>
                         <r MessageId="1074531543"/>
                       </ROOT>'
*/

BEGIN

    SET NOCOUNT ON

    DECLARE @xml     XML = CAST(@MessageIds AS XML)
    DECLARE @Message TABLE (MessageId INT, IssueTypeId TINYINT)

    INSERT INTO @Message (MessageId)
    SELECT t.c.value('@MessageId[1]','int') MessageId
    FROM @xml.nodes('/ROOT/r') t(c)

    ;WITH
    CTE_VoidingHistory_raw AS (
        SELECT RequestId, ISNULL(MessageId, 0) MessageId FROM bodb02.dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK)
        UNION ALL
        SELECT RequestId, ISNULL(MessageIdSpecial, 0) MessageId FROM bodb02.dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK)
    ),
    CTE_VoidingHistory_final AS (
        SELECT RequestId, MessageId
        FROM CTE_VoidingHistory_raw
        GROUP BY RequestId, MessageId
    )
    UPDATE m
    SET m.IssueTypeId = ISNULL(r.IssueTypeId, 0) 
    FROM @Message m
         LEFT JOIN CTE_VoidingHistory_final vh ON m.MessageId = vh.MessageId
         LEFT JOIN bodb02.dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = vh.RequestId

    SELECT DISTINCT MessageId, IssueTypeId FROM @Message

END	