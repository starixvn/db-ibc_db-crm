/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_SettingRelationUpd]
(
	@UserID			INT,
	@SettingID		VARCHAR(MAX)	= '',
	@ParentID		INT,
	@SettingName	VARCHAR(50)		= '',
	@IP				VARCHAR(15),
	@ErrCode		INT				= 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000)	= '' OUTPUT
)
AS
/*
	Created: Lukas
	Date: 
	Task : insert multiple Setting relation.
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20120329@Lukas: fix bug - wrong SP name & ActionID when write log
		- 20130121@Johnson: change linked server DB03 to DBPOLICY		
		- 20181113@Winnie: Fix bug log RedmineID: #103259
		- 20230629@Malcolm: change data type of @SettingID from VARCHAR(4000) to VARCHAR(MAX)  [redmine:#190437]
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @SubSetting TABLE(ID INT PRIMARY KEY IDENTITY, SettingID INT, DisplayOrder INT)
	DECLARE @OldValue NVARCHAR(MAX)

	SELECT @OldValue = STRING_AGG(CONVERT(VARCHAR(MAX), SettingID), ',') FROM dbo.crmSettingRelation WITH(NOLOCK)WHERE ParentID = @ParentID 

	SELECT	@ErrCode = 0, @ErrMsg = ''

	IF NOT EXISTS (SELECT 1 FROM dbo.crmSetting WITH(NOLOCK) WHERE SettingID = @ParentID)
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'Setting does not exist.'
		RETURN
	END

	IF @SettingID <> ''
	BEGIN	
		INSERT INTO @SubSetting(SettingId, DisplayOrder)
		SELECT n.SettingId, n.DisplayOrder
		FROM STRING_SPLIT (@SettingID, '|') r
			CROSS APPLY (
				SELECT 
					SUBSTRING(r.value, 1, CHARINDEX('_', r.value,1) -1) AS SettingId
					,SUBSTRING(r.value, CHARINDEX('_', r.value,1) + 1, LEN(r.value)) AS DisplayOrder
			) AS n
		WHERE r.value <> ''
	END

	--- delete
	DELETE FROM dbo.crmSettingRelation WITH(ROWLOCK,UPDLOCK)
	WHERE SettingID IN 
	(		
		SELECT SettingID 
		FROM dbo.crmSetting WITH(NOLOCK)
		WHERE SettingName = @SettingName
		EXCEPT
		SELECT SettingID FROM @SubSetting
	) AND ParentID = @ParentID

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'Update setting relation unsuccessfuly.'
		RETURN
	END

	--- update
	UPDATE rl WITH(ROWLOCK,UPDLOCK)
	SET	rl.DisplayOrder = s.DisplayOrder
	FROM crmSettingRelation rl 
			INNER JOIN @SubSetting s ON rl.ParentID = @ParentID AND rl.SettingID = s.SettingID
	WHERE rl.DisplayOrder <> s.DisplayOrder

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 102, @ErrMsg = 'Update setting relation unsuccessfuly.'
		RETURN
	END
	--- insert
	INSERT INTO dbo.crmSettingRelation(SettingID,ParentID,DisplayOrder)
	SELECT SettingID, @ParentID, DisplayOrder
	FROM @SubSetting
	WHERE SettingID NOT IN (SELECT s.SettingID
							FROM dbo.crmSettingRelation rl 
								INNER JOIN @SubSetting s ON rl.ParentID = @ParentID 
							AND rl.SettingID = s.SettingID)
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 103, @ErrMsg = 'Insert setting relation unsuccessfuly.'
		RETURN
	END

	-- write log
	DECLARE @LogElement XML
	DECLARE @LogElement_OLD XML

	SELECT @LogElement_OLD = 				
					'<Acc_CRM_SettingRelationUpd>' + --SP Name
						'<SettingID> ' + ISNULL(@OldValue,'') + '</SettingID>' + 
					'</Acc_CRM_SettingRelationUpd>'		

	SELECT @LogElement = 				
					'<Acc_CRM_SettingRelationUpd>' + --SP Name
						'<SettingID> ' + ISNULL(@SettingID,'') + '</SettingID>' + 
					'</Acc_CRM_SettingRelationUpd>'				

	EXEC [dbo].[WriteLog_UserLog_crmLogSetting]
					@SettingID = 0,--multiple SettingID, 
					@ParentID = @ParentID, 
					@UserID = @UserID, 
					@ActionID = 303, 
					@IP = @IP, 
					@NewValues = @LogElement,
					@OldValues = @LogElement_OLD

END

GO
