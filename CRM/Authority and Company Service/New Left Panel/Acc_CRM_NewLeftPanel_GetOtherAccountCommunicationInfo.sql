/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_NewLeftPanel_GetOtherAccountCommunicationInfo @CustID INT
AS

/*
	Created: Ned.Le
	Date:    20231212
	Task:    Get list of communication info of direct account
	DB:      DBCRM.bodb_CRM

	Revisions:
        20231212@Ned.Le: CRM - Manage Headline/PIC/Staff authority and Company services (#193385)

	Param's Explanation:
        @CustID: CustID that be used to get data

    Example:
        EXEC bodb_CRM.dbo.Acc_CRM_NewLeftPanel_GetOtherAccountCommunicationInfo @CustID=18547241
*/

BEGIN

	SET NOCOUNT ON

    SELECT ccc.CustID             CustID,
           ccc.CommunicationID    CommunicationID,
           sc.SettingValue        CommunicationName,
           ccc.CommunicationValue CommunicationValue
    FROM bodb_CRM.dbo.crmCustomerNewCommunicationTool ccc WITH (NOLOCK)
         LEFT JOIN bodb_CRM.dbo.crmSetting sc WITH (NOLOCK) ON sc.SettingName = 'PICCommunicationTool' AND ccc.CommunicationID = sc.SettingID
    WHERE ccc.CustID = @CustID
          AND sc.IsActive = 1
    ORDER BY sc.SettingValue
    OPTION (RECOMPILE)

END
GO