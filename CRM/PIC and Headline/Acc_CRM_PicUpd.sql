/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_PicUpd]
	@PicID					INT,
	@PicName				NVARCHAR(200),
	@Role					INT,
	@Remark					NVARCHAR(1000),
	@Language				VARCHAR(200),
	@Country                INT,
	@CommunicationTools	    NVARCHAR(MAX),
	@LoginIP				VARCHAR(20)='',
	@ErrCode				INT = 0 OUTPUT,
	@ErrMsg					NVARCHAR(4000) = '' OUTPUT,
	@UserID					INT
AS
/*
Created: 20200506@Malcolm
Task :  CRM - Staff/Boss Management of headline
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200506@Malcolm: Update information of PIC [Redmine: #108739]
		- 20200723@Malcolm : change logs [RedmineId : #137144]
	Param's Explanation:
	- @CommunicationTools:		
		<ROOT>
				<CommunicationTool SettingID = "" SettingValue = "" 
				/>
		</ROOT>	
		
*/
BEGIN
	SET NOCOUNT ON

	IF ISNULL(@CommunicationTools,'') = ''
		RETURN
	
	DECLARE @idoc INT

	DECLARE	@NewValues NVARCHAR(MAX),@OldValues NVARCHAR(MAX), @CountryXML XML, @LanguageXML XML,@RoleXML XML
	
	DECLARE @CountryXML_Old XML, @LanguageXML_Old XML, @RoleXML_Old XML

	DECLARE @Role_Old INT, @Country_Old INT, @Language_Old VARCHAR(200), @Remark_Old NVARCHAR(1000), @PicName_Old NVARCHAR(200)

	CREATE TABLE #input
	(	
		SettingID		INT,
		SettingValue	NVARCHAR(200)
	)

	BEGIN TRY
		EXEC sp_xml_preparedocument @iDoc OUTPUT, @CommunicationTools
		 
		INSERT INTO #input (SettingID,
							SettingValue)

		SELECT				SettingID,
							SettingValue
		FROM OPENXML(@iDoc, '/ROOT/CommunicationTool',1) WITH (SettingID		INT,
												  SettingValue	NVARCHAR(200))
		EXEC sp_xml_removedocument @iDoc
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH


	IF @PicName = ''
	BEGIN
		SELECT @ErrCode = 1007, @ErrMsg = 'Name is null'
		RETURN
	END

	IF EXISTS (SELECT 1 FROM dbo.crmPIC WITH(NOLOCK) WHERE Username = @PicName AND PicID <> @PicID)
	BEGIN
		SELECT @ErrCode = 1008, @ErrMsg = 'Name exists'
		RETURN
	END

	SELECT @Remark  = ISNULL(@Remark,''), @Language  = ISNULL(@Language,'')

	SELECT	@Role_Old		= Role,
			@Remark_Old		= Remark,
			@PicName_Old	= Username,
			@Country_Old	= Country,
			@Language_Old	= Language			
	FROM crmPIC
	WHERE PicID = @PicID


	SELECT @RoleXML_Old = (
				SELECT SettingID AS '@Id', SettingValue AS '@Name' 
				FROM crmSetting WITH(NOLOCK) 
				WHERE SettingID = @Role_Old
				FOR XML PATH('Role'))

	SELECT @CountryXML_Old = (
				SELECT CountryID AS '@Id', CountryName AS '@Name' 
				FROM crmCountry WITH(NOLOCK) 
				WHERE CountryID = @Country_Old
				FOR XML PATH('Country'))

	SELECT @LanguageXML_Old = (
				SELECT SettingID AS '@Id', SettingValue AS '@Name' 
				FROM crmSetting WITH(NOLOCK) 
				WHERE SettingID IN (SELECT Val FROM bodb02.dbo.strSplit(@Language_Old,','))
				FOR XML PATH('Language'))

	SELECT @OldValues =	CAST((SELECT	@PicName_Old    AS '@PicName',
										@Remark_Old	  	AS '@Remark',
										@RoleXML_Old,
										@CountryXML_Old,
										@LanguageXML_Old,
										(
											SELECT	CommunicationID		AS '@Id', 
													CommunicationValue	AS '@Value',
													s.SettingValue      AS '@Name'
											FROM  dbo.crmPICCommunication c WITH(NOLOCK)
												INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON c.CommunicationID = s.SettingID
											WHERE c.PicID = @PicID
											FOR XML PATH('CommunicationTool'),TYPE
										)
								FOR XML PATH('Acc_CRM_PicUpd')) AS NVARCHAR(MAX))

	BEGIN TRY
		UPDATE p
		SET p.Username	= @PicName,
			p.Role		= @Role,
			p.Remark	= @Remark,
			P.Language  = @Language,
			P.Country   = @Country
		FROM dbo.crmPIC AS p WITH(ROWLOCK)
		WHERE p.PicID = @PicID;
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH	

	BEGIN TRY		
		;MERGE dbo.crmPICCommunication AS TARGET
			USING #input AS SOURCE
				ON (TARGET.PicID = @PicID AND TARGET.CommunicationID = SOURCE.SettingID)
		WHEN MATCHED THEN 
			UPDATE SET TARGET.CommunicationValue = SOURCE.SettingValue
		WHEN NOT MATCHED  BY TARGET THEN 
			INSERT (PicID, CommunicationID, CommunicationValue) 
			VALUES(@PicID, SOURCE.SettingID, SOURCE.SettingValue)
		WHEN NOT MATCHED  BY SOURCE AND TARGET.PicID = @PicID 
			THEN DELETE;
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH	

	SELECT @RoleXML = (
				SELECT SettingID AS '@Id', SettingValue AS '@Name' 
				FROM crmSetting WITH(NOLOCK) 
				WHERE SettingID = @Role
				FOR XML PATH('Role'))

	SELECT @CountryXML = (
				SELECT CountryID AS '@Id', CountryName AS '@Name' 
				FROM crmCountry WITH(NOLOCK) 
				WHERE CountryID = @Country
				FOR XML PATH('Country'))

	SELECT @LanguageXML = (
				SELECT SettingID AS '@Id', SettingValue AS '@Name' 
				FROM crmSetting WITH(NOLOCK) 
				WHERE SettingID IN (SELECT Val FROM bodb02.dbo.strSplit(@Language,','))
				FOR XML PATH('Language'))

	SELECT @NewValues =	CAST((SELECT	@PicName        AS '@PicName',
										@Remark	  		AS '@Remark',
										@RoleXML,
										@CountryXML,
										@LanguageXML,								
										(
											 SELECT	i.SettingID	   AS '@Id', 
												    i.SettingValue AS '@Value',
													s.SettingValue AS '@Name'
											 FROM #input i
												INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingID = i.SettingID
											 FOR XML PATH('CommunicationTool'),TYPE
										)
								FOR XML PATH('Acc_CRM_PicUpd')) AS NVARCHAR(MAX))
	

	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @UserID,
			@CustId = @PicID,
			@ActionID = 902,
			@IP = @LoginIP,
			@NewValues = @NewValues,
			@OldValues = @OldValues

	DROP TABLE #input
END