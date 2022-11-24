/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_ConfigAutoFeedback_SettingUpd] 
	  @UpdateConfig NVARCHAR(MAX)
	, @UserID				INT
	, @IP					VARCHAR(15)
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
	CREATE TABLE #SettingNameOld(ID INT,SettingName VARCHAR(50),Value VARCHAR(MAX),ServiceName VARCHAR(100))

	BEGIN TRY
		--Parse XML
		EXECUTE	sp_xml_preparedocument @iDoc OUTPUT, @UpdateConfig

		INSERT INTO #SettingName (ID, SettingName, Value, ServiceName)
		SELECT	ox.ID, ox.SETTING AS SettingName, ox.VALUE AS Value, ox.SERVICENAME AS ServiceName 
		FROM OPENXML (@iDoc, '/ROOT/R', 1) 
		WITH (
			ID		INT
			, SETTING VARCHAR(50)  
			, VALUE  VARCHAR(MAX)  
			, SERVICENAME VARCHAR(100)  
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

	INSERT INTO #SettingNameOld(ID, SettingName, Value, ServiceName)
	SELECT s.ID, s.SettingName, b.Value, s.ServiceName 
	FROM #SettingName s
	INNER JOIN SystemSetting b ON S.ID  = b.ID

	UPDATE S
	SET S.ServiceName = b.ServiceName
		, S.SettingName = b.SettingName
		, S.Value = b.Value
	FROM SystemSetting S WITH(UPDLOCK,ROWLOCK)
		INNER JOIN #SettingName b ON S.ID  = b.ID
	
	-- write log  
	 DECLARE @LogElement XML , @LogElementOld XML , @UpdateConfigOld NVARCHAR(MAX), @UpdateConfigNew NVARCHAR(MAX)
	
	SELECT @UpdateConfigOld =	CAST((SELECT ID AS '@ID',
									 SettingName AS '@SETTING',
									 VALUE AS '@VALUE',
									 SERVICENAME AS '@SERVICENAME'
							FROM #SettingNameOld t
							FOR XML PATH('UpdateConfig'))--, ROOT('UpdateConfig')
						AS NVARCHAR(MAX))
	
	SELECT @UpdateConfigNew = REPLACE(REPLACE(REPLACE(REPLACE(@UpdateConfig, '<ROOT>', ''),'</ROOT>',''),'<R','<UpdateConfig'),'</R','</UpdateConfig')

	SELECT @LogElementOld =       
		 '<Acc_CRM_ConfigAutoFeedback_SettingUpd>' + --SP Name  
		  + ISNULL(@UpdateConfigOld,'')	+ 
		  '<UserID>' + ISNULL(CONVERT(VARCHAR(10),@UserID),'')	+ '</UserID>' +  
		  '<IP>' + ISNULL(@IP,'')								+ '</IP>' +  	
		 '</Acc_CRM_ConfigAutoFeedback_SettingUpd>'

	 SELECT @LogElement =       
		 '<Acc_CRM_ConfigAutoFeedback_SettingUpd>' + --SP Name  
		  + ISNULL(@UpdateConfigNew,'')	+
		  '<UserID>' + ISNULL(CONVERT(VARCHAR(10),@UserID),'')	+ '</UserID>' +  
		  '<IP>' + ISNULL(@IP,'')								+ '</IP>' +  	
		 '</Acc_CRM_ConfigAutoFeedback_SettingUpd>'  
      
  	 EXEC [dbo].[WriteLog_UserLog_crmLogSetting]  
		 @SettingID = 0,   
		 @ParentID = 0,   
		 @UserID = @UserID,   
		 @ActionID = 311,   
		 @IP = @IP,   
		 @NewValues = @LogElement ,
		 @OldValues = @LogElementOld

	DROP TABLE #SettingName, #SettingNameOld
END