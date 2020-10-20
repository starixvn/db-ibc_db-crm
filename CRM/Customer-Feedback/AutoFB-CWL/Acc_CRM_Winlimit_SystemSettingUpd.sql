/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Winlimit_SystemSettingUpd] 
	@Settings 	VARCHAR(MAX),
	@ServiceName VARCHAR(20) = 'WinLimitFB'
AS
/*
	Created: 20201020@@Johnson
	Task : get system setting for winlimit service auto feedback
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20201020@Johnson: Initial sp [redmine:#142194]
	Param's Explanation:
		- @Settings = '<ROOT><r Name="JobStatus" Value="Completed" />
							<r Name="LastLogID" Value="1000" />
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
	
	UPDATE s
	SET s.Value = t.value
	FROM SystemSetting s WITH(UPDLOCK,ROWLOCK)
		INNER JOIN @tmpSetting t ON s.SettingName = t.SettingName
	WHERE ServiceName = @ServiceName
		
		
END	