/*<info serverAlias="DBCRM-bodb_CRM"></info>*/

/*
    Created: 20240119@Ned.Le
    DB:      DBCRM-bodb_CRM
    Task:    Create new table crmFeedbackNewCommunicationTool
*/

USE bodb_CRM
GO

IF OBJECT_ID('bodb_CRM.dbo.crmFeedbackNewCommunicationTool') IS NOT NULL
BEGIN
    DROP TABLE dbo.crmFeedbackNewCommunicationTool
END
GO

CREATE TABLE dbo.crmFeedbackNewCommunicationTool
(
    FeedbackID         INT           NOT NULL,
    CustID             INT           NOT NULL,
    isHeadline         BIT           NOT NULL,
    PicInfo            NVARCHAR(200) NOT NULL DEFAULT(''),
    CommunicationID    INT           NOT NULL,
    CommunicationValue NVARCHAR(200) NULL

    CONSTRAINT [PK_crmFeedbackNewCommunicationTool] PRIMARY KEY CLUSTERED (FeedbackID, CustID, PicInfo, CommunicationID) ON [feedback_index]
) ON [feedback_table]
GO