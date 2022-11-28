/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ArchivedAccount_SyncData] 
	@ArchivedList VARCHAR(MAX) 
	,@ArchivedDate DATE
AS
/*
	Created: Winfred
	Task : CRM -Auto-generated FB to Headline for Archiving Dormant Accounts
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20221121@Winfred: CRM -Auto-generated FB to Headline for Archiving Dormant Accounts [redmine:#158258]
	
	Parameter's Explanation:
		- @ArchivedList = '85435629,85435630,85435631,85435632,85435633,85435634,85435635,85435636,85435637,85435638,85435639'
		- ,@ArchivedDate = '2022-11-09'
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #CustList (CustID INT PRIMARY KEY)

	INSERT INTO #CustList(CustID)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@ArchivedList, ',')
	WHERE value <> ''

	DECLARE @i TINYINT = 0, @maxTry TINYINT = 5, @msg VARCHAR(1024) = ''
	WHILE @i < @maxTry
	BEGIN
		SET @msg = ''
		BEGIN TRY
			INSERT INTO crmArchivedAccount(CustId,ArchivedDate,CreateDate)
			SELECT t.CustId, @ArchivedDate AS ArchivedDate, GETDATE()
			FROM #CustList t
				OUTER APPLY (SELECT TOP 1 m.CustId FROM crmArchivedAccount m WITH(NOLOCK) 
							WHERE t.CustId = m.CustId AND m.ArchivedDate = @ArchivedDate) m
			WHERE m.CustId IS NULL
		END TRY
		BEGIN CATCH
			IF ERROR_NUMBER() = 2627 -- violation of primary key
				SET @i = @i + 1
			ELSE
				SET @i = @maxTry
			
			SET @msg = ERROR_MESSAGE()
		END CATCH

		IF @msg = ''
			BREAK
		
	END

	IF ISNULL(@msg, '') <> ''
	BEGIN
		RAISERROR(@msg, 16, 1)
		RETURN
	END

	DROP TABLE #CustList
		
END	