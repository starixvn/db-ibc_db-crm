/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,bodbExtAccNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_HeadlineUpd]
	@CustID			INT = 0,
	@HeadlineID_Old INT = 0,
	@Username		VARCHAR(30) = '',
	@Case			INT = 0,
	@LoginIP		VARCHAR(20)='',
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT,
	@UserID			INT
AS
/*
Created: 20200717@Malcolm
Task : 
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200717@Malcolm:  Integrate Credit Term & Staff/Boss Management  [Redmine: #137144]
	Param's Explanation:
		@Case = 0 : No change
		      = 1 : remove PICs which manage this Customer AND assign PIC (default PICs of new headline) to this customer
			  = 2 :
			  = 3 :
			  = 4 :
				
*/
BEGIN 
	SET NOCOUNT ON

	DECLARE @XML XML = NULL, @NewValues	XML = NULL, @OldValues	XML = NULL, @HeadlineName_Old VARCHAR(30)
			
	SELECT @CustID = ISNULL(@CustID,0), @Username = ISNULL(@Username,'')

	IF @CustID = 0
		SELECT @CustID = CustId FROM bodb02.dbo.Customer WITH(NOLOCK) WHERE username = @Username
	ELSE 
		SELECT @Username = UserName FROM bodb02.dbo.Customer WITH(NOLOCK) WHERE custid = @CustID

	IF @Case IN (3,4)
	BEGIN
	
		UPDATE dbo.crmPICHeadline WITH(ROWLOCK, UPDLOCK)
		SET HeadlineID = @CustID
		WHERE HeadlineID = @HeadlineID_Old

		UPDATE dbo.crmPICDefault WITH(ROWLOCK, UPDLOCK)
		SET HeadlineID = @CustID
		WHERE HeadlineID = @HeadlineID_Old

	END

	IF @Case IN (1,4)
	BEGIN	

		DELETE dbo.crmPicManagement
		WHERE CustID = @CustID

		INSERT INTO dbo.crmPicManagement
		(
			CustID,
			PicID
		)
		SELECT 
			@CustID, 
			PicID
		FROM dbo.crmPICDefault WITH(NOLOCK)
		WHERE (@Case = 1 AND HeadlineID = @HeadlineID_Old)
			OR (@Case = 4 AND HeadlineID = @CustID)
	END

	IF @Case = 2
	BEGIN	

		DELETE dbo.crmPicManagement
		WHERE CustID = @CustID

		DELETE dbo.crmPICHeadline
		WHERE HeadlineID = @CustID
		
		DELETE dbo.crmPICDefault
		WHERE HeadlineID = @CustID		
	END

	-- Write log

    IF @Case IN (3, 4, 2)
	BEGIN
		SELECT @XML	=  (SELECT p.PicID AS 'PicID', P.Username AS 'PicName', s.SettingValue AS 'RoleName'
					FROM dbo.crmPICHeadline h WITH(NOLOCK)
						INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON h.PicID = p.PicID
						INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingID = p.Role
					WHERE h.HeadlineID = @CustID
					FOR XML PATH('PIC'))	    

		SELECT @OldValues  =  (SELECT @CustID   AS 'HeadlineID',
								      @Username AS 'HeadlineName',
									  @XML
							   FOR XML PATH('Acc_CRM_HeadlineUpd')) --906
		IF @Case IN (3, 4)
		BEGIN
		    SELECT @HeadlineName_Old = UserName 
			FROM bodb02.dbo.Customer WITH(NOLOCK) 
			WHERE custid = @HeadlineID_Old

		    SELECT @NewValues = @OldValues 

			SELECT @OldValues  =  (SELECT @HeadlineID_Old   AS 'HeadlineId',
										  @HeadlineName_Old AS 'HeadlineName',
										  @XML
								   FOR XML PATH('Acc_CRM_HeadlineUpd')) -- 906
		END
		
			
	END											 

	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @UserID,
			@CustId = @CustId,
			@ActionID = @ActionID,
			@IP = @LoginIP,
			@NewValues = @NewValues,
			@OldValues = @OldValues

END