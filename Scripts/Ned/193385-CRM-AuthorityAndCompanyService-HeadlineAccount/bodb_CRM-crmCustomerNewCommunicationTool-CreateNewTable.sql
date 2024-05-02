/*<info serverAlias="DBCRM-bodb_CRM"></info>*/

/*
    Created: 20231212@Ned.Le
    DB:      DBCRM-bodb_CRM
    Task:    Create new table crmCustomerNewCommunicationTool
*/

USE bodb_CRM
GO

IF OBJECT_ID('bodb_CRM.dbo.crmCustomerNewCommunicationTool') IS NOT NULL
BEGIN
    DROP TABLE dbo.crmCustomerNewCommunicationTool
END
GO

CREATE TABLE dbo.crmCustomerNewCommunicationTool
(
	CustID          INT              NOT NULL,
    CommunicationID INT              NOT NULL,
	CommunicationValue NVARCHAR(200) NULL,
    
    CONSTRAINT [PK_crmCustomerNewCommunicationTool] PRIMARY KEY CLUSTERED (CustID, CommunicationID) ON [customer_index]
) ON [customer_table]
GO