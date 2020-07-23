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
		- 20200723@Malcolm : change log [RedmineId : #137144]
	Param's Explanation:
	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @OldValues NVARCHAR(MAX) = '', @NewValues NVARCHAR(MAX) = '', @Old_IsActive BIT = 0, @PicName NVARCHAR(200) = '',@RemovedPICs NVARCHAR(MAX)


	SELECT @Old_IsActive = IsActive, @PicName =Username FROM dbo.crmPIC WITH(NOLOCK) WHERE PicID = @PicID

	DECLARE @TmpLog TABLE (CustID INT, PicID INT)

	SELECT @IsActive = ISNULL(@IsActive,0)

	IF @IsActive = 0
	BEGIN
		SELECT	@OldValues  =  (SELECT c.custid AS CustID, c.username AS UserName
								FROM dbo.crmPicManagement m WITH(NOLOCK)
									INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON m.CustID = c.custid
								WHERE PicID = @PicID
								FOR XML PATH('DirectAccount'))
		BEGIN TRY
			DELETE t
			OUTPUT deleted.CustID, deleted.PicID
				INTO @TmpLog (CustID, PicID)
			FROM dbo.crmPicManagement t WITH(ROWLOCK, UPDLOCK)
			WHERE t.PicID = @PicID

			DELETE t
			FROM dbo.crmPICHeadline t WITH(ROWLOCK, UPDLOCK)
			WHERE PicID = @PicID
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()

			IF EXISTS(SELECT 1 FROM @TmpLog)
			BEGIN
				INSERT INTO dbo.crmPicManagement (CustID, PicID)
				SELECT CustID, PicID
				FROM @TmpLog
			END

			RETURN
		END CATCH
	END 

	BEGIN TRY
		UPDATE t
		SET t.IsActive = @IsActive
		FROM dbo.crmPIC t
		WHERE t.PicID = @PicID
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	SELECT @OldValues = (SELECT @Old_IsActive AS '@IsActive', @OldValues FOR XML PATH('Acc_CRM_PICStatusUpd'))

	SELECT @NewValues = (SELECT @IsActive AS '@IsActive' FOR XML PATH('Acc_CRM_PICStatusUpd'))

	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @UserID,
			@CustID = @PicID,
			@ActionID = 903,
			@IP = @LoginIP,
			@NewValues = @NewValues,
			@OldValues = @OldValues

	
END