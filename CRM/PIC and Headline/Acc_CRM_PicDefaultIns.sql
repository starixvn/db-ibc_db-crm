/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_PicDefaultIns]
	@HeadlineID		INT,
	@DefaultPicIDs	NVARCHAR(200) ,
	@UserID			INT,
	@LoginIP        VARCHAR(20) ='',
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT
AS
/*
Created: 20200717@Malcolm
Task :  insert/update default PICs of a headline
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200717@Malcolm: insert/update default PICs of a headline [Redmine: #137144]
	Param's Explanation:
		
*/
BEGIN 
	SET NOCOUNT ON

	DECLARE @TmpLog TABLE 
	(
		HeadlineID	INT,
		PicID		INT, 
		PicName		NVARCHAR(200),
		RoleID		INT,
		RoleName	NVARCHAR(100),
		Type		INT
	)

	DECLARE @OldValues NVARCHAR(MAX) = '', @NewValues NVARCHAR(MAX) = ''
	
	BEGIN TRY
		DELETE dbo.crmPICDefault WITH(ROWLOCK, UPDLOCK)
		OUTPUT deleted.HeadlineID, deleted.PicID, 1 
			INTO  @TmpLog(HeadlineID, PicID, Type)
		WHERE HeadlineID = @HeadlineID

		INSERT INTO dbo.crmPICDefault (HeadlineID, PicID)
		OUTPUT inserted.HeadlineID, inserted.PicID, 2
			INTO @TmpLog (HeadlineID, PicID, Type)
		SELECT DISTINCT @HeadlineID, s.val AS PicID
		FROM bodb02.dbo.strSplit(@DefaultPicIDs,',') s
	END TRY
	BEGIN CATCH 
		IF EXISTS(SELECT 1 FROM @TmpLog)
		BEGIN
			INSERT INTO dbo.crmPICDefault
			SELECT HeadlineID, PicID
			FROM @TmpLog
		END
		RETURN
	END CATCH

	UPDATE t
	SET t.RoleID	= p.Role,
		t.RoleName	= s.SettingValue,
		t.PicName   = p.Username
	FROM @TmpLog t
		INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON t.PicID = p.PicID
		INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingID = p.Role

	SELECT @OldValues = CAST((SELECT	t.PicID		AS '@PicID',
										t.PicName	AS '@PicName',
										t.RoleID	AS '@RoleID',
										t.RoleName	AS '@RoleName'
							 FROM @TmpLog t	
							 WHERE Type = 1
							 FOR XML PATH('PIC'), ROOT('Acc_CRM_PicDefaultIns')) AS NVARCHAR(MAX))

	SELECT @NewValues = CAST((SELECT	t.PicID		AS '@PicID',
										t.PicName	AS '@PicName',
										t.RoleID	AS '@RoleID',
										t.RoleName	AS '@RoleName'
							 FROM @TmpLog t								
							 WHERE Type = 2
							 FOR XML PATH('PIC'), ROOT('Acc_CRM_PicDefaultIns')) AS NVARCHAR(MAX))


	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @UserID,
			@CustId = @HeadlineID,
			@ActionID = 907,
			@IP = @LoginIP,
			@NewValues = @NewValues,
			@OldValues = @OldValues
END
GO
