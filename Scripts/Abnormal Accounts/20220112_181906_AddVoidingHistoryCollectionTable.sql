/*<info serverAlias="DBACC-bodb02"></info>*/
/*
	Created: 20220112@Malcolm
	Task : Add new table
	DB: DBACC/bodb02
*/
USE [bodb02]
GO

CREATE TABLE dbo.VoidingHistoryCollection 
(
	VoidingHistoryCollectionId INT IDENTITY(1, 1) NOT NULL
	,IsProcessing BIT
	,CreatedDate DATETIME DEFAULT GETDATE()
	,CONSTRAINT [PK_VoidingHistoryCollection] PRIMARY KEY CLUSTERED 
	(
		VoidingHistoryCollectionId ASC
	) ON [DATA]
) ON [DATA]
GO

CREATE NONCLUSTERED INDEX IX_CreatedDate ON VoidingHistoryCollection (CreatedDate)
GO

CREATE NONCLUSTERED INDEX IX_IsProcessing ON dbo.VoidingHistoryCollection (IsProcessing)
GO

CREATE TABLE dbo.VoidingHistoryCollectionDetail
(
	VoidingHistoryCollectionId INT
	,VoidingHistoryId INT
	,CONSTRAINT [PK_VoidingHistoryCollectionDetail] PRIMARY KEY CLUSTERED
	(
		VoidingHistoryCollectionId ASC, VoidingHistoryId ASC 
	) ON [DATA]
) ON [DATA]

CREATE NONCLUSTERED INDEX IX_VoidingHistoryId ON dbo.VoidingHistoryCollectionDetail (VoidingHistoryId)
GO

CREATE TABLE dbo.VoidingHistoryCollectionDetail
(
	VoidingHistoryCollectionId INT
	,VoidingHistoryId INT
	,CONSTRAINT [PK_VoidingHistoryCollectionDetail] PRIMARY KEY CLUSTERED
	(
		VoidingHistoryCollectionId ASC, VoidingHistoryId ASC 
	) ON [DATA]
) ON [DATA]
GO
