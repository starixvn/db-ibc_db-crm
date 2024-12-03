/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_SystemSetting_Sel]
	@ServiceName VARCHAR(100) = 'ChatBot - AbnormalBets'
	,@Environment VARCHAR(50) = ''
AS

/*
	Created: 20200811@Percy
	DB: DBCRM-bodb_CRM
	Task: CRM - ChatBot - Get Setting

	Revisions:
		- 20200811@Percy: Initialize SP [RedmineID: #130544]
		- 20201104@Malcolm: Add @@ServiceName to support get setting by Service [RedmineId: #144265]
		- 20210801@Malcolm: Get SubmitDate, Seq [RedmineId: #151509]
		- 20210801@Malcolm: Get settings automatically [RedmineId: #181906]
*/

BEGIN
	SET NOCOUNT ON

	SELECT @Environment = ISNULL(@Environment, '')

	CREATE TABLE #Setting (SettingName VARCHAR(50), Value VARCHAR(MAX), DataTypeSql VARCHAR(50))

	;WITH CTE_Setting AS 
	(
		SELECT SettingName, Value, DataType
		FROM dbo.SystemSetting WITH(NOLOCK)
		WHERE ServiceName = @ServiceName
			AND SettingName NOT IN ('NotificationTemplate', 'IsSyncSettingsForUAT')
	)
	,CTE_SettingUAT AS 
	(
		SELECT SettingName, Value, DataType FROM CTE_Setting WHERE SettingName LIKE '%UAT'
	),CTE_SettingPro AS 
	(
		SELECT e.SettingName, e.Value, DataType FROM CTE_Setting e WHERE e.SettingName NOT LIKE '%UAT' 
	),CTE_DataTypeMapping AS 
	(
		SELECT n.DatatypeSetting, n.DataTypeSql
		FROM (
			VALUES 
				('DateTime', 'DATETIME2(7)')
				,('String', 'VARCHAR(50)')
				,('Int32', 'INT')
				,('Boolean', 'BIT')
				,('XML', 'XML')
		) AS n (DatatypeSetting, DataTypeSql)
	)
	INSERT INTO #Setting (SettingName, DataTypeSql, Value)
	SELECT p.SettingName, d.DataTypeSql, CASE WHEN @Environment <> 'UAT' THEN p.Value ELSE ISNULL(u.Value, p.Value) END AS [Value]
	FROM CTE_SettingPro p
		INNER JOIN CTE_DataTypeMapping d ON d.DatatypeSetting = P.DataType
		LEFT JOIN CTE_SettingUAT u ON SUBSTRING(u.SettingName, 1, LEN(u.SettingName) - 3) = p.SettingName

	DECLARE @sql NVARCHAR(MAX) = ''

	SELECT @sql = 
		   'SELECT ' + STRING_AGG('CONVERT(' + DataTypeSql + ',' + SettingName + ') AS ' + SettingName, ',') + ' '+
		   'FROM 
			(	
				SELECT SettingName, Value
				FROM #Setting
			) AS s
			PIVOT 
			(
				MAX(Value)
				FOR SettingName IN (' + STRING_AGG(SettingName, ',') + ')' + 
		    ') AS p'
	FROM #Setting 

	EXEC sp_executesql  @sql

	DROP TABLE #Setting

END
GO