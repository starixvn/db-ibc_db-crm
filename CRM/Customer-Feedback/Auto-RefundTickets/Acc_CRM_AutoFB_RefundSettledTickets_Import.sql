/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" isFunction="0" isNested="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_AutoFB_RefundSettledTickets_Import]
	@Message			XML
	,@MessageContent 	XML
	,@Environment		VARCHAR(50) = ''
	,@ErrCode			INT = 0 OUTPUT
	,@ErrMsg			NVARCHAR(4000) = '' OUTPUT
	,@IP				VARCHAR(45) = ''
AS

/*
	Created: 20210731@Malcolm
	DB: DBCRM-bodb_CRM
	Task: CRM - AutoFB - Refund Settled tickets - Import Auto feedback

	Revisions:
		- 20210731@Malcolm: Initialize SP [RedmineId: #195404]
        - 20240318@Ned.Le: Fix bug relate to table crmSettingMapping
        - 20240320@Ned.Le: CRM - Manage Headline/PIC/Staff authority and Company services (#193385)
		- 20240718@Luke: CRM - Incorporate new product - Virtual Sports 5 [Redmine: #207712]
		
	Param's Explanation:
		. @MessageContent = 
					  '<root>
							<r MessageId="1" MatchId="114" Content_en="Content_en" Content_cs="Content_cs" Content_yn="Content_yn"/>
					  </root>'
		. @Message = '<root>
							<r MessageId="1" MsgTargetId="2" BetTransId="1,2,3,4"/>
					  </root>'
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @LastMsgTargetId INT, @SettingNameOfJobStatus VARCHAR(50) = '',@SettingNameOfLastMsgTargetId VARCHAR(50) = '', @IncludeUUSCurrency BIT, @LastRuntime DATETIME 
			,@SettingNameOfLastRuntime VARCHAR(50) = '' 

	DECLARE @ServerName NVARCHAR(100) = @@SERVERNAME, @DBName NVARCHAR(100) = DB_NAME(), @SPName NVARCHAR(300) = OBJECT_NAME(@@PROCID)

	SELECT @IncludeUUSCurrency = CONVERT(BIT, Value) FROM dbo.SystemSetting WITH(NOLOCK) WHERE ServiceName = 'AutoFB - Refund Settled tickets' and SettingName = 'IncludeUUSCurrency'
	
	SELECT @Environment = ISNULL(@Environment, '')
		   ,@SettingNameOfJobStatus = CASE WHEN @Environment = 'UAT' THEN 'JobStatusUAT' ELSE 'JobStatus' END
		   ,@SettingNameOfLastMsgTargetId = CASE WHEN @Environment = 'UAT' THEN 'LastMsgTargetIdUAT' ELSE 'LastMsgTargetId' END
		   ,@SettingNameOfLastRuntime = CASE WHEN @Environment = 'UAT' THEN 'LastRuntimeUAT' ELSE 'LastRuntime' END

	DECLARE @FeedbackId INT, @StationId INT, @CategoryId INT, @SubCategoryId INT, @ProductId INT, @RelatedCustomers NVARCHAR(MAX), @ResponseId INT, @StatusId INT
	DECLARE @CreatorId INT = 10278938 -- Starix

	-- Update Job Status
	UPDATE dbo.SystemSetting WITH(ROWLOCK)
		SET Value = 'running'
	WHERE ServiceName = 'AutoFB - Refund Settled tickets'
		AND SettingName = @SettingNameOfJobStatus
		AND Value = 'Completed'
	
	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @LastRuntime = CONVERT(DATETIME, Value) FROM dbo.SystemSetting WITH(NOLOCK) WHERE SettingName = @SettingNameOfLastRuntime AND ServiceName = 'AutoFB - Refund Settled tickets'

		IF DATEDIFF(SECOND, @LastRuntime, GETDATE()) >= 5 * 60
		BEGIN
			UPDATE dbo.SystemSetting WITH (ROWLOCK)
			SET Value = 'Completed'
			WHERE ServiceName = 'AutoFB - Refund Settled tickets'
				AND SettingName = @SettingNameOfJobStatus
				AND Value = 'running'

			--Update LastRuntime
			UPDATE dbo.SystemSetting WITH (ROWLOCK)
			SET Value = CONVERT(VARCHAR(20), GETDATE(), 120)
			WHERE ServiceName = 'AutoFB - Refund Settled tickets'
				AND SettingName = @SettingNameOfLastRuntime
		END
		ELSE 
		BEGIN
			SELECT @ErrCode = 100, @ErrMsg = 'Server Name : ' + @ServerName + ' - Database Name : ' + @DBName + ' - SP Name : ' + @SPName + ' - Error Message : ' + 'AutoFB - Refund Settled tickets - Job is running.'
		END	
		RETURN
	END

	--Update LastRuntime
	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = CONVERT(VARCHAR(20), GETDATE(), 120)
	WHERE ServiceName = 'AutoFB - Refund Settled tickets'
		AND SettingName = @SettingNameOfLastRuntime

	SELECT 
		@ResponseId = MAX(CASE WHEN SettingName = 'Response' AND SettingValue = 'Neutral' THEN SettingId ELSE NULL END) --Response: Neutral
		,@StatusId = MAX(CASE WHEN SettingName = 'Status' AND SettingValue = 'Closed' THEN SettingId ELSE NULL END) -- Status: Closed
		,@StationId = MAX(CASE WHEN SettingName = 'Station' AND SettingValue = 'N/A' THEN SettingId ELSE NULL END) -- CS Ex./Station: N/A	
		,@CategoryId = MAX(CASE WHEN SettingName = 'MainCategory' AND SettingValue = 'Result Amended/Recalculation Notification' THEN SettingId ELSE NULL END) -- Category: Result Amended/Recalculation Notification
		,@SubCategoryId = MAX(CASE WHEN SettingName = 'SubCategory' AND SettingValue = 'N/A' THEN SettingId ELSE NULL END) -- Sub Category: N/A	
		,@ProductId = MAX(CASE WHEN SettingName = 'Product' AND SettingValue = 'Virtual Sports' THEN SettingId ELSE NULL END)-- Product: Virtual Sports	
	FROM dbo.crmSetting WITH(NOLOCK)
	WHERE SiteOffer = 2

	DECLARE @AffectedList VARCHAR(MAX) = ''

	CREATE TABLE #CustHeadline (CustId INT, HeadlineId INT, HeadlineName VARCHAR(50))

	CREATE TABLE #MessageContent (MessageId INT, MatchId INT, Content_EN NVARCHAR(MAX), Content_SC NVARCHAR(MAX), Content_YN NVARCHAR(MAX))
	
	INSERT INTO #MessageContent (MessageId, MatchId, Content_EN, Content_SC, Content_YN)
	SELECT 
		t.c.value('@MessageId', 'INT') AS MessageId
		,t.c.value('@MatchId', 'INT') AS MatchId
		,t.c.value('@Content_en', 'NVARCHAR(MAX)') AS Content_EN
		,t.c.value('@Content_cs', 'NVARCHAR(MAX)') AS Content_SC
		,t.c.value('@Content_yn', 'NVARCHAR(MAX)') AS Content_YN
	FROM @MessageContent.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@MessageContent = NULL))

	CREATE TABLE #Message (MessageId INT, MsgTargetId INT, TransId BIGINT, CustId INT, Username VARCHAR(30), Recommend INT, Mrecommend INT
		,Srecommend INT, Content_en NVARCHAR(MAX), Content_cs NVARCHAR(MAX), BetransIds VARCHAR(MAX), HeadlineId INT, HeadlineName VARCHAR(30)
		,GroupName VARCHAR(50), MainDBSportTypeId TINYINT, MainDBBettypeId INT, SportTypeId INT, BettypeId INT, ProductId INT, MatchId INT, IsTest BIT DEFAULT 0)

	INSERT INTO #Message (MessageId, MsgTargetId, TransId)
	SELECT DISTINCT  
		t.c.value('@MessageId', 'INT') AS MessageId
		,t.c.value('@MsgTargetId', 'INT') AS MsgTargetId
		,n.TransId
	FROM @Message.nodes('root/r') t(c)
	CROSS APPLY (
		SELECT f.value AS TransId
		FROM STRING_SPLIT(t.c.value('@BetTransId','VARCHAR(MAX)'), ',') AS f
	) AS n
	OPTION (OPTIMIZE FOR (@Message = NULL), MAXRECURSION 0)

	IF @@ROWCOUNT = 0
	BEGIN
		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = 'Completed'
		WHERE ServiceName = 'AutoFB - Refund Settled tickets'
			AND SettingName = @SettingNameOfJobStatus
			AND Value = 'running'

		RETURN
	END

	SELECT @LastMsgTargetId = MAX(MsgTargetId) FROM #Message m

	/*Get headline*/
	UPDATE m
		SET m.TransId = b.TransId
			,m.CustId = b.custId
			,m.Recommend = b.recommend
			,m.Mrecommend = b.mrecommend
			,m.Srecommend = b.srecommend
			,m.Username = b.Username
			,m.IsTest = CASE WHEN b.currency = 20 THEN 1 ELSE 0 END
			,M.MainDBBettypeId = b.bettype
	FROM #Message m
	CROSS APPLY (
		SELECT TOP(1) TransId, custId, recommend, mrecommend, srecommend, Username, matchId, currency, bettype
		FROM bodb02.dbo.bettrans b WITH(NOLOCK)
		WHERE m.TransId = b.TransId
	) AS b

	UPDATE m
		SET m.TransId = b.TransId
			,m.CustId = b.custId
			,m.Recommend = b.recommend
			,m.Mrecommend = b.mrecommend
			,m.Srecommend = b.srecommend
			,m.Username = b.Username
			,m.IsTest = CASE WHEN b.currency = 20 THEN 1 ELSE 0 END
			,m.MainDBBettypeId = b.bettype
	FROM #Message m
	CROSS APPLY (
		SELECT TOP(1) TransId, custId, recommend, mrecommend, srecommend, Username, matchId, currency, bettype
		FROM bodb02.dbo.bettrans14 b WITH(NOLOCK)
		WHERE m.TransId = b.TransId
	) AS b
	WHERE m.TransId IS NULL
	
	-- Business model: Credit
	;WITH CTE_Deposit AS (	
		SELECT DISTINCT m.CustId
		FROM #Message m
			LEFT JOIN bodb02.dbo.Dep_CustSuper d WITH(NOLOCK) ON d.custId = m.Srecommend
		WHERE d.custId IS NOT NULL
	)
	DELETE m
	FROM #Message m
		INNER JOIN CTE_Deposit d ON d.CustId = m.CustId
		
	-- Only import testing accounts with uat environment
	IF @Environment = 'UAT'
	BEGIN
		;WITH CTE_RealMessage AS (
			SELECT DISTINCT MessageId FROM #Message WHERE IsTest = 0
		)
		DELETE m 
		FROM #Message m 
			INNER JOIN CTE_RealMessage r ON r.MessageId = m.MessageId
	END

	--Exclude UUS currency with LIVE environment
	IF @Environment = 'LIVE' AND @IncludeUUSCurrency = 0
	BEGIN
		DELETE m FROM #Message m WHERE m.IsTest = 1
	END

	IF NOT EXISTS (SELECT 1 FROM #Message)
	BEGIN
		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = CONVERT(VARCHAR(20), @LastMsgTargetId)
		WHERE ServiceName = 'AutoFB - Refund Settled tickets'
			AND SettingName = @SettingNameOfLastMsgTargetId

		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = 'Completed'
		WHERE ServiceName = 'AutoFB - Refund Settled tickets'
			AND SettingName = @SettingNameOfJobStatus
			AND Value = 'running'

		RETURN
	END

	UPDATE m
		SET m.MatchId = mc.MatchId
	FROM #Message m
		INNER JOIN #MessageContent mc ON mc.MessageId = m.MessageId
	
	;WITH CTE_Customer AS (
		SELECT DISTINCT CustId FROM #Message
	)
	SELECT @AffectedList = ISNULL(STRING_AGG(CONVERT(VARCHAR(MAX), CustId), ','), '') FROM CTE_Customer m

	INSERT INTO #CustHeadline(CustId,HeadlineId,HeadlineName)
	EXEC bodb02.dbo.Acc_CRM_GroupHeadlineSel @custIds = @AffectedList	

	UPDATE m
		SET m.HeadlineId = h.HeadlineId, m.HeadlineName = h.HeadlineName -- HeadlineName: HeadlineName OR Direct account name
	FROM #Message m
		INNER JOIN #CustHeadline h ON h.CustId = m.CustId

	DELETE m
	FROM #Message m
		INNER JOIN crmCustomer c WITH(NOLOCK) ON c.CustID = m.HeadlineId
	WHERE c.Ignored = 1

	CREATE TABLE #Headline (Id INT IdENTITY(1, 1), HeadlineId INT, HeadlineName VARCHAR(30), CommunicationIds VARCHAR(MAX), CommunicationNames NVARCHAR(MAX), SiteLable VARCHAR(20), IsVip BIT)

	INSERT INTO #Headline (HeadlineId, HeadlineName)
	SELECT DISTINCT HeadlineId, HeadlineName
	FROM #Message
	
	UPDATE h 
		SET h.SiteLable = s.SiteLabel, h.IsVip = ISNULL(cr.IsVIP, 0)
	FROM #Headline h 
		INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custId = h.HeadlineId
		INNER JOIN bodb02.dbo.Site s WITH(NOLOCK) ON s.site = c.site
		LEFT JOIN dbo.crmCustomer cr WITH(NOLOCK) ON cr.CustId = h.HeadlineId

	/*Get Default Comm Tool*/
	/*Default Communication of Headline Group / Direct Account Headline Group / Direct Account without default communication shall be set to "N/A"*/
	;WITH CTE_Setting AS (
		SELECT 
			c.DefaultCommId
			,c.CustId
			,STRING_AGG(IIF(c.SettingType = 1, CONVERT(VARCHAR(MAX), c.SettingId), NULL), ',') WITHIN GROUP (ORDER BY c.SettingId ASC) AS Categorystr
			,STRING_AGG(IIF(c.SettingType = 2, CONVERT(VARCHAR(MAX), c.SettingId), NULL), ',') WITHIN GROUP (ORDER BY c.SettingId ASC) AS SubCategorystr
			,STRING_AGG(IIF(c.SettingType = 3, CONVERT(VARCHAR(MAX), c.SettingId), NULL), ',') WITHIN GROUP (ORDER BY c.SettingId ASC) AS CommunicationIds
		FROM dbo.crmDefaultCommTool c WITH(NOLOCK) 
			INNER JOIN #Headline h ON h.HeadlineId = c.CustID
			LEFT JOIN crmSetting s WITH(NOLOCK) ON s.SettingID = c.SettingID
		WHERE c.DefaultCommID <> 0
		GROUP BY c.DefaultCommId, c.CustId	
	), CTE_CommTool AS (
		SELECT 
			CustId
			,CommunicationIds
			,CASE WHEN Categorystr = CONVERT(VARCHAR(20), @CategoryId) THEN 1
				  WHEN ',' + Categorystr + ',' LIKE '%,0,%' THEN 2 
			 ELSE 3 END AS Category_MappedLevel
			,CASE WHEN SubCategorystr = CONVERT(VARCHAR(20), @SubCategoryId) THEN 1
				  WHEN ',' + SubCategorystr + ',' LIKE '%,0,%' THEN 2
			 ELSE 3 END AS SubCategory_MappedLevel
		FROM CTE_Setting
	)
	UPDATE h
		SET h.CommunicationIds = ISNULL(df.CommunicationIds, '1005') -- CommunicationIds = 1005 : N/A
	FROM #Headline h
	OUTER APPLY (
		SELECT TOP(1) 
			CASE WHEN c.Category_MappedLevel = 3 OR c.SubCategory_MappedLevel = 3 THEN '1005' ELSE c.CommunicationIds END AS CommunicationIds
		FROM CTE_CommTool c
		WHERE h.HeadlineId = c.CustID 
		ORDER BY c.Category_MappedLevel, c.SubCategory_MappedLevel
	) AS df

	UPDATE h
	 SET h.CommunicationNames = n.CommunicationNames
	FROM #Headline h
	CROSS APPLY (
		SELECT STRING_AGG(CONVERT(NVARCHAR(MAX), s.SettingValue), '/') WITHIN GROUP (ORDER BY s.SettingValue ASC) AS CommunicationNames
		FROM STRING_SPLIT(h.CommunicationIds, ',') AS h 
			INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingID = CONVERT(INT, h.value)
	) AS n
	

	UPDATE m
		SET m.MainDBSportTypeId = mt.sporttype
	FROM #Message m		
		INNER JOIN bodb02.dbo.match mt WITH(NOLOCK) ON mt.matchId = m.MatchId

	--VS5
	UPDATE m
		SET m.MainDBSportTypeId = mt.sporttype
	FROM #Message m		
		INNER JOIN bodb02.dbo.Match3rd mt WITH(NOLOCK) ON mt.Match3rdId = m.MatchId
	
	/*Sub-Product*/
	;WITH CTE_Sporttype AS (
		SELECT m.MainDBSportTypeId, mp.SettingId
		FROM #Message m		
			INNER JOIN bodb02.dbo.Sports s WITH(NOLOCK) ON s.SportType = m.MainDBSportTypeId
			INNER JOIN dbo.crmSettingMapping mp WITH(NOLOCK) ON mp.SettingSource = s.SportName
            INNER JOIN dbo.crmSetting st WITH(NOLOCK) ON st.SettingName = 'SubProduct' AND st.SettingID = mp.SettingID
		GROUP BY m.MainDBSportTypeId, mp.SettingId
	),/*Bet Type*/ 
	CTE_Bettype AS (
		SELECT m.MainDBBettypeId, mp.SettingId
		FROM #Message m		
			INNER JOIN bodb02.dbo.bettype b WITH(NOLOCK) ON b.typeId = m.MainDBBettypeId
			INNER JOIN dbo.crmSettingMapping mp WITH(NOLOCK) ON mp.SettingSource = b.typenamee
            INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingName = 'BetType' AND s.SettingID = mp.SettingID
            INNER JOIN dbo.crmSettingRelation sr WITH(NOLOCK) ON sr.ParentID IN (SELECT SettingId FROM CTE_Sporttype) AND s.SettingID = sr.SettingID
		GROUP BY m.MainDBBettypeId, mp.SettingId 
	)
	UPDATE m
		SET m.SportTypeId = s.SettingId, m.BettypeId = b.SettingId
	FROM #Message m
		LEFT JOIN CTE_Sporttype s ON s.MainDBSportTypeId = m.MainDBSportTypeId
		LEFT JOIN CTE_Bettype b ON b.MainDBBettypeId = m.MainDBBettypeId 

	DECLARE @Id INT = 1, @CustId INT, @Username NVARCHAR(50)

	WHILE EXISTS (SELECT 1 FROM #Headline WHERE Id = @Id)
	BEGIN
		
		SELECT @CustId = HeadlineId, @Username = HeadlineName FROM #Headline WHERE Id = @Id

		IF NOT EXISTS (SELECT 1 FROM dbo.crmCustomer WITH(NOLOCK) WHERE CustId = @CustId)
		BEGIN
			EXECUTE dbo.Acc_CRM_CustomerIns_New 
						@UserId					 = @CreatorId
						,@CustId				 = @CustId
						,@UserName				 = @Username
						,@FirstName				 = NULL
						,@LastName				 = NULL
						,@TitleId				 = NULL
						,@Birthday				 = NULL
						,@LanguageId		     = 0
						,@Phone					 = NULL
						,@PhoneCountryCode		 = NULL
						,@PhoneAreaCode			 = NULL
						,@Phone2				 = NULL
						,@Phone2CountryCode		 = NULL
						,@Phone2AreaCode		 = NULL
						,@Phone3				 = NULL
						,@Phone3CountryCode		 = NULL
						,@Phone3AreaCode		 = NULL
						,@MobilePhone			 = NULL
						,@MobilePhoneCountryCode = NULL
						,@MobilePhoneAreaCode	 = NULL
						,@Fax					 = NULL
						,@FaxCountryCode		 = NULL
						,@FaxAreaCode			 = NULL
						,@Email					 = NULL
						,@Passport				 = NULL
						,@BettingCode            = NULL
						,@RefCode2				 = NULL
						,@Skype					 = NULL
						,@MSN					 = NULL
						,@CountryId				 = NULL
						,@IsVIP					 = 0
						,@SiteId				 = NULL
						,@CreatorId			     = @CreatorId
						,@LicenseeType           = NULL
						,@WhatsApp               = NULL
						,@Line                   = NULL
						,@WeChat				 = NULL
						,@Yahoo					 = NULL
						,@QQ					 = NULL
						,@BBM					 = NULL
						,@IP					 = @IP
						,@Pic1					 = NULL
						,@Pic2					 = NULL
						,@Pic3					 = NULL
						,@Pic4					 = NULL
						,@ProvinceId			 = NULL					
						,@ErrCode				 = @ErrCode OUTPUT
						,@ErrMsg				 = @ErrMsg OUTPUT;

					IF @ErrCode <> 0
					BEGIN
						SELECT @ErrCode = 101, @ErrMsg = 'Insert failed : SP - Acc_CRM_CustomerIns_New, Params : CustId : ' + ISNULL(CONVERT(VARCHAR(20), @CustId), '') + ', Username : ' + ISNULL(@Username, '') 
														 + ', CreatorId = ' + ISNULL(CONVERT(VARCHAR(20), @CreatorId), '') + ', IP = ' + ISNULL(CONVERT(VARCHAR(20), @IP), '')

						UPDATE dbo.SystemSetting WITH (ROWLOCK)
						SET Value = 'Completed'
						WHERE ServiceName = 'AutoFB - Refund Settled tickets'
							AND SettingName = @SettingNameOfJobStatus
							AND Value = 'running'

						RETURN;
					END;
				END

				SET @Id += 1
	END
	
	/*Sync Related Customer (Members that placed the affected tickets) to CRM*/
	;WITH CTE_Customer AS (
		SELECT DISTINCT HeadlineId AS CustId, CustId AS RelatedCustId, Username
		FROM #Message
	)
	SELECT @RelatedCustomers = (
		SELECT CustId AS '@CustId', RelatedCustId AS '@RelatedCustId', Username AS '@Username'
		FROM CTE_Customer
		FOR XML PATH ('Row'), ROOT('ROOT')
	)

	EXECUTE	dbo.Acc_CRM_AmendmentNoti_MultiCustIns
			@RelatedCustomers	= @RelatedCustomers
		   ,@UserId				= @CreatorId
		   ,@CreatorId			= @CreatorId
		   ,@IP					= @IP
		   ,@ErrCode			= @ErrCode OUTPUT
		   ,@ErrMsg				= @ErrMsg OUTPUT;
	IF @ErrCode <> 0
	BEGIN
		SELECT @ErrMsg = ISNULL(@ErrMsg, '') + ' - SP : Acc_CRM_AmendmentNoti_MultiCustIns, Params : RelatedCustomers = ' + ISNULL(@RelatedCustomers, '') + ', CreatorId = ' 
						+ ISNULL(CONVERT(VARCHAR(20), @CreatorId), '') + ', IP = ' + ISNULL(@IP, '')
		
		UPDATE dbo.SystemSetting WITH (ROWLOCK)
			SET Value = 'Completed'
		WHERE ServiceName = 'AutoFB - Refund Settled tickets'
			AND SettingName = @SettingNameOfJobStatus
			AND Value = 'running'
		RETURN;
	END;

	DECLARE @Getdate DATETIME = GETDATE()

	DECLARE @Result TABLE (Id INT IdENTITY(1, 1), MessageId INT, CustId INT, SubProductIds VARCHAR(MAX), BettypeIds VARCHAR(MAX), RelatedCustIds VARCHAR(MAX)
		,Description NVARCHAR(MAX), Solution NVARCHAR(MAX), CreatedBy INT, RoleId INT, LanguageId INT, CommunicationIds VARCHAR(MAX))

	;WITH CTE_SolutionTemplate AS (
		SELECT 
			CONVERT(NVARCHAR(MAX), 
				N'Dear Sir, Customer Support would like to inform the below announcement:<br/>'
				+ N'您好，客服部在此通知以下的通告：<br/><br/>' 
				+ N'{message_content_en}<br/>'
				+ N'{message_content_sc}<br/><br/>'
				+ N'Affected user/受影响会员: {affected_list}'
			) AS SolutionENSC
			,CONVERT(NVARCHAR(MAX),
				N'Dear Sir, Customer Support would like to inform the below announcement:<br/>'
				+ N'Xin chào quý khách, Bộ phận chăm sóc khách hàng xin thông báo thông báo dưới đây:<br/><br>'
				+ N'{message_content_en}<br/><br/>'
				+ N'Affected user / Tài khoản bị ảnh hưởng: {affected_list}'
			) AS SolutionENYN
	), CTE_Result AS (
		SELECT m.HeadlineId, m.MessageId, MAX(m.MatchId) AS MatchId
		FROM #Message m
		GROUP BY m.HeadlineId, m.MessageId
	), CTE_EventInfo AS (
		SELECT
			m.MatchId
			,FORMAT(mt.eventdate, 'dd-MMM-yyyy') AS EventDate
			,FORMAT(DATEADD(HH, 12, mt.GlobalShowTime), 'hh:mm tt') AS KO_time
			,h.teamname + ' -vs- ' + a.teamname AS Match
			,s.SportName
		FROM (
			SELECT DISTINCT MatchId FROM CTE_Result
		) AS m	
			INNER JOIN bodb02.dbo.match mt WITH(NOLOCK) ON mt.matchId = m.MatchId
			INNER JOIN bodb02.dbo.Team h WITH(NOLOCK) ON h.teamId = mt.homeId
			INNER JOIN bodb02.dbo.Team a WITH(NOLOCK) ON a.teamId = mt.awayId
			LEFT JOIN bodb02.dbo.Sports s WITH(NOLOCK) ON s.SportType = mt.sporttype

		UNION ALL

		SELECT
			m.MatchId
			,FORMAT(mt.eventdate, 'dd-MMM-yyyy') AS EventDate
			,FORMAT(DATEADD(HH, 12, mt.StartTime), 'hh:mm tt') AS KO_time
			,h.teamname + ' -vs- ' + a.teamname AS Match
			,s.SportName
		FROM (
			SELECT DISTINCT MatchId FROM CTE_Result
		) AS m	
			INNER JOIN bodb02.dbo.Match3rd mt WITH(NOLOCK) ON mt.Match3rdId = m.MatchId
			INNER JOIN bodb02.dbo.Team3rd h WITH(NOLOCK) ON h.Team3rdId = mt.homeId
			INNER JOIN bodb02.dbo.Team3rd a WITH(NOLOCK) ON a.Team3rdId = mt.awayId
			LEFT JOIN bodb02.dbo.Sports s WITH(NOLOCK) ON s.SportType = mt.sporttype
	), CTE_CommonInfo AS (
		SELECT 
			STUFF
			(
				(
					SELECT DISTINCT ',' + CONVERT(VARCHAR(MAX), BettypeId)  
					FROM #Message m
					WHERE m.HeadlineId = r.HeadlineId AND m.MessageId = r.MessageId
					FOR XML PATH('')
				), 1, 1, ''
			) AS BettypeIds
			,STUFF
			(
				(
					SELECT DISTINCT ',' + CONVERT(VARCHAR(MAX), SportTypeId)  
					FROM #Message m
					WHERE m.HeadlineId = r.HeadlineId AND m.MessageId = r.MessageId
					FOR XML PATH('')
				), 1, 1, ''
			) AS SportTypeIds
			,STUFF
			(
				(
					SELECT DISTINCT ',' + CONVERT(VARCHAR(MAX), CustId)  
					FROM #Message m
					WHERE m.HeadlineId = r.HeadlineId AND m.MessageId = r.MessageId
					FOR XML PATH('')
				), 1, 1, ''
			) AS RelatedCustIds
			,STUFF
			(
				(
					SELECT DISTINCT ', ' + CONVERT(VARCHAR(MAX), Username)  
					FROM #Message m
					WHERE m.HeadlineId = r.HeadlineId AND m.MessageId = r.MessageId
					FOR XML PATH('')
				), 1, 1, ''
			) AS RelatedUsernames
			,r.MessageId
			,r.HeadlineId
		FROM CTE_Result r
		
	), CTE_Solution AS (
		SELECT 
			mc.MessageId
			,REPLACE(REPLACE(REPLACE(st.SolutionENSC, '{message_content_en}', mc.Content_EN), '{message_content_sc}', mc.Content_SC), '@@', '') AS SolutionENSC
			,REPLACE(REPLACE(st.SolutionENYN, '{message_content_en}', mc.Content_EN), '@@', '') AS SolutionENYN
		FROM #MessageContent mc 
			INNER JOIN CTE_SolutionTemplate st ON 1 = 1
	)
	INSERT INTO @Result (MessageId, CustId, Description, RelatedCustIds, BettypeIds, SubProductIds,Solution)
	SELECT r.MessageId, r.HeadlineId, l.Description, c.RelatedCustIds, c.BettypeIds, c.SportTypeIds
		 ,CASE WHEN h.SiteLable = '789y' AND h.IsVip = 1 THEN REPLACE(s.SolutionENYN, '{affected_list}', c.RelatedUsernames) 
		  ELSE REPLACE(s.SolutionENSC, '{affected_list}', c.RelatedUsernames) END AS Solution	
		  /*
			Display EN + YN language in case of informing Headlines have:
			Site: 789y (get from mainDB)
			Headline Type: VIP (get from CRM DB)
			Headline doesn't exist in CRM DB yet shall be considered as Normal type.
			If YN language does NOT exist, display EN + SC language.
			For other Headlines / Direct Accounts: Display EN + SC language
		  */
	FROM CTE_Result r
		LEFT JOIN CTE_EventInfo e ON e.MatchId = r.MatchId
		LEFT JOIN CTE_CommonInfo c ON c.HeadlineId = r.HeadlineId AND c.MessageId = r.MessageId
		LEFT JOIN CTE_Solution s ON s.MessageId = r.MessageId
		LEFT JOIN #Headline h ON h.HeadlineId = r.HeadlineId
		OUTER APPLY (
			SELECT 
				'Date Time & Tool:' + FORMAT(DATEADD(HOUR, 12, @Getdate), 'yyyyMMdd/hh:mmtt') + '/' + h.CommunicationNames  + CHAR(13) + CHAR(10)
				+ 'System ID: ' + c.RelatedUsernames AS '@AutoField'
				,'<span style="color: rgb(255, 0, 0);">This is an auto-generated entry.</span><br /><span style="color: rgb(255, 0, 0);">'
				+ 'Msg ID: ' + CONVERT(VARCHAR(20), r.MessageId) + '</span><br /><br />'
				+ 'Date: ' + ISNULL(e.EventDate, '')  + '<br/>' 
				+ 'Sport: ' + ISNULL(e.SportName, '') + '<br/>' 
				+ 'Time: ' + ISNULL(e.KO_time, '') + '<br/>' 
				+ 'Match: ' + ISNULL(e.Match, '') AS '@Remark'
			FOR XML PATH('row'), ROOT('ROOT') 
		) AS l(Description)

	UPDATE r
		SET r.RoleId = CASE c.roleId WHEN 1 THEN 7000
									 WHEN 2 THEN 7001
									 WHEN 3 THEN 7002
									 WHEN 4 THEN 7003
						ELSE 7004 END
			,r.LanguageId = l.LanguageId
	FROM @Result r
		LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custId = r.CustId
		OUTER APPLY (
			SELECT TOP(1) l.LanguageId FROM dbo.crmCustomerLanguage l WITH(NOLOCK) WHERE l.CustId = r.CustId ORDER BY l.LanguageID DESC
		) AS l

	UPDATE r
		SET r.CommunicationIds = h.CommunicationIds
	FROM @Result r
		INNER JOIN #Headline h ON h.HeadlineId = r.CustId 

	/*Setting*/
	DECLARE @SettingResult TABLE (Id INT, SettingId INT, SubSettingId INT, SubSettingIDLevel3 INT)

	;WITH CTE_SettingCommon AS (
		SELECT r.Id, s.SettingId, s.SubSettingId, s.SubSettingIdLevel3
		FROM @Result r
		CROSS APPLY (
			SELECT @StationId AS SettingId, 0 AS SubSettingId, 0 AS SubSettingIdLevel3 --CS Ex./Station
			UNION ALL
			SELECT @CategoryId, @SubCategoryId, 0 -- Category, Sub Category
		) AS s
	), CTE_Product AS (
			SELECT DISTINCT r.Id, @ProductId AS ProductId, ISNULL(sub.value, 0) AS SubProductId, ISNULL(bt.value, 0) AS BettypeId
			FROM @Result r
				OUTER APPLY (SELECT CONVERT(INT, Value) AS Value FROM STRING_SPLIT(r.SubProductIds, ',') sub) sub
				OUTER APPLY (SELECT CONVERT(INT, value) AS Value FROM STRING_SPLIT(r.BettypeIds, ',') AS bt) bt
	), CTE_Communication AS (
			SELECT r.Id, ISNULL(c.Value, 0) AS CommunicationId
			FROM @Result r	
			OUTER APPLY (SELECT CONVERT(INT, Value) AS Value FROM STRING_SPLIT(r.CommunicationIds, ',') c) c
	), CTE_Setting AS (
			SELECT Id, SettingId, SubSettingId, SubSettingIdLevel3
			FROM CTE_SettingCommon
			UNION ALL
			SELECT Id, ProductId, ISNULL(SubProductId, 0), ISNULL(BettypeId, 0) -- Product, Sub-Product, Bet Type
			FROM CTE_Product
			UNION ALL
			SELECT Id, CommunicationId, 0, 0 -- Communication Tool	
			FROM CTE_Communication
	)
	INSERT INTO @SettingResult (id, SettingId, SubSettingId, SubSettingIdLevel3)
	SELECT Id, SettingId, SubSettingId, SubSettingIdLevel3
	FROM CTE_Setting

	SET @Id = 1
	WHILE 1 = 1
	BEGIN
		IF NOT EXISTS (SELECT 1 FROM @Result WHERE ID = @Id)
			BREAK

		INSERT INTO dbo.crmFeedback (CustId,TitleId,Birthday,FirstName,LastName,Phone,PhoneCountryCode,PhoneAreaCode,Phone2
			,Phone2CountryCode,Phone2AreaCode,Phone3,Phone3CountryCode,Phone3AreaCode,MobilePhone,MobilePhoneCountryCode,MobilePhoneAreaCode,Fax
			,FaxCountryCode,FaxAreaCode,Email,Skype,MSN,LanguageId,CountryId,Pic1,Pic2,Pic3,Pic4,Pic1Name,Pic2Name,Pic3Name,Pic4Name,Passport
			,RefCode1,RefCode2,IsVip,CreatorId,CreateDate,Subject,FeedbackDate,ResolutionDate,RoleId,ResponseId,StatusId,Description
			,Solution,IsReviewed,Review,ReviewerId,SiteId,LicenseeType,WhatsApp,Line,WeChat,Yahoo,QQ,BBM,ProvinceId,Inquiries
		)
		SELECT r.CustId, c.TitleId, c.Birthday, c.FirstName, c.LastName, c.Phone, c.PhoneCountryCode, c.PhoneAreaCode, c.Phone2
			,c.Phone2CountryCode, c.Phone2AreaCode, c.Phone3, c.Phone3CountryCode, c.Phone3AreaCode, c.MobilePhone, c.MobilePhoneCountryCode, c.MobilePhoneAreaCode, c.Fax
			,c.FaxCountryCode, c.FaxAreaCode, c.Email, c.Skype, c.MSN, r.LanguageId, c.CountryId, c.Pic1, c.Pic2,c.Pic3,c.Pic4, c.Pic1Name,c.Pic2Name, c.Pic3Name, c.Pic4Name, c.Passport
			,c.RefCode1,c.RefCode2,c.IsVip,@CreatorId AS CreatorId, GETDATE() AS CreateDate, 'Result Amend/Recalculation Notification' AS Subject, @Getdate AS FeedbackDate, DATEADD(MINUTE, 1, @Getdate) AS ResolutionDate,r.RoleId, @ResponseId, @StatusId, r.Description
			,r.Solution, 0 AS IsReviewed, '' AS Review, NULL AS ReviewerId, c.SiteId, c.LicenseeType, c.WhatsApp, c.Line, c.WeChat, c.Yahoo, c.QQ, c.BBM, c.ProvinceId, 0 AS NoInquiries
		FROM @Result r
			INNER JOIN dbo.crmCustomer c WITH(NOLOCK) ON c.CustId = r.CustId
		WHERE r.Id = @Id

		SET @FeedbackId = SCOPE_IDENTITY()

		INSERT INTO dbo.crmFeedbackCustomer (FeedbackId, CustId, IsRelated)
		SELECT @FeedbackId, n.CustId, n.IsRelated
		FROM @Result r	
		CROSS APPLY (
			SELECT value AS CustId, 1 AS IsRelated
			FROM STRING_SPLIT(r.RelatedCustIds, ',') AS l
			WHERE l.value <> r.CustId
			UNION ALL
			SELECT r.CustId, 0 AS IsRelated
		) AS n
		WHERE r.Id = @Id
				
		INSERT INTO dbo.crmFeedbackSetting (FeedbackId, SettingId, SubSettingId, SubSettingIdLevel3)
		SELECT @FeedbackId, SettingId, SubSettingId, SubSettingIdLevel3
		FROM @SettingResult
		WHERE Id = @Id

        -----------------------------------------------------------
        -- BEGIN - Process data for crmFeedbackNewCommunicationTool

        DECLARE @Cust_Id INT
        SELECT  @Cust_Id = r.CustId FROM @Result r INNER JOIN bodb_CRM.dbo.crmCustomer c WITH (NOLOCK) ON c.CustId = r.CustId WHERE r.Id = @Id

        DECLARE @Cust_IsGroupHeadline BIT = 0
        SELECT  @Cust_IsGroupHeadline = ISNULL(IsGroupHeadLine, 0) FROM bodb02.dbo.custAccount WITH (NOLOCK) WHERE custid = @Cust_Id AND IsGroupHeadLine = 1

        IF (@Cust_IsGroupHeadline = 1)
        BEGIN
            ;WITH CTE_HeadlineInfo AS (
                SELECT DISTINCT
                       p.PicID         PicID,
                       p.Username      PicName,
                       sr.SettingValue PicRoleName
                FROM bodb_CRM.dbo.crmPicManagement pm WITH (NOLOCK)
                     LEFT JOIN bodb_CRM.dbo.crmPIC p WITH (NOLOCK) ON pm.PicID = p.PicID
                     LEFT JOIN bodb_CRM.dbo.crmSetting sr WITH (NOLOCK) ON sr.SettingName = 'PICRole' AND p.Role = sr.SettingID
                WHERE pm.HeadlineID = @Cust_Id
            )
            INSERT INTO bodb_CRM.dbo.crmFeedbackNewCommunicationTool (
                FeedbackID,
                CustID,
                isHeadline,
                PicInfo,
                CommunicationID,
                CommunicationValue
            )
            SELECT @FeedbackId                                              FeedbackID,
                   @Cust_Id                                                 CustID,
                   ISNULL(@Cust_IsGroupHeadline, 0)                         isHeadline,
                   ISNULL((cte.PicName + ' (' + cte.PicRoleName + ')'), '') PicInfo,
                   pc.CommunicationID                                       CommunicationID,
                   pc.CommunicationValue                                    PicCommunicationValue
            FROM CTE_HeadlineInfo cte
                 LEFT JOIN bodb_CRM.dbo.crmPICCommunication pc WITH (NOLOCK) ON cte.PicID = pc.PicID
        END
        ELSE
        BEGIN
            INSERT INTO bodb_CRM.dbo.crmFeedbackNewCommunicationTool (
                FeedbackID,
                CustID,
                isHeadline,
                PicInfo,
                CommunicationID,
                CommunicationValue
            )
            SELECT @FeedbackId                      FeedbackID,
                   @Cust_Id                         CustID,
                   ISNULL(@Cust_IsGroupHeadline, 0) isHeadline,
                   ''                               PicInfo,
                   ccc.CommunicationID              CommunicationID,
                   ccc.CommunicationValue           CommunicationValue
            FROM bodb_CRM.dbo.crmCustomerNewCommunicationTool ccc WITH (NOLOCK)
            WHERE ccc.CustID = @Cust_Id
        END

        -- END - Process data for crmFeedbackNewCommunicationTool
        ---------------------------------------------------------

		INSERT INTO dbo.crmFeedbackReference (FeedbackId, ReferenceId, DataSource, CreatedDate)
		SELECT @FeedbackId, MessageId, 'DBMSG.bodb_Message.dbo.Msg', GETDATE()
		FROM @Result
		WHERE Id = @Id

		SET @Id += 1
	END

	UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = CONVERT(VARCHAR(20), @LastMsgTargetId)
	WHERE ServiceName = 'AutoFB - Refund Settled tickets'
		AND SettingName = @SettingNameOfLastMsgTargetId AND ISNULL(@LastMsgTargetId, '') <> 0

	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = 'Completed'
	WHERE ServiceName = 'AutoFB - Refund Settled tickets'
		AND SettingName = @SettingNameOfJobStatus
		AND Value = 'running'

	DROP TABLE #MessageContent
	DROP TABLE #CustHeadline
	DROP TABLE #Headline
	DROP TABLE #Message
	
END
GO

