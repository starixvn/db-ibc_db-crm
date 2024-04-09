/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_NewAccDetail_GetHeadlineCompanyService @HeadlineID INT
AS

/*
	Created: Ned.Le
	Date:    20231212
	Task:    Get Company Service of Headline
	DB:      DBCRM.bodb_CRM

	Revisions:
        20231212@Ned.Le: CRM - Manage Headline/PIC/Staff authority and Company services (#193385)

	Param's Explanation:
        @HeadlineID: HeadlineID (also be CustID) that be used to get data

    Example:
        EXEC bodb_CRM.dbo.Acc_CRM_NewAccDetail_GetHeadlineCompanyService @HeadlineID=10695
*/

BEGIN

	SET NOCOUNT ON


    ----------------------------
    -- Get data for data grid --

    -- Create temp table
    CREATE TABLE #tmpHeadlineCompanyService (
        HeadlineID         INT,
        CompanyServiceID   INT,
        CompanyServiceName NVARCHAR(100),
        isOffered          BIT,
        CommunicationID    INT,
        CommunicationName  NVARCHAR(100),
        CommunicationValue NVARCHAR(200)
    )

    -- Gen data from main table
    INSERT INTO #tmpHeadlineCompanyService (
        HeadlineID,
        CompanyServiceID,
        CompanyServiceName,
        isOffered,
        CommunicationID,
        CommunicationName,
        CommunicationValue
    )
    SELECT chc.HeadlineID         HeadlineID,
           chc.CompanyServiceID   CompanyServiceID,
           scs.SettingValue       CompanyServiceName,
           chc.isOffered          isOffered,
           chc.CommunicationID    CommunicationID,
           sc.SettingValue        CommunicationName,
           chc.CommunicationValue CommunicationValue
    FROM bodb_CRM.dbo.crmCustomerHeadlineCompanyService chc WITH (NOLOCK)
         LEFT JOIN bodb_CRM.dbo.crmSetting scs WITH (NOLOCK) ON scs.SettingName = 'HeadlineCompanyService' AND chc.CompanyServiceID = scs.SettingID
         LEFT JOIN bodb_CRM.dbo.crmSetting sc WITH (NOLOCK) ON sc.SettingName = 'PICCommunicationTool' AND chc.CommunicationID = sc.SettingID
    WHERE chc.HeadlineID = @HeadlineID
          AND scs.IsActive = 1
          AND sc.IsActive = 1
    OPTION (RECOMPILE)

    -- Gen data from setting table
    INSERT INTO #tmpHeadlineCompanyService (
        HeadlineID,
        CompanyServiceID,
        CompanyServiceName,
        isOffered,
        CommunicationID,
        CommunicationName,
        CommunicationValue
    )
    SELECT c.CustID         HeadlineID,
           scs.SettingID    CompanyServiceID,
           scs.SettingValue CompanyServiceName,
           0                isOffered,
           NULL             CommunicationID,
           NULL             CommunicationName,
           NULL             CommunicationValue
    FROM bodb_CRM.dbo.crmCustomer c WITH (NOLOCK)
         CROSS JOIN bodb_CRM.dbo.crmSetting scs WITH (NOLOCK)
    WHERE c.CustID = @HeadlineID
          AND scs.SettingName = 'HeadlineCompanyService'
          AND scs.SettingID NOT IN (SELECT CompanyServiceID FROM #tmpHeadlineCompanyService)
          AND scs.IsActive = 1
    OPTION (RECOMPILE)

    -- Return data
    SELECT HeadlineID,
           CompanyServiceID,
           CompanyServiceName,
           isOffered,
           CommunicationID,
           CommunicationName,
           CommunicationValue
    FROM #tmpHeadlineCompanyService
    ORDER BY CompanyServiceName


    ----------------------------------
    -- Get data for data suggestion --

    SELECT DISTINCT
           cgh.HeadlineId,
           sc.SettingID CommunicationID,
           sc.SettingValue CommunicationName,
           cg.ConversationGroupName DisplayName
    FROM bodb_CRM.dbo.crmConversationGroupHeadline cgh WITH (NOLOCK)
         INNER JOIN bodb_CRM.dbo.crmConversationGroup cg WITH (NOLOCK) ON cgh.ConversationGroupId = cg.ConversationGroupId
         INNER JOIN bodb_CRM.dbo.crmChannel ch WITH (NOLOCK) ON cg.ChannelId = ch.ChannelId
         INNER JOIN bodb_CRM.dbo.crmSetting sc WITH (NOLOCK) ON sc.SettingName = 'PICCommunicationTool' AND ch.ChannelName = sc.SettingValue
    WHERE cgh.HeadlineId = @HeadlineID
          AND sc.IsActive = 1
          AND cg.IsActive = 1
    ORDER BY cg.ConversationGroupName
    OPTION (RECOMPILE)


    ---------------------
    -- Drop temp table --

    DROP TABLE #tmpHeadlineCompanyService

END
GO