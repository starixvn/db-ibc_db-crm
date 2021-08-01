/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_ChatBot_crmMessageImport_Ins]
	@Messages XML
AS

/*
	Created: 20200811@Percy
	DB: DBCRM-bodb_CRM
	Task: CRM - ChatBot - Insert data into crmMessageImport

	Revisions:
		- 20200811@Percy: Initialize SP [RedmineID: #130544]
		- 20201029@Percy: Change left join to outer apply [RedmineID: #144466]
		- 20201105@Percy: Try 5 times for duplicate primary key [RedmineID: #144466]
		- 20210415@Malcolm: Integrate Abnormal Accounts [RedmineId : #157303]

	Param's Explanation:
		@Messages:
			<root>
				<r MessageID="1" RequestID="1" UsernameList="xxx,u1" CustIdList=""/>
				<r MessageID="1" RequestID="2" UsernameList="xxx,u1" CustIdList=""/>
				<r MessageID="3" RequestID="2" UsernameList="xxx,u1" CustIdList=""/>
			</root>	
		
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Messages (MessageId INT, RequestId INT, UsernameList NVARCHAR(MAX), CustIdList VARCHAR(MAX))
	INSERT INTO  #Messages (MessageId, RequestId, UsernameList, CustIdList)
	SELECT DISTINCT
		t.c.value('@MessageID', 'INT') AS MessageId
		,t.c.value('@RequestID', 'INT') AS RequestId
		,t.c.value('@UsernameList', 'NVARCHAR(MAX)') AS UsernameList
		,t.c.value('@CustIdList', 'VARCHAR(MAX)') AS CustIdList
	FROM @Messages.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@Messages = NULL))

	DECLARE @i TINYINT = 0, @maxTry TINYINT = 5, @msg VARCHAR(1024) = ''

	WHILE @i < @maxTry
	BEGIN
		BEGIN TRY
			INSERT INTO dbo.crmMessageImport (MessageId, RequestId, UsernameList, CustIdList, CreatedDate, IsProcessed)
			SELECT m.MessageId, m.RequestId, m.UsernameList, m.CustIdList, GETDATE(), CASE WHEN m.UsernameList IS NOT NULL AND m.UsernameList <> '' THEN 1 ELSE 0 END AS isProcessed
			FROM #Messages m
				OUTER APPLY (SELECT TOP 1 cm.MessageId FROM dbo.crmMessageImport cm WITH (NOLOCK) WHERE m.MessageId = cm.MessageId AND m.RequestId = cm.RequestId) cm
			WHERE cm.MessageId IS NULL
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
		RAISERROR(@Msg, 16, 1)
		RETURN
	END

	DROP TABLE #Messages
END
GO


