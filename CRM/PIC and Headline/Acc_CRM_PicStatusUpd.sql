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
	Param's Explanation:
	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @OldValues NVARCHAR(MAX) = '', @NewValues NVARCHAR(MAX) = '', @Old_IsActive BIT = 0, @PicName NVARCHAR(200) = '',@RemovedPICs NVARCHAR(MAX)

	SELECT @Old_IsActive = IsActive, @PicName =Username FROM dbo.crmPIC WITH(NOLOCK) WHERE PicID = @PicID

	SELECT @IsActive = ISNULL(@IsActive,0)

	IF @IsActive = 0
	BEGIN
		
		SELECT @RemovedPICs = '<ROOT><RemovedPIC HeadlineID = "0" CustID = "0"  PicID = "'+ CONVERT(VARCHAR(20),@PicID) +'"/></ROOT>'

		EXEC dbo.Acc_CRM_PICAssignmentDel	@RemovedPICs	= @RemovedPICs, 
											@InActivatedPIC = 1, 											
											@LoginIP		= @LoginIP,
											@UserID			= @UserID,
											@ErrCode		= @ErrCode OUTPUT, 
											@ErrMsg			= @ErrMsg OUTPUT
		IF @ErrCode <> 0
			RETURN	    
	END

	BEGIN TRY
		UPDATE t
		SET t.IsActive = @IsActive
		FROM dbo.crmPIC t
		WHERE t.PicID = @PicID
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
	END CATCH

	SELECT @OldValues = (SELECT @PicID AS '@CountryID', @PicName AS '@PicName' ,@Old_IsActive AS '@IsActive' FOR XML PATH('Acc_CRM_PICStatusUpd'))

	SELECT @NewValues = (SELECT @PicID AS '@CountryID', @PicName AS '@PicName' ,@IsActive AS '@IsActive' FOR XML PATH('Acc_CRM_PICStatusUpd'))

	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @UserID,
			@ActionID = 903,
			@IP = @LoginIP,
			@NewValues = @NewValues,
			@OldValues = @OldValues

	
END