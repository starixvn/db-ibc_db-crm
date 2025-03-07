/*<info serverAlias="DBCRM-bodb_CRM" executers="dwrs2,wsv_nap" viewers="" isFunction="0"></info>*/

USE [bodb_CRM]
GO

ALTER PROCEDURE dbo.Acc_CRM_ReasonSettingSel
	@IsActive BIT = NULL
AS

/*
    Created: 20250305@Virgil
    DB: DBCRM-bodb_CRM
    Task: CRM - Message Notifications Center for Result Amendment - Add Reason [RedmineID: #219040]

	Revisions:
		20250305@Virgil: Initial SP [Redmine #219040]
*/

BEGIN
	SET NOCOUNT ON;

    SELECT SettingID, SettingValue
	FROM [dbo].[crmSetting] WITH(NOLOCK)
	WHERE SettingName = 'Reason'
		AND (@IsActive IS NULL OR IsActive = @IsActive)

END
GO
