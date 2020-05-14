/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_SettingIns]  
(  
	 @UserID   INT,  
	 @SettingName VARCHAR(50),  
	 @SettingType TINYINT  = 0,  
	 @SettingValue NVARCHAR(100),  
	 @SettingSource VARCHAR(MAX)='',
	 @ParentID  INT,  
	 @DisplayOrder INT,  
	 @IP    VARCHAR(15),  
	 @ErrCode  INT = 0 OUTPUT,  
	 @ErrMsg   NVARCHAR(4000) = '' OUTPUT ,
	 @UserRole	INT
)  
AS  
/*  
	Created: Lukas  
	Date: 20101020  
	Task : Insert new setting  
	DB: DBCRM/bodb_CRM  
	Original:  
	  
	Revisions:  
	 - 20120424@Sophia: Add parameter @SettingType for @SettingName = 'Site' to indicate Licensee site or Credit Site  
	 - 20130121@Johnson: chang linked server DB03 to DBPOLICY  
	 - 20140114@Dom: Update Language setting  
	 - 20190506@Winnie: CN88 Permission RedmineID: #112637
	 - 20200421@Johnson: add mapping setting for auto feedback [redmine:#130949]
	Param's Explanation:  
	 @SettingType:  
	   0 : Licensee site    
	   1 : Credit site  
  
*/  
BEGIN  
	SET NOCOUNT ON  

	--Check permission  
	--EXEC DBPOLICY.bodb02.dbo.Acc_Con_CheckPermission @custid=@UserID,@funcname='[SettingManagement]',@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT  
	--IF @ErrCode <> 0  
	--RETURN  

	DECLARE @SettingRelation_DisplayOrder INT  
	DECLARE @SettingID INT,   
			@MaxSettingID INT  

	SELECT @ErrCode      = 0,  
			@ErrMsg       = '',  
			@SettingRelation_DisplayOrder = 0  

	--- check existed  
	SELECT TOP 1 @SettingID = SettingID   
	FROM crmSetting WITH(NOLOCK)   
	WHERE SettingName = @SettingName AND @SettingName <> 'Site' AND SettingValue = @SettingValue AND SiteOffer=@UserRole  
	ORDER BY SettingID DESC  
	
	IF ISNULL(@SettingID, '') <> ''  
	BEGIN  
		UPDATE crmSetting WITH(ROWLOCK,UPDLOCK)  
		SET  IsActive = 1  
		WHERE SettingName = @SettingName   
			AND SettingValue = @SettingValue  
			AND SettingID =@SettingID   
			AND SiteOffer=@UserRole   
	END  
	ELSE --- check existed for Site and indicate Credit/Licensee    
		SELECT TOP 1 @SettingID = SettingID    
		FROM crmSetting WITH(NOLOCK)   
		WHERE SettingName = @SettingName AND @SettingName = 'Site' AND SettingValue = @SettingValue   
			AND CASE WHEN @SettingType = 1 AND SettingID BETWEEN 6000 AND 6199 THEN 1  
					WHEN @SettingType = 0 AND SettingID BETWEEN 6200 AND 6999 THEN 1  
					ELSE 0 END = 1  
			AND SiteOffer=@UserRole
		ORDER BY SettingID DESC  

	IF ISNULL(@SettingID, '') <> ''  
	BEGIN  
		UPDATE  crmSetting WITH(ROWLOCK,UPDLOCK)  
		SET  IsActive = 1, @SettingID = SettingID  
		WHERE SettingName = @SettingName   
			AND SettingValue = @SettingValue  
			AND CASE WHEN @SettingType = 1 AND SettingID BETWEEN 6000 AND 6199 THEN 1  
					WHEN @SettingType = 0 AND SettingID BETWEEN 6200 AND 6999 THEN 1  
					ELSE 0 END = 1  
			AND SettingID =@SettingID   
			AND SiteOffer=@UserRole
	END  
	ELSE --create new  
	BEGIN  
		-- generate SettingID  
		IF NOT EXISTS (SELECT 1 FROM crmSetting WITH(NOLOCK) WHERE SettingName = @SettingName AND SiteOffer=@UserRole)  
		BEGIN  
			SELECT @MaxSettingID = MAX(SettingID)  
			FROM crmSetting WITH(NOLOCK)  

			SELECT @SettingID = (@MaxSettingID/1000 + 1)*1000  
		END  
		ELSE  --- Setting name existed already  
		BEGIN

			IF @SettingName = 'Site' AND @SettingType = 1 --- for Credit Site  
			BEGIN  
				SELECT @SettingID = MAX(SettingID) + 1  
				FROM crmSetting WITH(NOLOCK)  
				WHERE SettingName = 'Site' AND SettingID < 6200  
			END  
			ELSE   
			BEGIN  
				SELECT @SettingID = MAX(SettingID) + 1  
				FROM crmSetting WITH(NOLOCK)  
				WHERE SettingName = @SettingName  
			END  
		END
		
		--- get display order in crmSettingRelation table  
		SELECT   
			@SettingRelation_DisplayOrder = CASE WHEN @ParentID <> 0 THEN ISNULL(MAX(DisplayOrder) + 1, 0) ELSE 0 END  
		FROM crmSettingRelation WITH(NOLOCK)  
		WHERE ParentID = @ParentID  

		--- insert to setting  
		INSERT INTO crmSetting  
		(  
			SettingName,   
			SettingID,   
			SettingValue,   
			DisplayOrder,
			SiteOffer
		)  
		VALUES   
		(  
			@SettingName,   
			@SettingID,  
			@SettingValue,   
			@DisplayOrder,
			@UserRole  
		)  
	
		IF @@ERROR <> 0  
		BEGIN  
			SELECT @ErrCode = 101, @ErrMsg = 'Create new setting unsuccessfuly.'  
			RETURN  
		END  
		
		IF @SettingName IN ('Product','SubProduct','Bettype') AND ISNULL(@SettingSource,'') <> ''
		BEGIN
			INSERT INTO crmSettingMapping(SettingID,SettingSource)	
			SELECT @SettingID, val
			FROM f_CRM_StrSplit(@SettingSource,',')
		END
		
		--- insert to settingrelation  
		EXEC [dbo].[Acc_CRM_SettingRelationIns]  
				@UserID = @UserID,  
				@SettingID = @SettingID,  
				@ParentID = @ParentID,  
				@DisplayOrder = @SettingRelation_DisplayOrder,  
				@IP = @IP,  
				@ErrCode = @ErrCode OUTPUT,  
				@ErrMsg = @ErrMsg OUTPUT  
		IF @ErrCode <> 0  
		BEGIN  
		-- rollback  
			DELETE FROM crmSetting WHERE SettingID = @SettingID AND SiteOffer=@UserRole
			DELETE FROM crmSettingMapping WHERE SettingID = @SettingID 
			SELECT @ErrCode = 102, @ErrMsg = @ErrMsg--'Create new setting unsuccessfuly.'  
			RETURN  
		END  

	END --- end create new  

	-- write log  
	DECLARE @LogElement XML  

	SELECT @LogElement =       
		'<Acc_CRM_SettingIns>' + --SP Name  
		'<SettingName>'  + ISNULL(@SettingName,'')      + '</SettingName>'  +  
		'<SettingValue>' + ISNULL(@SettingValue,'')      + '</SettingValue>' +  
		'<DisplayOrder>' + ISNULL(CONVERT(VARCHAR(10),@DisplayOrder),'') + '</DisplayOrder>' +  
		'<UserRole>' + ISNULL(CONVERT(VARCHAR(10),@UserRole),'') + '</UserRole>' +  
		'</Acc_CRM_SettingIns>'  


	EXEC [dbo].[WriteLog_UserLog_crmLogSetting]  
		@SettingID = @SettingID,   
		@ParentID = 0,   
		@UserID = @UserID,   
		@ActionID = 300,   
		@IP = @IP,   
		@NewValues = @LogElement  
END  
GO 

