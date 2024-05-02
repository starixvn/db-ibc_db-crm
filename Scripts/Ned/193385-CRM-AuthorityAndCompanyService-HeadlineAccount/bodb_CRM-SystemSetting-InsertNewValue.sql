/*<info serverAlias="DBCRM-bodb_CRM"></info>*/

/*
Created: 20240220@Ned.Le
DB: DBCRM.bodb_CRM
Task: Insert new value to table SystemSetting
*/

USE bodb_CRM
GO

DECLARE @MAX_FeedbackID INT
SELECT  @MAX_FeedbackID = MAX(FeedbackID) FROM bodb_CRM.dbo.crmFeedback WITH (NOLOCK)

UPDATE s
SET s.Value = CAST(@MAX_FeedbackID AS VARCHAR(MAX))
FROM bodb_CRM.dbo.SystemSetting s WITH (UPDLOCK, TABLOCK)
WHERE ServiceName = 'Internal Setting'
      AND SettingName = 'FeebackID_SeparateNewOld'

IF (@@ROWCOUNT = 0)
BEGIN
    INSERT INTO bodb_CRM.dbo.SystemSetting (
        SettingName,
        Value,
        ServiceName,
        DataType
    )
    SELECT 'FeebackID_SeparateNewOld'            AS SettingName,
           CAST(@MAX_FeedbackID AS VARCHAR(MAX)) AS Value,
           'Internal Setting'                    AS ServiceName,
           'Int32'                               AS DataType
END
GO