/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE	dbo.Acc_CRM_SubProductList
					@ProductID		INT = 0,
					@UserRole		TINYINT,
					@Active			TINYINT = 1,
					@Lang			VARCHAR(10)='en-US'
AS /*
	Created:	20160323@Billy
	Task:		Get List of SubProduct by ProductID - [Redmine: #52998]
	DB:			DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20190506@Winnie: CN88 Permission RedmineID: #112637
		- 20201030@Johnson: add filter IsActive [redmine: #142194]
	Param's Explanation:
		- @Active = 1: get active
				= 2: get all 
*/
BEGIN	
	SET NOCOUNT ON
	
		CREATE TABLE #Setting(			
			[SettingID] [int] PRIMARY KEY,
			[SettingValue] [nvarchar](100) ,
			[DisplayOrder] [int] ,
			[IsActive] [bit] ,		
			[SettingValueCS] [nvarchar](100) NULL,
			[SettingValueCT] [nvarchar](100) NULL
		)
		INSERT INTO #setting([SettingID],[SettingValue],[SettingValueCS],[SettingValueCT],[DisplayOrder],[IsActive])
		SELECT cs.SettingID,cs.SettingValue,cs.SettingValueCS,cs.SettingValueCT,cs.DisplayOrder,IsActive		
		FROM dbo.crmSetting AS cs WITH (NOLOCK)
		WHERE cs.SettingName = 'SubProduct'
			AND 1 = CASE WHEN (@Active = 1 AND IsActive = 1) OR @Active = 2 THEN 1 ELSE 0 END
			AND (cs.SiteOffer=@UserRole )
	
	SELECT	cs.SettingID		SubProductID,	
			CASE	WHEN @Lang='zh-TW' THEN ISNULL(SettingValueCT,SettingValue)
					WHEN @Lang='zh-CN' THEN ISNULL(SettingValueCS,SettingValue)
											ELSE SettingValue
			END AS Name
		,	csr.ParentID		ProductID
		,	cs.DisplayOrder		DisplayOrder
		,	cs.IsActive			IsActive
	FROM	#setting AS cs WITH (NOLOCK)
	INNER JOIN	dbo.crmSettingRelation AS csr WITH (NOLOCK)
			ON	csr.SettingID = cs.SettingID
	WHERE			
			csr.ParentID = ISNULL(CASE WHEN @ProductID = 0 THEN NULL ELSE @ProductID END, csr.ParentID)		
	ORDER BY csr.ParentID ASC, cs.DisplayOrder ASC;
END
GO

