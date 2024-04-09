/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_NewManualFeedback_CheckFeedbackIDIsNew @FeedbackID INT
AS

/*
	Created: Ned.Le
	Date:    20240321
	Task:    Check if the FeedbackID is New or Old
	DB:      DBCRM.bodb_CRM

	Revisions:
        20240321@Ned.Le: CRM - Manage Headline/PIC/Staff authority and Company services (#193385)

	Param's Explanation:
        @FeedbackID: FeedbackID to check

    Example:
        EXEC bodb_CRM.dbo.Acc_CRM_NewManualFeedback_CheckFeedbackIDIsNew @FeedbackID=596230
*/

BEGIN

	SET NOCOUNT ON

    -- Get value from setting that help to determine one feedback is new or old
    DECLARE @FeebackID_SeparateNewOld INT
    SELECT  @FeebackID_SeparateNewOld = CAST(Value AS INT)
    FROM bodb_CRM.dbo.SystemSetting WITH (NOLOCK)
    WHERE ServiceName = 'Internal Setting'
          AND SettingName = 'FeebackID_SeparateNewOld'

    -- If FeedbackID over the setting value, it is new
    IF (@FeedbackID > @FeebackID_SeparateNewOld)
    BEGIN
        SELECT 1
    END
    -- Otherwise, it is old
    ELSE
    BEGIN
        SELECT 0
    END

END
GO