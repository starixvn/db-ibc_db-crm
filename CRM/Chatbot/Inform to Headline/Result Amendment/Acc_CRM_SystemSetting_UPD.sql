/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_SystemSetting_Upd]
	@ServiceName VARCHAR(100)
	,@Setting XML

AS
/*
Created: 20210811@Malcolm
Task :  Update setting 
DB: DBCRM/bodb_CRM
Original:
	Revisions:
		- 20210811@Malcolm: Initialize SPs [Redmine: #151509]
	Param's Explanation:
		. @Setting
			<root>
				<r SettingName="1" Value=""/>
			</root>

		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @SettingTmp TABLE (SettingName VARCHAR(50), Value VARCHAR(MAX))

	INSERT INTO @SettingTmp (SettingName, Value)
	SELECT 
		t.c.value('@SettingName', 'VARCHAR(50)') AS SettingName
		,t.c.value('@Value', 'VARCHAR(MAX)') AS [Value]
	FROM @Setting.nodes('root/r') t(c)
	
	UPDATE s
		SET s.Value = t.Value
	FROM SystemSetting s WITH(ROWLOCK)
		INNER JOIN @SettingTmp t ON t.SettingName = s.SettingName
	WHERE s.ServiceName = @ServiceName AND t.Value <> ''

END
GO

