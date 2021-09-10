/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="1"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_SystemSetting_Upd]
	@ServiceName VARCHAR(100)
	,@Settings XML
	,@Environment VARCHAR(50) = ''

AS
/*
Created: 20210811@Malcolm
Task :  Update setting 
DB: DBCRM/bodb_CRM
Original:
	Revisions:
		- 20210811@Malcolm: Initialize SPs [Redmine: #151509]
	Param's Explanation:
		. @Setting = <root>	
						<r>
							<SettingName>1</SettingName>
							<Value>2</Value>
						</r>
					</root>	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @IsSyncSettingsForUAT BIT

	SELECT @IsSyncSettingsForUAT = Value FROM SystemSetting WITH(NOLOCK) WHERE ServiceName = 'ChatBot - ResultAmendment' AND SettingName = 'IsSyncSettingsForUAT'

	DECLARE @SettingTmp TABLE (SettingName VARCHAR(50), Value VARCHAR(MAX))

	INSERT INTO @SettingTmp (SettingName, Value)
	SELECT t.c.value('(SettingName/text())[1]', 'VARCHAR(50)') AS SettingName
		  ,t.c.value('(Value/text())[1]', 'VARCHAR(MAX)') AS [Value]
	FROM @Settings.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@Settings = NULL))

	IF @IsSyncSettingsForUAT = 1 AND @Environment <> 'UAT'
	BEGIN
		INSERT INTO @SettingTmp (SettingName, [Value])
		SELECT s.SettingName + 'UAT', s.[Value]
		FROM @SettingTmp s
		WHERE s.SettingName <> 'JobStatus'
	END
	
	UPDATE s
		SET s.Value = t.Value
	FROM SystemSetting s WITH(ROWLOCK)
		INNER JOIN @SettingTmp t ON t.SettingName = s.SettingName
	WHERE s.ServiceName = @ServiceName AND ISNULL(t.Value, '') <> '' 

END
GO

