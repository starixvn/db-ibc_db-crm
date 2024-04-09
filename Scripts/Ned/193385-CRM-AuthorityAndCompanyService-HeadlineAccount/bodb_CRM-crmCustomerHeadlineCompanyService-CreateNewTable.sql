/*<info serverAlias="DBCRM-bodb_CRM"></info>*/

/*
    Created: 20231212@Ned.Le
    DB:      DBCRM-bodb_CRM
    Task:    Create new table crmCustomerHeadlineCompanyService
*/

USE bodb_CRM
GO

IF OBJECT_ID('bodb_CRM.dbo.crmCustomerHeadlineCompanyService') IS NOT NULL
BEGIN
    DROP TABLE dbo.crmCustomerHeadlineCompanyService
END
GO

CREATE TABLE dbo.crmCustomerHeadlineCompanyService
(
	HeadlineID         INT           NOT NULL,
    CompanyServiceID   INT           NOT NULL,
    isOffered          BIT           NOT NULL,
    CommunicationID    INT           NULL,
    CommunicationValue NVARCHAR(200) NULL,
    
    CONSTRAINT [PK_crmCustomerHeadlineCompanyService] PRIMARY KEY CLUSTERED (HeadlineID, CompanyServiceID) ON [customer_index]
) ON [customer_table]
GO