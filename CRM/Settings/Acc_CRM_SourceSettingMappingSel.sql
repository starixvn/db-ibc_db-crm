/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Acc_CRM_SourceSettingMappingSel
	@Settings VARCHAR(MAX)
AS
/*
	Created: 20200421@Johnson	
	Task: get source setting for crm setting 
	DB:	DBCRM/bodb_CRM
	Original:
	
	Revisions:
		- 20200421@Johnson: initial sp [redmine:#130949]
		- 20201021@Johnson: get all products/sports/bettypes to support mapping for winlimit fb  [redmine:#142194]
	Parameter's Explanations:
*/	
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @tmpSetting TABLE (SettingName VARCHAR(50))
	DECLARE @result TABLE (SettingName VARCHAR(50), Source VARCHAR(50))
	
	INSERT INTO @tmpSetting (SettingName)
	SELECT val
	FROM f_CRM_StrSplit(@Settings,',')
	
	IF EXISTS(SELECT 1 FROM @tmpSetting WHERE SettingName = 'product')
	BEGIN
		INSERT INTO @result(SettingName,Source)
		SELECT 'Product',ProductName
		FROM bodb02.dbo.Products WITH(NOLOCK)
		WHERE Enabled = 1		
	END
	
	IF EXISTS(SELECT 1 FROM @tmpSetting WHERE SettingName = 'SubProduct')
	BEGIN
		INSERT INTO @result(SettingName,Source)
		SELECT 'SubProduct',SportName
		FROM bodb02.dbo.sports WITH(NOLOCK)
		WHERE sportType IN (SELECT DISTINCT SportType 
							FROM bodb02.dbo.SportBettypeMatrix WITH(NOLOCK)
							WHERE ProductID IN (SELECT ProductID 
												FROM bodb02.dbo.Products WITH(NOLOCK)
												WHERE Enabled = 1)
								AND IsTest = 0
							)							
	END
	
	IF EXISTS(SELECT 1 FROM @tmpSetting WHERE SettingName = 'Bettype')
	BEGIN
		INSERT INTO @result(SettingName,Source)
		SELECT 'Bettype',TypeNamee
		FROM bodb02.dbo.bettype WITH(NOLOCK)
		WHERE typeid IN (SELECT DISTINCT bettype 
							FROM bodb02.dbo.SportBettypeMatrix WITH(NOLOCK)
							WHERE ProductID IN (SELECT ProductID 
												FROM bodb02.dbo.Products WITH(NOLOCK)
												WHERE Enabled = 1)
								AND IsTest = 0
							)
	END
	
	SELECT *
	FROM @Result
	ORDER BY SettingName, Source ASC
END