/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_SystemSettingUpd] 
	@Settings VARCHAR(MAX)	
AS
/*
	Created: 20200418@@Johnson
	Task : get system setting for service auto feedback
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20200418@@Johnson: Initial sp [redmine:#130949]
	Param's Explanation:
		- @Settings = '<ROOT><r Name="JobStatus" Value="Completed" />
							<r Name="LastMsgID" Value="1000" />
					</ROOT>'
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @xml XML = CAST(@Settings as xml)
	
	DECLARE @tmpSetting TABLE (SettingName VARCHAR(50),Value VARCHAR(50))
	
	INSERT INTO @tmpSetting(SettingName,Value)
	SELECT t.c.value('@Name[1]','varchar(50)') SettingName,
		t.c.value('@Value[1]','varchar(50)') Value
	FROM @xml.nodes('/ROOT/r') t(c)
	
	
END	