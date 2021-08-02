/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_PicDefaultDel]
	@HeadlineID		INT,
	@UserID			INT,
	@LoginIP        VARCHAR(20) ='',
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT
AS
/*
Created: 20200717@Malcolm
Task :  Get default PICs of a headline
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200717@Malcolm: remove default PICs from a headline [Redmine: #137144]
		- 20210731@Malcolm : Add alias [RedmineId : #151509] 
	Param's Explanation:
		
*/
BEGIN 
	SET NOCOUNT ON

	DECLARE @HeadlineName VARCHAR(20), @NewValues NVARCHAR(MAX) = ''

	IF NOT EXISTS(SELECT 1 FROM dbo.crmPICDefault WITH(NOLOCK) WHERE HeadlineID = @HeadlineID)
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'There are some updates on PIC assignment. Please submit again to get the lastest updates!'
		RETURN
	END

	SELECT @HeadlineName = Username FROM bodb02.dbo.Customer WITH(NOLOCK) WHERE custid = @HeadlineID

	SELECT @NewValues =	CAST((SELECT	d.PicID			AS '@PicID',
										p.Username		AS '@PicName',
										p.Role			AS '@RoleID',
										s.SettingValue	AS '@RoleName'
							  FROM dbo.crmPICDefault d WITH(NOLOCK)
								 INNER JOIN dbo.crmPIC p WITH(NOLOCK)  ON d.PicID = p.PicID
								 INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingID = p.Role
							  WHERE d.HeadlineID = @HeadlineID
							  FOR XML PATH('PIC'),ROOT('Acc_CRM_PicDefaultDel')) AS NVARCHAR(MAX))

	BEGIN TRY
		DELETE dbo.crmPICDefault
		WHERE HeadlineID = @HeadlineID
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH	

	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @UserID,
			@CustId = @HeadlineID,
			@ActionID = 908,
			@IP = @LoginIP,
			@NewValues = @NewValues

END
GO
