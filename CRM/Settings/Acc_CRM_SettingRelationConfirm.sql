/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

CREATE PROCEDURE dbo.Acc_CRM_SettingRelationConfirm @SettingID   VARCHAR(MAX) = '',
                                                    @ParentID    INT,
                                                    @SettingName VARCHAR(50)  = ''
AS

/*
	Created: Ned.Le
	Date:    20230922
	Task:    Check the existence of remark between setting relationship
	DB:      DBCRM.bodb_CRM

	Revisions:
        20230922@Ned.Le: CRM - Category Classification (Remark management) (#193383)

	Param's Explanation:
		@SettingID:   List of child settingid that be checked
        @ParentID:    The settingid that have child settingid
        @SettingName: The settingname of child settingid

    Example
        EXEC bodb_CRM.dbo.Acc_CRM_SettingRelationConfirm @SettingID   = '97000,97003,97001,97002',
                                                         @ParentID    = 86000,
                                                         @SettingName = 'qc'
*/

BEGIN

	SET NOCOUNT ON

    -- #tmpCheckedSettingIDList
    -- + Split list of checked child settingid from input parameter @SettingID
    CREATE TABLE #tmpCheckedSettingIDList (SettingID INT)

    INSERT INTO  #tmpCheckedSettingIDList (SettingID)
    SELECT value SettingID FROM STRING_SPLIT (ISNULL(@SettingID, ''), ',')

    -- #tmpSettingRelationHaveRemark
    -- + Get list of existed child settingid that not be checked
    CREATE TABLE #tmpSettingRelationHaveRemark (SettingID INT, ParentID INT, Remark NVARCHAR(MAX))

    INSERT INTO  #tmpSettingRelationHaveRemark (SettingID, ParentID, Remark)
    SELECT SettingID, ParentID, Remark
    FROM bodb_CRM.dbo.crmSettingRelation WITH (NOLOCK)
    WHERE SettingID IN (SELECT SettingID
                        FROM bodB_CRM.dbo.crmSetting WITH (NOLOCK)
                        WHERE SettingName = @SettingName
                              AND SettingID NOT IN (SELECT SettingID FROM #tmpCheckedSettingIDList))
          AND ParentID = @ParentID

    -- Check value and return result
    DECLARE @counttable INT = 0
    SELECT  @counttable = COUNT(1) FROM #tmpSettingRelationHaveRemark WHERE Remark IS NOT NULL

    IF (@counttable > 0)
    BEGIN
        SELECT 1 isHaveRamark
    END
    ELSE
    BEGIN
        SELECT 0 isHaveRamark
    END

    -- Drop temp table
    DROP TABLE #tmpCheckedSettingIDList
    DROP TABLE #tmpSettingRelationHaveRemark

END
GO