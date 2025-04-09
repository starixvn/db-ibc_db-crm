/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
/*
    Created: 20250408@Virgil
    DB: DBACC-bodb02
    Task: CRM - Hotfix The licensee not recorded in CRM [RedmineID: #222618]
*/
USE [bodb02]
GO

CREATE CLUSTERED INDEX [CIX_TicketVoiding_RequestDetail_RequestId] ON [dbo].[TicketVoiding_RequestDetail] ([RequestId])

CREATE NONCLUSTERED INDEX [IX_VoidingHistoryId_MessageId_MatchId] ON [dbo].[TicketVoiding_VoidedTransaction] ([VoidingHistoryId],[MessageId],[MatchId])