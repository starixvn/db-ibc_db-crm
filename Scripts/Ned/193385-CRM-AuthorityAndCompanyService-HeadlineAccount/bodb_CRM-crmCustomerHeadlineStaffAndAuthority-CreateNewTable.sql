/*<info serverAlias="DBCRM-bodb_CRM"></info>*/

/*
    Created: 20231212@Ned.Le
    DB:      DBCRM-bodb_CRM
    Task:    Create new table crmCustomerHeadlineStaffAndAuthority
*/

USE bodb_CRM
GO

IF OBJECT_ID('bodb_CRM.dbo.crmCustomerHeadlineStaffAndAuthority') IS NOT NULL
BEGIN
    DROP TABLE dbo.crmCustomerHeadlineStaffAndAuthority
END
GO

CREATE TABLE dbo.crmCustomerHeadlineStaffAndAuthority
(
    RowID                 INT            NOT NULL IDENTITY(1,1),
    HeadlineID            INT            NOT NULL,
    PicID                 INT            NULL,
    PicName               NVARCHAR(200)  NOT NULL,
    PicRoleID             INT            NOT NULL,
    PicCommunicationID    INT            NOT NULL,
    PicCommunicationValue NVARCHAR(200)  NULL,
    AuthorityID           VARCHAR(MAX)   NULL,
    Remark                NVARCHAR(4000) NULL,
    isSyncFromPicTable    BIT            NOT NULL DEFAULT 1,
    CreatedDate           DATETIME       NOT NULL DEFAULT GETDATE()
    
    CONSTRAINT [PK_crmCustomerHeadlineStaffAndAuthority] PRIMARY KEY CLUSTERED (RowID) ON [customer_index]
) ON [customer_table]
GO