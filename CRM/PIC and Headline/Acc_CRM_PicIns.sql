/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_PicIns]	
	@PicName				NVARCHAR(200),
	@PicType					INT,			
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
Task : CRM - PIC and Headlin -> PIC Management -> Insert
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200506@Malcolm: insert a new PIC [Redmine: #108739]
		- 20200723@Malcolm : change logs [RedmineId : #137144]
		- 20200921@Malcolm : New PIC shall be inserted in table crmRecipient[RedmineId : #130544] 
		- 20210731@Malcolm : Add pic type [RedmineId : #151509] 
	Param's Explanation:
	- @CommunicationTools:		
		<ROOT>
				<CommunicationTool SettingID = "" SettingValue = ""/>
		</ROOT>	
		
*/
BEGIN 
	SET NOCOUNT ON

	IF ISNULL(@CommunicationTools,'') = ''
		RETURN
	
	DECLARE @idoc INT, @CountryXML XML, @LanguageXML XML, @RoleXML XML, @PicXML XML, @RemarkXML XML, @PicTypeXML XML, @RecipientTypeId INT

	DECLARE  @NewValues NVARCHAR(MAX), @PicID INT = 0, @Username NVARCHAR(200)

	CREATE TABLE #input
	(	
		SettingID   	INT,
		SettingValue	NVARCHAR(200)
	)

	BEGIN TRY
		EXEC sp_xml_preparedocument @iDoc OUTPUT, @CommunicationTools
		 
		INSERT INTO #input (SettingID,
							SettingValue)

		SELECT				SettingID,
							SettingValue
		FROM OPENXML(@iDoc, '/ROOT/CommunicationTool',1) WITH (SettingID     INT,
												  SettingValue  NVARCHAR(200))
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

	IF EXISTS (SELECT 1 FROM dbo.crmPIC WITH(NOLOCK) WHERE Username = @PicName)
	BEGIN
		SELECT @ErrCode = 1007,  @ErrMsg = 'Name exists'
		RETURN
	END

	SELECT @Language = ISNULL(@Language,''), @Remark = ISNULL(@Remark,'')

	BEGIN TRY
		INSERT INTO dbo.crmPIC
		(
			Username, 
			Role,
			[PicType],
			Language,
			Country,
			IsActive,
			Remark
		)
		VALUES(	@PicName, @Role, @PicType, @Language, @Country, 1, @Remark)
		
		SET @PicID = SCOPE_IDENTITY();

		INSERT INTO dbo.crmPICCommunication 
		(
			PicID,
			CommunicationID,
			CommunicationValue
		)
		SELECT	@PicID,
				I.SettingID,
				I.SettingValue
		FROM #input i 
			
	END TRY
	BEGIN CATCH
		SELECT  @ErrCode = ERROR_NUMBER(),@ErrMsg = ERROR_MESSAGE()

		IF @PicID <> 0
		BEGIN
			DELETE dbo.crmPIC WITH(ROWLOCK, UPDLOCK)
			WHERE PicID = @PicID
		END
		RETURN
	END CATCH

	-- Insert Into crmRecipient Table 
	BEGIN TRY

		DECLARE @RecipientTypeName VARCHAR(200) = ''

		SELECT @RecipientTypeName = SettingValue FROM dbo.crmSetting WITH(NOLOCK) WHERE SettingID = @PicType

		IF @RecipientTypeName = 'Headline PIC'
			SET @RecipientTypeName = 'PIC of headline'

		SELECT @RecipientTypeId = RecipientTypeId FROM dbo.crmRecipientType WITH(NOLOCK) WHERE RecipientTypeName = @RecipientTypeName

		IF @RecipientTypeId IS NULL
		BEGIN
			SELECT @ErrCode = 100, @ErrMsg = 'Recipient type does not exist. Please check again!'
			DELETE dbo.crmPIC WITH(ROWLOCK, UPDLOCK)
			WHERE PicID = @PicID
			RETURN
		END

		INSERT INTO dbo.crmRecipient (RecipientTypeId, SourceId, DataSource)
		VALUES(@RecipientTypeId, @PicID, 'bodb_CRM.dbo.crmPIC')
	END TRY
	BEGIN CATCH
		SELECT  @ErrCode = ERROR_NUMBER(),@ErrMsg = ERROR_MESSAGE()
		DELETE dbo.crmPIC WITH(ROWLOCK, UPDLOCK)
		WHERE PicID = @PicID
		RETURN
	END CATCH
	
	--Write log
	SELECT @RoleXML = (
				SELECT SettingID AS '@Id', SettingValue AS '@Name' 
				FROM crmSetting WITH(NOLOCK) 
				WHERE SettingID = @Role
				FOR XML PATH('Role'))

	SELECT @PicTypeXML = (
				SELECT SettingID AS '@Id', SettingValue AS '@Name' 
				FROM crmSetting WITH(NOLOCK) 
				WHERE SettingID = @PicType
				FOR XML PATH('PicType'))

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
										1               AS '@Active',
										@PicTypeXML,
										@RoleXML,
										@CountryXML,
										@LanguageXML,								
										(
											 SELECT	i.SettingID	 AS '@Id', 
												    i.SettingValue AS '@Value',
													s.SettingValue AS '@Name'
											 FROM #input i
												INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON i.SettingID = s.SettingID
											 FOR XML PATH('CommunicationTool'),TYPE
										)
								FOR XML PATH('Acc_CRM_PicIns')) AS NVARCHAR(MAX))
    
	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @UserID,
			@CustID = @PicID,
			@ActionID = 901,
			@IP = @LoginIP,
			@NewValues = @NewValues
						
	DROP TABLE #input
END