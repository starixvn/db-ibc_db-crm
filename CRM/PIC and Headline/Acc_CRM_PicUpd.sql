/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_PicUpd]
	@PicID					INT,
	@PicName				NVARCHAR(200),
	@PicType				INT,
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
Task : CRM - PIC and Headlin -> PIC Management -> Edit
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200506@Malcolm: Update information of PIC [Redmine: #108739]
		- 20200723@Malcolm : change logs [RedmineId : #137144]
		- 20200916@Malcolm : Update chat Type mapping [Redmine : #130544]
		- 20210731@Malcolm : Add pic type [RedmineId : #151509] 
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

	DECLARE	@NewValues NVARCHAR(MAX),@OldValues NVARCHAR(MAX), @CountryXML XML, @LanguageXML XML, @RoleXML XML, @PicTypeXML XML, @RecipienttypeId TINYINT, @RecipientTypeName VARCHAR(200) = ''
	
	DECLARE @CountryXML_Old XML, @LanguageXML_Old XML, @RoleXML_Old XML, @PicTypeXML_Old XML

	DECLARE @Role_Old INT, @PicType_Old INT, @Country_Old INT, @Language_Old VARCHAR(200), @Remark_Old NVARCHAR(1000), @PicName_Old NVARCHAR(200)

	DECLARE @Tmp TABLE (PicID INT, CommunicationID INT, CommunicationValue NVARCHAR(200))

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
			@PicType_Old	= PicType,
			@Remark_Old		= Remark,
			@PicName_Old	= Username,
			@Country_Old	= Country,
			@Language_Old	= Language			
	FROM dbo.crmPIC WITH(NOLOCK)
	WHERE PicID = @PicID

	IF EXISTS (SELECT 1 FROM dbo.crmSetting WITH(NOLOCK) WHERE SettingId = @PicType_Old AND SettingValue = 'Accounting PIC' AND SettingName = 'PicType' AND @PicType_Old <> @PicType)
	BEGIN
		IF EXISTS (
			SELECT  1
			FROM crmConversationGroupRecipient cr WITH(NOLOCK)
				INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId = cr.RecipientId
			WHERE r.DataSource = 'bodb_CRM.dbo.crmPIC' AND r.SourceId = @PicId
		)
		BEGIN
			SELECT @ErrCode = 1009, @ErrMsg = 'Cannot change PIC Type since the Accounting PIC already created Chat Type Mapping'
			RETURN
		END
		 
	END

	--Update recipient type
	SELECT @RecipientTypeName = SettingValue FROM dbo.crmSetting WITH(NOLOCK) WHERE SettingID = @PicType
	IF @RecipientTypeName = 'Headline PIC'
		SET @RecipientTypeName = 'PIC of headline'

	SELECT @RecipientTypeId = RecipientTypeId FROM dbo.crmRecipientType WITH(NOLOCK) WHERE RecipientTypeName = @RecipientTypeName

	IF @RecipientTypeId IS NULL
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'Recipient type does not exist. Please check again!'
		RETURN
	END

	UPDATE r
		SET r.RecipientTypeId = @RecipientTypeId
	FROM dbo.crmRecipient r WITH(ROWLOCK)
		INNER JOIN dbo.crmPic p WITH(NOLOCK) ON p.PicId = r.SourceId 
	WHERE r.DataSource = 'bodb_CRM.dbo.crmPIC' AND p.PicId = @PicID

	INSERT INTO @Tmp (PicID, CommunicationID, CommunicationValue)
	SELECT pc.PicID, pc.CommunicationID, pc.CommunicationValue
	FROM dbo.crmPICCommunication pc WITH(NOLOCK)
	WHERE pc.PicID = @PicID

	SELECT @RoleXML_Old = (
				SELECT SettingID AS '@Id', SettingValue AS '@Name' 
				FROM crmSetting WITH(NOLOCK) 
				WHERE SettingID = @Role_Old
				FOR XML PATH('Role'))

	SELECT @PicTypeXML_Old = (
				SELECT SettingID AS '@Id', SettingValue AS '@Name' 
				FROM dbo.crmSetting WITH(NOLOCK) 
				WHERE SettingID = @PicType_Old
				FOR XML PATH('PicType'))

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
										@PicTypeXML_Old,
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
			P.Country   = @Country,
			P.PicType   = @PicType
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

	-- Update for Chat Type Mapping
	BEGIN
		DECLARE @SettingLetstalkId INT
		SELECT  @SettingLetstalkId = SettingId
		FROM dbo.crmSetting WITH(NOLOCK)
		WHERE SettingName = 'PICCommunicationTool' AND SettingValue = 'Letstalk'

		DECLARE @Used__Letstalk TABLE (ConversationGroupId SMALLINT, LetstalkId VARCHAR(200), IsActive BIT)
		DECLARE @New__Letstalk TABLE (LetstalkId VARCHAR(200))

		INSERT INTO @New__Letstalk (LetstalkId)
		SELECT DISTINCT LTRIM(RTRIM(f.val))
		FROM #input i
			CROSS APPLY dbo.f_CRM_strSplit(i.SettingValue, ',') f
		WHERE i.SettingId = @SettingLetstalkId AND ISNULL(LTRIM(RTRIM(f.val)), '') <> ''
	
		INSERT INTO @Used__Letstalk (ConversationGroupId, LetstalkId, IsActive)
		SELECT DISTINCT cg.ConversationGroupId, cg.ConversationId, cg.IsActive
		FROM dbo.crmConversationGroup cg WITH(NOLOCK)
			INNER JOIN dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) ON cgr.ConversationGroupId = cg.ConversationGroupId
			INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId = cgr.RecipientId
		WHERE cg.ChatTypeId = 2 AND r.SourceId = @PicId AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
			AND ISNULL(cg.ConversationId, '') <> ''

		DELETE u
		FROM @Used__Letstalk u
			INNER JOIN @New__Letstalk n ON u.LetstalkId = n.LetstalkId

		DECLARE @ConversationGroupId SMALLINT, @IsActive BIT
		WHILE EXISTS (SELECT 1 FROM @Used__Letstalk)
		BEGIN
			SELECT TOP 1 @ConversationGroupId = ConversationGroupId, @IsActive = IsActive FROM @Used__Letstalk

			IF @IsActive = 1
			BEGIN
				EXEC dbo.Acc_CRM_ChatBot_ChatTypeMappingStatus_Upd
					@ConversationGroupId = @ConversationGroupId
					,@IsActive	= 0
					,@UserId = @UserId
					,@ErrCode = @ErrCode OUTPUT
					,@ErrMsg = @ErrMsg OUTPUT
					,@LoginIP = @LoginIP

				IF @ErrCode <> 0
				BEGIN
					DELETE dbo.crmPICCommunication WITH(ROWLOCK, UPDLOCK)
					WHERE PicID = @PicID

					INSERT INTO dbo.crmPICCommunication (PicID, CommunicationID, CommunicationValue)
					SELECT PicID, CommunicationID, CommunicationValue
					FROM @Tmp

					UPDATE dbo.crmPIC WITH(ROWLOCK, UPDLOCK)
						SET Username = @PicName_Old
							,Role = @Role_Old
							,Language = @Language_Old
							,Country = @Country_Old
							,Remark = @Remark_Old
					WHERE PicID = @PicID

					RETURN
				END
			END

			EXEC dbo.Acc_CRM_ChatBot_ChatTypeMapping_Upd
				@ConversationGroupId = @ConversationGroupId
				,@BotId = NULL
				,@ConversationGroupName	= ''
				,@RecipientTypeId  = NULL
				,@HeadlineIds = NULL
				,@RecipientIds	= NULL
				,@LetstalkID = ''
				,@LanguageId = NULL
				,@Remark = NULL
				,@UserId = @UserId
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT
				,@LoginIP = @LoginIP
				,@IsAuto = 1

			IF @ErrCode <> 0
			BEGIN
				IF @IsActive = 1
				BEGIN
					UPDATE dbo.crmConversationGroup WITH(ROWLOCK)
						SET IsActive = 1
					WHERE ConversationGroupId = @ConversationGroupId
				END

				DELETE dbo.crmPICCommunication WITH(ROWLOCK, UPDLOCK)
				WHERE PicID = @PicID

				INSERT INTO dbo.crmPICCommunication (PicID, CommunicationID, CommunicationValue)
				SELECT PicID, CommunicationID, CommunicationValue
				FROM @Tmp

				UPDATE dbo.crmPIC WITH(ROWLOCK, UPDLOCK)
					SET Username = @PicName_Old
						,Role = @Role_Old
						,Language = @Language_Old
						,Country = @Country_Old
						,Remark = @Remark_Old
				WHERE PicID = @PicID

				RETURN
			END

			DELETE @Used__Letstalk WHERE ConversationGroupId = @ConversationGroupId
		END
	END

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
										@RoleXML,
										@PicTypeXML,
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