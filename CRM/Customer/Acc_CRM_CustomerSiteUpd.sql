/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_CustomerSiteUpd]  
(	
	@CustID		INT,  
	@Site		NVARCHAR(50),
	 
	@IP    VARCHAR(15),  
	@ErrCode  INT = 0 OUTPUT,  
	@ErrMsg   NVARCHAR(4000) = '' OUTPUT
)  
AS  
/*  
	Created: 20200915@Johnson  	
	Task : update site in crm incase move site from NAP
	DB: DBCRM/bodb_CRM  
	  
	Revisions:  
		- 20200915@Johnson: initial sp [redmine:#141257]
		- 20240315@NedLe: CRM - Migrate internal accounts to new 2 new sites - Hedging & Special [redmine:#202208]
	
	DECLARE @ErrCode  INT = 0 ,  
		@ErrMsg   NVARCHAR(4000) = '' 

	exec Acc_CRM_CustomerSiteUpd @CustID =1176086, 
		@Site = 'Test Site JS3',	 
		@IP   = '',  
		@ErrCode  = @ErrCode OUTPUT,  
		@ErrMsg   = @ErrMsg OUTPUT
		
	select @ErrMsg, @ErrCode		
*/	
BEGIN
	SET NOCOUNT ON
	
	DECLARE @siteID 	INT,
			@SiteID_Old INT,
			@roleid 	INT
	
	IF NOT EXISTS (SELECT 1 FROM crmCustomer WITH(NOLOCK) WHERE custid = @custid)
		RETURN;
		
	SELECT TOP (1) @SiteID = SettingID
	FROM crmSetting WITH(NOLOCK)
	WHERE SettingName = 'site'	
		AND SettingValue = @site
	
	IF @SiteID IS NULL
	BEGIN
		SELECT @ErrCode = 100,
			@ErrMsg = 'Missing site setting in CRM'
		RETURN;
	END
	
	SELECT @roleid = roleid
	FROM bodb02.dbo.custinfo WITH(NOLOCK)
	WHERE custid = @custid
	
	SELECT @SiteID_Old = SiteID
	FROM crmCustomer WITH(NOLOCK)
	WHERE custid = @custid
	
	IF @roleid = 4
	BEGIN
		UPDATE c
		SET siteID = @siteID
		FROM crmCustomer c WITH(UPDLOCK,ROWLOCK)
			INNER JOIN bodb02.dbo.custinfo ci WITH(NOLOCK) ON c.custid = ci.custid
		WHERE ci.srecommend = @custid
	END
	ELSE IF @roleid = 3
	BEGIN
		UPDATE c
		SET siteID = @siteID
		FROM crmCustomer c WITH(UPDLOCK,ROWLOCK)
			INNER JOIN bodb02.dbo.custinfo ci WITH(NOLOCK) ON c.custid = ci.custid
		WHERE ci.mrecommend = @custid
	END
	ELSE IF @roleid = 2
	BEGIN
		UPDATE c
		SET siteID = @siteID
		FROM crmCustomer c WITH(UPDLOCK,ROWLOCK)
			INNER JOIN bodb02.dbo.custinfo ci WITH(NOLOCK) ON c.custid = ci.custid
		WHERE ci.recommend = @custid
	END
	ELSE IF @roleid = 1
	BEGIN
		UPDATE c
		SET siteID = @siteID
		FROM crmCustomer c WITH(UPDLOCK,ROWLOCK)
			INNER JOIN bodb02.dbo.custinfo ci WITH(NOLOCK) ON c.custid = ci.custid
		WHERE ci.custid = @custid
	END
	
	-- write log
	DECLARE @NewValues XML,@OldValues XML
	SELECT @OldValues =
					'<Acc_CRM_CustomerSiteUpd>' + --SP Name
						'<SiteID>'	+ ISNULL([dbo].[f_EncodeXMLValue](@SiteID_Old),'')+ '</SiteID>'	+
					'</Acc_CRM_CustomerSiteUpd>'	
					
	SELECT @NewValues =
					'<Acc_CRM_CustomerSiteUpd>' + --SP Name
						'<SiteID>'	+ ISNULL([dbo].[f_EncodeXMLValue](@SiteID),'')+ '</SiteID>'	+
					'</Acc_CRM_CustomerSiteUpd>'
					
	EXEC [dbo].[WriteLog_UserLog_crmLogCustomer]
				@CustID = @CustID, 
				@UserID = 10278938, --starixIT
				@ActionID = 106, 
				@IP = @IP, 
				@NewValues = @NewValues,
				@OldValues = @OldValues
END