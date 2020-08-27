/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_PICStatusUpd]
	@PicID		INT,
	@IsActive	BIT,
	@LoginIP	VARCHAR(20)='',
	@UserID		INT,
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		NVARCHAR(4000) = '' OUTPUT
AS
/*
Created: 20200506@Malcolm
Task :  CRM - Staff/Boss Management of headline
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200506@Malcolm: Update status of PIC [Redmine: #108739]
		- 20200723@Malcolm : change logs [RedmineId : #137144]
	Param's Explanation:
	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @OldValues NVARCHAR(MAX) = '', @NewValues NVARCHAR(MAX) = '', @Old_IsActive BIT = 0, @PicName NVARCHAR(200) = '',
			@RemovedPICs NVARCHAR(MAX), @OldDirectAccounts XML, @OldHeadlines XML  

	SELECT @Old_IsActive = IsActive, @PicName =Username FROM dbo.crmPIC WITH(NOLOCK) WHERE PicID = @PicID

	DECLARE @TmpLog TABLE (HeadlineID INT, CustID INT, PicID INT, Type INT)

	SELECT @IsActive = ISNULL(@IsActive,0)

	IF @IsActive = 0
	BEGIN
		SELECT	@OldDirectAccounts  =   (SELECT c.custid AS '@Id', c.username AS '@Name'
										 FROM dbo.crmPicManagement m WITH(NOLOCK)
											 INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON m.CustID = c.custid
										 WHERE PicID = @PicID
										 FOR XML PATH('DirectAccount'))

		SELECT @OldHeadlines =	(SELECT c.custid AS '@Id', c.username AS '@Name'
								FROM dbo.crmPICDefault d WITH(NOLOCK)
									 INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON d.HeadlineID = c.custid
								WHERE d.PicID = @PicID
								FOR XML PATH('Headline'))
		BEGIN TRY
			DELETE t
			OUTPUT deleted.HeadlineID, deleted.CustID, deleted.PicID, 1
				INTO @TmpLog (HeadlineID, CustID, PicID, Type)
			FROM dbo.crmPicManagement t WITH(ROWLOCK, UPDLOCK)
			WHERE t.PicID = @PicID

			DELETE t
			OUTPUT deleted.HeadlineID, deleted.PicID, 2
				INTO @TmpLog(HeadlineID, PicID, Type)
			FROM dbo.crmPICDefault t WITH(ROWLOCK, UPDLOCK)		
			WHERE PicID = @PicID

			DELETE t
			FROM dbo.crmPICHeadline t WITH(ROWLOCK, UPDLOCK)
			WHERE PicID = @PicID

		END TRY
		BEGIN CATCH
			SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()

			IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 1)
			BEGIN
				INSERT INTO dbo.crmPicManagement (HeadlineID, CustID, PicID)
				SELECT HeadlineID ,CustID, PicID
				FROM @TmpLog
				WHERE Type = 1
			END

			IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 2)
			BEGIN
				INSERT INTO dbo.crmPICDefault (HeadlineID, PicID)
				SELECT HeadlineID, PicID
				FROM @TmpLog
				WHERE Type = 2
			END

			RETURN
		END CATCH
	END 

	BEGIN TRY
		UPDATE t
		SET t.IsActive = @IsActive
		FROM dbo.crmPIC t WITH(ROWLOCK)
		WHERE t.PicID = @PicID
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	SELECT @OldValues = CAST((SELECT @Old_IsActive AS '@IsActive', @OldDirectAccounts, @OldHeadlines FOR XML PATH('Acc_CRM_PICStatusUpd')) AS NVARCHAR(MAX))

	SELECT @NewValues = CAST((SELECT @IsActive AS '@IsActive' FOR XML PATH('Acc_CRM_PICStatusUpd')) AS NVARCHAR(MAX))

	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @UserID,
			@CustID = @PicID,
			@ActionID = 903,
			@IP = @LoginIP,
			@NewValues = @NewValues,
			@OldValues = @OldValues

	
END