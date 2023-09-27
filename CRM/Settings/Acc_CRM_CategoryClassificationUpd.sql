/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_CategoryClassificationUpd @MainCategoryID INT,
                                                      @SubCategoryID  INT,
                                                      @RemarkNewValue NVARCHAR(MAX) = NULL,
                                                      @ActionType     INT,
                                                      @UserID         INT,
                                                      @IP             VARCHAR(45),
                                                      @ErrCode        INT            = 0  OUTPUT,
                                                      @ErrMsg         NVARCHAR(4000) = '' OUTPUT
AS

/*
	Created: Ned.Le
	Date:    20230922
	Task:    Delete Remark of specific MainCategory/SubCategory
	DB:      DBCRM.bodb_CRM

	Revisions:
        20230922@Ned.Le: CRM - Category Classification (Remark management) (#193383)

	Param's Explanation:
        @MainCategoryID: Value of column ParentID in table crmSettingRelation
        @SubCategoryID:  Value of column SettingID in table crmSettingRelation
        @RemarkNewValue: Value that be used to update column Remark in table crmSettingRelation
        @ActionType:     1-This is the action that update value column Remark
                         2-This is the action that delete value column Remark

    Example
        DECLARE @ErrCode_out INT = 0
        DECLARE @ErrMsg_out  NVARCHAR(4000) = ''
        EXEC bodb_CRM.dbo.Acc_CRM_CategoryClassificationUpd @MainCategoryID = 86000,
                                                            @SubCategoryID  = 97003,
                                                            @RemarkNewValue = NULL,
                                                            @ActionType     = 2,
                                                            @UserID         = 8,
                                                            @IP             = '10.0.0.4',
                                                            @ErrCode        = @ErrCode_out OUTPUT,
                                                            @ErrMsg         = @ErrMsg_out  OUTPUT
        SELECT @ErrCode_out ErrCode, @ErrMsg_out ErrMsg
*/

BEGIN

	SET NOCOUNT ON

    -- Check the existence of relationship of MainCategory/SubCategory
    DECLARE @countable INT

    SELECT @countable = COUNT(1)
    FROM bodb_CRM.dbo.crmSettingRelation WITH (NOLOCK)
    WHERE ParentID = @MainCategoryID AND SettingID = @SubCategoryID

    IF (@countable = 0)
    BEGIN
        SET @ErrCode = 101
        SET @ErrMsg  = 'Not exist the relationship of MainCategory/SubCategory'

        RETURN
    END

    -- Check the consistency between @RemarkNewValue and @ActionType
    IF (@ActionType = 1 AND @RemarkNewValue IS NULL)
    BEGIN
        SET @ErrCode = 102
        SET @ErrMsg  = 'For update Remark, value of @RemarkNewValue must be NOT NULL'

        RETURN
    END

    IF (@ActionType = 2 AND @RemarkNewValue IS NOT NULL)
    BEGIN
        SET @ErrCode = 103
        SET @ErrMsg  = 'For delete Remark, value of @RemarkNewValue must be NULL'

        RETURN
    END


    -- Get old value of Remark
    DECLARE @RemarkOldValue NVARCHAR(MAX)
    SELECT  @RemarkOldValue = Remark
    FROM bodb_CRM.dbo.crmSettingRelation WITH (NOLOCK)
    WHERE ParentID = @MainCategoryID AND SettingID = @SubCategoryID

    -- Update/Delete Remark of MainCategory/SubCategory
	UPDATE sr
    SET sr.Remark = @RemarkNewValue
    FROM bodb_CRM.dbo.crmSettingRelation sr WITH (ROWLOCK, UPDLOCK)
    WHERE ParentID = @MainCategoryID AND SettingID = @SubCategoryID

    IF (@@ERROR <> 0)
    BEGIN
        SET @ErrCode = 104
        SET @ErrMsg  = 'Update/Delete Remark of MainCaegory/SubCategory unsuccessfully'

        RETURN
    END

    -- Write log
    DECLARE @MainCategoryName NVARCHAR(100)
    SELECT  @MainCategoryName = SettingValue
    FROM bodb_CRM.dbo.crmSetting WITH (NOLOCK)
    WHERE SettingID = @MainCategoryID

    DECLARE @SubCategoryName  NVARCHAR(100)
    SELECT  @SubCategoryName = SettingValue
    FROM bodb_CRM.dbo.crmSetting WITH (NOLOCK)
    WHERE SettingID = @SubCategoryID

    DECLARE @OldValues XML
    SELECT  @OldValues = '<Acc_CRM_CategoryClassificationUpd>' +
                         '<Category>' + @MainCategoryName + '</Category>' +
                         '<Sub-Category>' + @SubCategoryName + '</Sub-Category>' +
                         '<Remark>' + ISNULL(@RemarkOldValue, '') + '</Remark>' +
                         '</Acc_CRM_CategoryClassificationUpd>'

    DECLARE @NewValues XML
    SELECT  @NewValues = '<Acc_CRM_CategoryClassificationUpd>' +
                         '<Category>' + @MainCategoryName + '</Category>' +
                         '<Sub-Category>' + @SubCategoryName + '</Sub-Category>' +
                         '<Remark>' + ISNULL(@RemarkNewValue, '') + '</Remark>' +
                         '</Acc_CRM_CategoryClassificationUpd>'

    DECLARE @ActionID INT
    IF (@ActionType = 1) BEGIN SET @ActionID = 312 END
    ELSE                 BEGIN SET @ActionID = 313 END

    EXEC bodb_CRM.dbo.WriteLog_UserLog_crmLogSetting @SettingID = @SubCategoryID,
                                                     @ParentID  = @MainCategoryID,
                                                     @UserID    = @UserID,
                                                     @ActionID  = @ActionID,
                                                     @IP        = @IP,
                                                     @NewValues = @NewValues,
                                                     @OldValues = @OldValues

END
GO