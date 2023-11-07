/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_CategoryClassificationSel @MainCategoryID INT,
                                                      @SubCategoryID  INT,
                                                      @ErrCode        INT            = 0  OUTPUT,
                                                      @ErrMsg         NVARCHAR(4000) = '' OUTPUT
AS

/*
	Created: Ned.Le
	Date:    20230922
	Task:    Get specific MainCategory/SubCategory with Remark
	DB:      DBCRM.bodb_CRM

	Revisions:
        20230922@Ned.Le: CRM - Category Classification (Remark management) (#193383)

	Param's Explanation:
        @MainCategoryID: MainCategoryID that need to get information
        @SubCategoryID:  SubCategoryID that need to get information

    Example:
        -- CASE 01
        DECLARE @ErrCode_out INT = 0
        DECLARE @ErrMsg_out  NVARCHAR(4000) = ''
        EXEC bodb_CRM.dbo.Acc_CRM_CategoryClassificationSel @MainCategoryID = 86000,
                                                            @SubCategoryID  = NULL,
                                                            @ErrCode        = @ErrCode_out OUTPUT,
                                                            @ErrMsg         = @ErrMsg_out  OUTPUT
        SELECT @ErrCode_out ErrCode, @ErrMsg_out ErrMsg

        -- CASE 02
        DECLARE @ErrCode_out INT = 0
        DECLARE @ErrMsg_out  NVARCHAR(4000) = ''
        EXEC bodb_CRM.dbo.Acc_CRM_CategoryClassificationSel @MainCategoryID = NULL,
                                                            @SubCategoryID  = 97003,
                                                            @ErrCode        = @ErrCode_out OUTPUT,
                                                            @ErrMsg         = @ErrMsg_out  OUTPUT
        SELECT @ErrCode_out ErrCode, @ErrMsg_out ErrMsg

        -- CASE 03
        DECLARE @ErrCode_out INT = 0
        DECLARE @ErrMsg_out  NVARCHAR(4000) = ''
        EXEC bodb_CRM.dbo.Acc_CRM_CategoryClassificationSel @MainCategoryID = 86000,
                                                            @SubCategoryID  = 97003,
                                                            @ErrCode        = @ErrCode_out OUTPUT,
                                                            @ErrMsg         = @ErrMsg_out  OUTPUT
        SELECT @ErrCode_out ErrCode, @ErrMsg_out ErrMsg
*/

BEGIN

	SET NOCOUNT ON

    -- Check input paramter
    IF (@MainCategoryID IS NULL AND @SubCategoryID IS NULL)
    BEGIN
        SET @ErrCode = 101
        SET @ErrMsg  = 'All input parameter is NULL'

        RETURN
    END

    -- Create temp table
    CREATE TABLE #tmpResult (
        MainCategoryID INT,
        MainCategory   NVARCHAR(100),
        SubCategoryID  INT,
        SubCategory    NVARCHAR(100),
        Remark         NVARCHAR(MAX)
    )

    -- Gen data to temp table
    INSERT INTO #tmpResult (
        MainCategoryID,
        MainCategory,
        SubCategoryID,
        SubCategory,
        Remark
    )
    SELECT m.SettingID    MainCategoryID,
           m.SettingValue MainCategory,
           s.SettingID    SubCategoryID,
           s.SettingValue SubCategory,
           sr.Remark      Remark
    FROM bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK)
         INNER JOIN bodb_CRM.dbo.crmSetting m WITH (NOLOCK) ON sr.ParentID = m.SettingID
         INNER JOIN bodb_CRM.dbo.crmSetting s WITH (NOLOCK) ON sr.SettingID = s.SettingID
    WHERE sr.ParentID = (CASE WHEN @MainCategoryID IS NULL THEN sr.ParentID ELSE @MainCategoryID END)
          AND sr.SettingID = (CASE WHEN @SubCategoryID IS NULL THEN sr.SettingID ELSE @SubCategoryID END)
    ORDER BY m.SettingValue, s.SettingValue

    -- Return data
    SELECT MainCategoryID,
           MainCategory,
           SubCategoryID,
           SubCategory,
           Remark
    FROM #tmpResult

    -- Drop temp table
    DROP TABLE #tmpResult

END
GO