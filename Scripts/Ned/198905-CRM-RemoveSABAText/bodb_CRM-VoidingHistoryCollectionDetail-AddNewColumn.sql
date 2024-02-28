/*<info serverAlias="DBACC-bodb02"></info>*/

/*
Created: 20231228@Ned.Le
DB: DBACC.bodb02
Task: Add some new columns to table VoidingHistoryCollectionDetail
*/

USE bodb02
GO

ALTER TABLE dbo.VoidingHistoryCollectionDetail ADD RequestId INT
GO
ALTER TABLE dbo.VoidingHistoryCollectionDetail ADD MessageId INT
GO
ALTER TABLE dbo.VoidingHistoryCollectionDetail ADD SiteDBGroupID SMALLINT
GO
ALTER TABLE dbo.VoidingHistoryCollectionDetail ADD IssueTypeId TINYINT
GO
ALTER TABLE dbo.VoidingHistoryCollectionDetail ADD RequestBy NVARCHAR(200)
GO
ALTER TABLE dbo.VoidingHistoryCollectionDetail ADD DecidedBy NVARCHAR(200)
GO
ALTER TABLE dbo.VoidingHistoryCollectionDetail ADD VoidBy NVARCHAR(200)
GO
ALTER TABLE dbo.VoidingHistoryCollectionDetail ADD MatchId INT
GO
ALTER TABLE dbo.VoidingHistoryCollectionDetail ADD TransIdList VARCHAR(MAX)
GO
ALTER TABLE dbo.VoidingHistoryCollectionDetail ADD UsernameList NVARCHAR(MAX)
GO
ALTER TABLE dbo.VoidingHistoryCollectionDetail ADD ReasonList NVARCHAR(MAX)
GO
ALTER TABLE dbo.VoidingHistoryCollectionDetail ADD OriginalTransId VARCHAR(MAX)
GO
ALTER TABLE dbo.VoidingHistoryCollectionDetail ADD FilterBy TINYINT
GO
ALTER TABLE dbo.VoidingHistoryCollectionDetail ADD MinWinlostdate DATETIME
GO
ALTER TABLE dbo.VoidingHistoryCollectionDetail ADD MaxWinlostdate DATETIME
GO