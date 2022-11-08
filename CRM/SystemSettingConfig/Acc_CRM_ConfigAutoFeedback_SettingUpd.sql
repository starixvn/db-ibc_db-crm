/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ConfigAutoFeedback_SettingUpd] 
	  @UpdateConfig NVARCHAR(MAX)
	, @ErrCode		INT				= 0		OUTPUT	
	, @ErrMsg		NVARCHAR(200)	= ''	OUTPUT
AS
/*
	Created: Winfred
	Task : Update system setting for all service
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20221028@Winfred: Update system setting config for all service [redmine:#158258]
	
	Parameter's Explanation:
		- @UpdateConfig:
			<ROOT>
					<R
						ID="439"
						SETTING="JobStatus"
						VALUE="Completed"
						SERVICENAME="AutoFB"
					/>
			</ROOT>
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @xml XML, @iDoc INT,  @Threshold INT, @NumProduct INT = 0
	SELECT	@ErrCode = 0, @ErrMsg = ''
	CREATE TABLE #SettingName(ID INT,SettingName VARCHAR(50),Value VARCHAR(MAX),ServiceName VARCHAR(100))

	BEGIN TRY
		--Parse XML
		EXECUTE	sp_xml_preparedocument @iDoc OUTPUT, @UpdateConfig

		INSERT INTO #SettingName (ID, SettingName, Value, ServiceName)
		SELECT	ox.ID, ox.SettingName, ox.Value, ox.ServiceName
		FROM OPENXML (@iDoc, '/ROOT/R', 1) 
		WITH (
			ID		INT
		,	SettingName	VARCHAR(50)
		,	Value		VARCHAR(MAX)
		,	ServiceName	VARCHAR(100)
		) AS ox;

		EXECUTE sp_xml_removedocument @iDoc;
	END TRY
	BEGIN CATCH
		SET @ErrCode = 100
		SET @ErrMsg = N'Unable to process update due to invalid parameters, please try again.'
		RETURN
	END CATCH;

	IF EXISTS (SELECT TOP 1 1 FROM #SettingName a
				WHERE NOT EXISTS (SELECT 1 FROM SystemSetting WITH(NOLOCK) WHERE ID = a.ID))
	BEGIN
		SET @ErrCode = 101
		SET @ErrMsg = N'Not exists ID.'
		RETURN
	END

	UPDATE S
	SET S.ServiceName = b.ServiceName
		, S.SettingName = b.SettingName
		, S.Value = b.Value
	FROM SystemSetting S WITH(UPDLOCK,ROWLOCK)
		INNER JOIN #SettingName b ON S.ID  = b.ID
	
	DROP TABLE #SettingName
END