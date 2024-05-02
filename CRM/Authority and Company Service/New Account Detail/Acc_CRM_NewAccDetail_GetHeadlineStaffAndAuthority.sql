/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_NewAccDetail_GetHeadlineStaffAndAuthority @HeadlineID INT
AS

/*
	Created: Ned.Le
	Date:    20231212
	Task:    Get Staff and Authotity of Headline
	DB:      DBCRM.bodb_CRM

	Revisions:
        20231212@Ned.Le: CRM - Manage Headline/PIC/Staff authority and Company services (#193385)

	Param's Explanation:
        @HeadlineID: HeadlineID (also be CustID) that be used to get data

    Example:
        EXEC bodb_CRM.dbo.Acc_CRM_NewAccDetail_GetHeadlineStaffAndAuthority @HeadlineID=1211024
*/

BEGIN

	SET NOCOUNT ON

    ;WITH
    CTE_ParseAuthority AS (
        SELECT cha.RowID,
               cha.PicID,
               cha.PicCommunicationID,
               au.AuthorityID,
               sa.SettingValue Authority
        FROM bodb_CRM.dbo.crmCustomerHeadlineStaffAndAuthority cha WITH (NOLOCK)
             OUTER APPLY (SELECT TRIM(value) AuthorityID FROM STRING_SPLIT(cha.AuthorityID, ',')) au
             LEFT JOIN bodb_CRM.dbo.crmSetting sa WITH (NOLOCK) ON sa.SettingName = 'StaffAndAuthority' AND sa.IsActive = 1 AND au.AuthorityID = sa.SettingID
        WHERE ((ISNULL(cha.AuthorityID, '') =  '' AND sa.SettingValue IS NULL) OR
               (ISNULL(cha.AuthorityID, '') <> '' AND sa.SettingValue IS NOT NULL))
    ),
    CTE_AggAuthority AS (
        SELECT RowID,
               STRING_AGG(CAST(AuthorityID AS NVARCHAR(MAX)), ',') AuthorityID,
               STRING_AGG(CAST(Authority AS NVARCHAR(MAX)), '|') Authority
        FROM CTE_ParseAuthority
        GROUP BY RowID
    )
    SELECT cha.RowID                 RowID,
           cha.HeadlineID            HeadlineID,
           cha.PicID                 PicID,
           cha.PicName               PicName,
           cha.PicRoleID             PicRoleID,
           sr.SettingValue           PicRoleName,
           cha.PicCommunicationID    PicCommunicationID,
           sc.SettingValue           PicCommunicationName,
           cha.PicCommunicationValue PicCommunicationValue,
           cte.AuthorityID           AuthorityID,
           cte.Authority             Authority,
           cha.Remark                Remark,
           cha.isSyncFromPicTable    isSyncFromPicTable,
           cha.CreatedDate           CreatedDate
    FROM bodb_CRM.dbo.crmCustomerHeadlineStaffAndAuthority cha WITH (NOLOCK)
         LEFT JOIN CTE_AggAuthority cte ON cha.RowID = cte.RowID
         LEFT JOIN bodb_CRM.dbo.crmSetting sr WITH (NOLOCK) ON sr.SettingName = 'PICRole' AND cha.PicRoleID = sr.SettingID
         LEFT JOIN bodb_CRM.dbo.crmSetting sc WITH (NOLOCK) ON sc.SettingName = 'PICCommunicationTool' AND cha.PicCommunicationID = sc.SettingID
    WHERE cha.HeadlineID = @HeadlineID
          AND sc.IsActive = 1
    ORDER BY cha.isSyncFromPicTable DESC,
             CASE WHEN cha.isSyncFromPicTable = 1 AND sr.SettingValue = 'Boss' THEN 1 ELSE 2 END,
             CASE WHEN cha.isSyncFromPicTable = 1 AND sr.SettingValue = 'Boss' THEN cha.PicName END,
             CASE WHEN cha.isSyncFromPicTable = 1 THEN sr.SettingValue END,
             CASE WHEN cha.isSyncFromPicTable = 1 THEN cha.PicName END,
             CASE WHEN cha.isSyncFromPicTable = 0 THEN cha.CreatedDate END
    OPTION (RECOMPILE)

END
GO