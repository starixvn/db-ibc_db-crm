/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_NewAccDetail_CheckCustomerExistsOnCRM @CustID INT
AS

/*
	Created: Ned.Le
	Date:    20231212
	Task:    Check if the customer exists on the CRM system (exists data on table crmCustomer)
	DB:      DBCRM.bodb_CRM

	Revisions:
        20231212@Ned.Le: CRM - Manage Headline/PIC/Staff authority and Company services (#193385)

	Param's Explanation:
        @CustID: CustID to check

    Example:
        EXEC bodb_CRM.dbo.Acc_CRM_NewAccDetail_CheckCustomerExistsOnCRM @CustID=101555302
*/

BEGIN

	SET NOCOUNT ON

    IF EXISTS (SELECT 1 FROM bodb_CRM.dbo.crmCustomer WITH (NOLOCK) WHERE CustID = @CustID)
    BEGIN
        SELECT 1
    END
    ELSE
    BEGIN
        SELECT 0
    END

END
GO