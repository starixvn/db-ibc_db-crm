/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_AutoFB_AbnormalBets_Import]
	@Message						XML
	,@VoidedCollectionInfo 			XML
	,@MaxVoidingHistoryCollectionId INT
	,@Environment					VARCHAR(50) = ''
	,@ErrCode						INT = 0 OUTPUT
	,@ErrMsg						NVARCHAR(4000) = '' OUTPUT
	,@IP							VARCHAR(45) = ''
AS

/*
	Created: 20240109@Malcolm
	DB: DBCRM-bodb_CRM
	Task: CRM - AutoFB - Abnormal Bets - Import Auto feedback

	Revisions:
		- 20240109@Malcolm: Initialize SPs [RedmineId: #198905]
        - 20240304@Ned.Le: CRM | Missing info in feedback -> Special Notification of abnormal bet incase affected licensee list too long. (HotFix #201768)
        - 20240305@Ned.Le: Remove SABA text for site 777777 [RedmineId : #198905]
		
	Param's Explanation:
		. @Message = 
			'<root>
				<r VoidingHistoryCollectionId="1" MessageId="2" Content_en="Content_en" Content_cs="Content_cs" Content_yn="Content_yn"/>
			</root>'
			
		. @VoidedCollectionInfo = 
			'<root>
				<r VoidingHistoryCollectionId="1" RequestId="1" MessageId="1" IssueTypeId="1" IsParlay="1" RequestBy="" DecidedBy="" VoidBy="" MatchId="" TransIdList="1" ReasonList="" OriginalTransId="" UsernameList=""/>
			</root>'
		
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @LastVoidingHistoryCollectionId INT, @SettingNameOfJobStatus VARCHAR(50) = '',@SettingNameOfLastVoidingHistoryCollectionId VARCHAR(50) = '', @IncludeUUSCurrency BIT, @LastRuntime DATETIME 
			,@SettingNameOfLastRuntime VARCHAR(50) = '' 

	DECLARE @ServerName NVARCHAR(100) = @@SERVERNAME, @DBName NVARCHAR(100) = DB_NAME(), @SPName NVARCHAR(300) = OBJECT_NAME(@@PROCID)

	SELECT @IncludeUUSCurrency = CONVERT(BIT, Value) FROM dbo.SystemSetting WITH(NOLOCK) WHERE ServiceName = 'AutoFB - AbnormalBets' and SettingName = 'IncludeUUSCurrency'
	
	SELECT @Environment	=   ISNULL(@Environment, '')
		   ,@SettingNameOfJobStatus	= CASE WHEN @Environment = 'UAT' THEN 'JobStatusUAT'	ELSE 'JobStatus' END
		   ,@SettingNameOfLastRuntime =	CASE WHEN @Environment = 'UAT' THEN 'LastRuntimeUAT' ELSE 'LastRuntime' END
		   ,@SettingNameOfLastVoidingHistoryCollectionId = CASE WHEN @Environment = 'UAT' THEN 'LastVoidingHistoryCollectionIdUAT' ELSE 'LastVoidingHistoryCollectionId'	END

	DECLARE @FeedbackId INT, @StationId INT, @CategoryId INT, @ProductId INT, @RelatedCustomers NVARCHAR(MAX), @ResponseId INT, @StatusId INT
		   ,@SubCategoryId_AbnormalBets INT,@SubCategoryId INT,@SubCategoryId_AbnormalAccounts INT,@SubCategoryId_DuplicateTickets INT
		   ,@SubProductId_MultipleSports INT, @BettypeId_MixParlay INT, @ProductId_Sportsbook INT
	DECLARE @CreatorId INT = 10278938 -- Starix

	-- Update Job Status
	UPDATE dbo.SystemSetting WITH(ROWLOCK)
		SET Value = 'running'
	WHERE ServiceName = 'AutoFB - AbnormalBets'
		AND SettingName = @SettingNameOfJobStatus
		AND Value = 'Completed'
	
	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @LastRuntime = CONVERT(DATETIME, Value) FROM dbo.SystemSetting WITH(NOLOCK) WHERE SettingName = @SettingNameOfLastRuntime AND ServiceName = 'AutoFB - AbnormalBets'

		IF DATEDIFF(SECOND, @LastRuntime, GETDATE()) >= 5 * 60
		BEGIN
			UPDATE dbo.SystemSetting WITH (ROWLOCK)
			SET Value = 'Completed'
			WHERE ServiceName = 'AutoFB - AbnormalBets'
				AND SettingName = @SettingNameOfJobStatus
				AND Value = 'running'

			--Update LastRuntime
			UPDATE dbo.SystemSetting WITH (ROWLOCK)
			SET Value = CONVERT(VARCHAR(20), GETDATE(), 120)
			WHERE ServiceName = 'AutoFB - AbnormalBets'
				AND SettingName = @SettingNameOfLastRuntime
		END
		ELSE 
		BEGIN
			SELECT @ErrCode = 100, @ErrMsg = 'Server Name : ' + @ServerName + ' - Database Name : ' + @DBName + ' - SP Name : ' + @SPName + ' - Error Message : ' + 'AutoFB - AbnormalBets - Job is running.'
		END	
		RETURN
	END

	--Update LastRuntime
	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = CONVERT(VARCHAR(20), GETDATE(), 120)
	WHERE ServiceName = 'AutoFB - AbnormalBets'
		AND SettingName = @SettingNameOfLastRuntime

	SELECT 
		@ResponseId							= MAX(CASE WHEN SettingName = 'Response'		AND SettingValue = 'Neutral'				THEN SettingId ELSE NULL END) -- Response: Neutral
		,@StatusId							= MAX(CASE WHEN SettingName = 'Status'			AND SettingValue = 'Closed'					THEN SettingId ELSE NULL END) -- Status: Closed
		,@StationId							= MAX(CASE WHEN SettingName = 'Station'			AND SettingValue = 'N/A'					THEN SettingId ELSE NULL END) -- CS Ex./Station: N/A	
		,@CategoryId						= MAX(CASE WHEN SettingName = 'MainCategory'	AND SettingValue = 'Special Notification'	THEN SettingId ELSE NULL END) -- 'Special Notification
		,@SubCategoryId_AbnormalBets		= MAX(CASE WHEN SettingName = 'SubCategory'		AND SettingValue = 'Abnormal Bets'			THEN SettingId ELSE NULL END) -- 'Abnormal Bets'
		,@SubCategoryId_AbnormalAccounts	= MAX(CASE WHEN SettingName = 'SubCategory'		AND SettingValue = 'Abnormal Account'		THEN SettingId ELSE NULL END) -- 'Abnormal Accounts'
		,@SubCategoryId_DuplicateTickets	= MAX(CASE WHEN SettingName = 'SubCategory'		AND SettingValue = 'Duplicate Tickets'		THEN SettingId ELSE NULL END) -- 'Duplicate Tickets'
		,@SubProductId_MultipleSports		= MAX(CASE WHEN SettingName = 'SubProduct'		AND SettingValue = 'Multiple Sports'		THEN SettingId ELSE NULL END) -- 'Multiple Sports'
		,@BettypeId_MixParlay				= MAX(CASE WHEN SettingName = 'Bettype'			AND SettingValue = 'Mix Parlay'				THEN SettingId ELSE NULL END) -- 'Mix Parlay'
		,@ProductId_Sportsbook				= MAX(CASE WHEN SettingName = 'Product'			AND SettingValue = 'Sportsbook'				THEN SettingId ELSE NULL END) -- 'Sportsbook'	
	FROM dbo.crmSetting WITH(NOLOCK)
	WHERE SiteOffer = 2

	DECLARE @AffectedList VARCHAR(MAX) = ''

	CREATE TABLE #CustHeadline (CustId INT, HeadlineId INT, HeadlineName VARCHAR(50))

	CREATE TABLE #Message (VoidingHistoryCollectionId INT, MessageId INT, Content_EN NVARCHAR(4000), Content_SC NVARCHAR(4000), Content_YN NVARCHAR(4000))
	
	INSERT INTO #Message (VoidingHistoryCollectionId, MessageId, Content_EN, Content_SC, Content_YN)
	SELECT 
		t.c.value('@VoidingHistoryCollectionId', 'INT') AS VoidingHistoryCollectionId
		,t.c.value('@MessageId', 'INT') AS MessageId
		,t.c.value('@Content_en', 'NVARCHAR(4000)') AS Content_EN
		,t.c.value('@Content_cs', 'NVARCHAR(4000)') AS Content_SC
		,t.c.value('@Content_yn', 'NVARCHAR(4000)') AS Content_YN
	FROM @Message.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@Message = NULL))

	/*Replace @@ to empty*/
	UPDATE #Message
	SET Content_EN = REPLACE(Content_EN, '@@', '')
		,Content_SC = REPLACE(Content_SC, '@@', '')
		,Content_YN = REPLACE(Content_YN, '@@', '')

	CREATE TABLE #VoidedCollectionInfo 
	(
		VoidingHistoryCollectionId	INT
		,RequestId					INT
		,MessageId					INT
		,TransId					BIGINT
		,CustId						INT
		,Username					VARCHAR(30)
		,Recommend					INT
		,Mrecommend					INT
		,Srecommend					INT
		,Content_en					NVARCHAR(MAX)
		,Content_cs					NVARCHAR(MAX)
		,HeadlineId					INT
		,HeadlineName				VARCHAR(50)
		,GroupName					VARCHAR(50)
		,MainDBSportTypeId			TINYINT
		,MainDBBettypeId			INT
		,MainDBProductId			INT
		,SportTypeId				INT
		,BettypeId					INT
		,ProductId					INT
		,MatchId					INT
		,IsTest						BIT DEFAULT 0
		,IsDeposit					BIT
		,IssueTypeId				TINYINT
		,IsParlay					BIT
		,RelatedCustId				INT
		,SiteName					NVARCHAR(50)
		,RelatedUsername			NVARCHAR(50)
		,RequestedBy				NVARCHAR(MAX)
		,DecidedBy					NVARCHAR(MAX)
		,VoidedBy					NVARCHAR(MAX)
		,UsernameList				NVARCHAR(MAX)
		,WinlostDate				DATETIME
		,OrigTransId				VARCHAR(4000)
	)

	/*Get data of Abnormal Bets, Ab real member, Abnormal Accounts*/
	INSERT INTO #VoidedCollectionInfo 
	(
		VoidingHistoryCollectionId
		,RequestId
		,MessageId
		,IssueTypeId
		,IsParlay
		,RequestedBy
		,DecidedBy
		,VoidedBy
		,MatchId
		,UsernameList
		,TransId
	)
	SELECT DISTINCT  
		t.c.value('@VoidingHistoryCollectionId', 'INT') AS VoidingHistoryCollectionId
		,t.c.value('@RequestId', 'INT') AS RequestId
		,t.c.value('@MessageId', 'INT') AS MessageId
		,t.c.value('@IssueTypeId', 'TINYINT') AS IssueTypeId
		,t.c.value('@IsParlay', 'BIT') AS IsParlay
		,t.c.value('@RequestBy', 'NVARCHAR(MAX)') AS RequestedBy
		,t.c.value('@DecidedBy', 'NVARCHAR(MAX)') AS DecidedBy
		,t.c.value('@VoidBy', 'NVARCHAR(MAX)') AS VoidedBy
		,t.c.value('@MatchId', 'INT') AS MatchId
		,t.c.value('@UsernameList', 'NVARCHAR(MAX)') AS UsernameList
		,n.TransId
	FROM @VoidedCollectionInfo.nodes('root/r') t(c)
	CROSS APPLY (
		SELECT CONVERT(BIGINT, f.value) AS TransId
		FROM STRING_SPLIT(t.c.value('@TransIdList','VARCHAR(MAX)'), ',') AS f
	) AS n
	WHERE t.c.value('@IssueTypeId', 'TINYINT') IN (11, 15, 13)
	OPTION (OPTIMIZE FOR (@VoidedCollectionInfo = NULL))

	/*Duplicated tickets*/
	INSERT INTO #VoidedCollectionInfo 
	(
		VoidingHistoryCollectionId
		,RequestId
		,MessageId
		,IssueTypeId
		,IsParlay
		,RequestedBy
		,DecidedBy
		,VoidedBy
		,MatchId
		,UsernameList
		,TransId
		,OrigTransId
	)
	SELECT DISTINCT  
		t.c.value('@VoidingHistoryCollectionId', 'INT') AS VoidingHistoryCollectionId
		,t.c.value('@RequestId', 'INT') AS RequestId
		,t.c.value('@MessageId', 'INT') AS MessageId
		,t.c.value('@IssueTypeId', 'TINYINT') AS IssueTypeId
		,t.c.value('@IsParlay', 'BIT') AS IsParlay
		,t.c.value('@RequestBy', 'NVARCHAR(MAX)') AS RequestedBy
		,t.c.value('@DecidedBy', 'NVARCHAR(MAX)') AS DecidedBy
		,t.c.value('@VoidBy', 'NVARCHAR(MAX)') AS VoidedBy
		,t.c.value('@MatchId', 'INT') AS MatchId
		,t.c.value('@UsernameList', 'NVARCHAR(MAX)') AS UsernameList
		,n.TransId
		,n.OrigTransId
	FROM @VoidedCollectionInfo.nodes('root/r') t(c)
	CROSS APPLY (SELECT CONVERT(XML, t.c.value('@OriginalTransId', 'NVARCHAR(MAX)')) AS OriginalTransId) AS d
	CROSS APPLY 
	(
		SELECT 
			-- TRY_CONVERT(BIGINT, g.c.value('@OrgTransIds', 'VARCHAR(4000)')) AS OrigTransId
			g.c.value('@OrgTransIds', 'VARCHAR(4000)') AS OrigTransId
			,r.TransId 
		FROM d.OriginalTransId.nodes('root/r') g(c)
			CROSS APPLY(
			SELECT CONVERT(BIGINT, r.value) AS TransId
			FROM STRING_SPLIT (g.c.value('@VoidedTransIds', 'VARCHAR(MAX)'), ',') AS r
			WHERE r.value <> ''
		) AS r 
	 ) AS n
	WHERE t.c.value('@IssueTypeId', 'TINYINT') = 20
	OPTION (OPTIMIZE FOR (@VoidedCollectionInfo = NULL))

	IF NOT EXISTS (SELECT 1 FROM #VoidedCollectionInfo)
	BEGIN
		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = 'Completed'
		WHERE ServiceName = 'AutoFB - AbnormalBets'
			AND SettingName = @SettingNameOfJobStatus
			AND Value = 'running'

		RETURN
	END

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
			,m.MatchId = b.matchid
			,m.WinlostDate = b.winlostdate
	FROM #VoidedCollectionInfo m
	CROSS APPLY (
		SELECT TOP(1) b.TransId, b.custId, b.recommend, b.mrecommend, b.srecommend, b.Username, b.matchId, b.currency, b.bettype, b.winlostdate
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
			,m.MatchId = b.matchid
			,m.WinlostDate = b.winlostdate
	FROM #VoidedCollectionInfo m
	CROSS APPLY (
		SELECT TOP(1) b.TransId, b.custId, b.recommend, b.mrecommend, b.srecommend, b.Username, b.matchId, b.currency, b.bettype, b.winlostdate
		FROM bodb02.dbo.bettrans14 b WITH(NOLOCK)
		WHERE m.TransId = b.TransId
	) AS b
	WHERE m.CustId IS NULL
	
	UPDATE m
		SET m.IsDeposit = CASE WHEN d.custId IS NOT NULL THEN 1 ELSE 0 END
	FROM #VoidedCollectionInfo m
		LEFT JOIN bodb02.dbo.Dep_CustSuper d WITH(NOLOCK) ON d.custId = m.Srecommend
	
	/*Ticket recovered*/
	DELETE #VoidedCollectionInfo WHERE ISNULL(TransId, 0) = 0

	/*Only support deposit for duplicated tickets*/

	DELETE #VoidedCollectionInfo WHERE IsDeposit = 0 AND IssueTypeId = 20
	
	-- Only import testing accounts with uat environment
	IF @Environment = 'UAT'
	BEGIN
		;WITH CTE_RealMessage AS (
			SELECT DISTINCT VoidingHistoryCollectionId FROM #VoidedCollectionInfo WHERE IsTest = 0
		)
		DELETE m 
		FROM #VoidedCollectionInfo m 
			INNER JOIN CTE_RealMessage r ON r.VoidingHistoryCollectionId = m.VoidingHistoryCollectionId
	END

	--Exclude UUS currency with LIVE environment
	IF @Environment = 'LIVE' AND @IncludeUUSCurrency = 0
	BEGIN
		DELETE m FROM #VoidedCollectionInfo m WHERE m.IsTest = 1
	END

	IF NOT EXISTS (SELECT 1 FROM #VoidedCollectionInfo)
	BEGIN
		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = CONVERT(VARCHAR(20), @MaxVoidingHistoryCollectionId)
		WHERE ServiceName = 'AutoFB - AbnormalBets'
			AND SettingName = @SettingNameOfLastVoidingHistoryCollectionId AND ISNULL(@MaxVoidingHistoryCollectionId, 0) <> 0

		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = 'Completed'
		WHERE ServiceName = 'AutoFB - AbnormalBets'
			AND SettingName = @SettingNameOfJobStatus
			AND Value = 'running'

		RETURN
	END

	/*Create fb for headline, all - licensee*/
	-- Credit
	;WITH CTE_Customer AS (
		SELECT DISTINCT CustId FROM #VoidedCollectionInfo WHERE IsDeposit = 0
	)
	SELECT @AffectedList = ISNULL(STRING_AGG(CONVERT(VARCHAR(MAX), CustId), ','), '') FROM CTE_Customer m

	INSERT INTO #CustHeadline(CustId, HeadlineId, HeadlineName)
	EXEC bodb02.dbo.Acc_CRM_GroupHeadlineSel @custIds = @AffectedList	

	-- Deposit
	INSERT INTO #CustHeadline (CustId, HeadlineId, HeadlineName)
	SELECT DISTINCT i.CustId, a.CustID, a.UserName
	FROM #VoidedCollectionInfo i
		CROSS JOIN (SELECT CustID, UserName FROM bodb_CRM.dbo.crmCustomer WITH (NOLOCK) WHERE UserName = 'All-licensees') a
	WHERE i.IsDeposit = 1

	UPDATE m
		SET m.HeadlineId = h.HeadlineId, m.HeadlineName = h.HeadlineName, m.SiteName = IIF(IsDeposit = 0, '', s.site) -- HeadlineName: HeadlineName OR Direct account name
	FROM #VoidedCollectionInfo m
		INNER JOIN #CustHeadline h ON h.CustId = m.CustId
		LEFT JOIN bodb02.dbo.Dep_CustSuper s WITH(NOLOCK) ON s.custid = m.Srecommend
	
	/*Related Customer*/
	BEGIN
		/*For Credit*/
			/*Abnormal Bets, Ab real member*/
			UPDATE v
				SET v.RelatedCustId = CustId, v.RelatedUsername = v.Username
			FROM #VoidedCollectionInfo v
			WHERE IssueTypeId IN (11, 15) AND IsDeposit = 0

			/*Abnormal Accounts*/
			UPDATE v
				SET v.RelatedCustId = n.custid, v.RelatedUsername = n.Username
			FROM #VoidedCollectionInfo v
			CROSS APPLY (
				SELECT CONVERT(VARCHAR(30), f.value) AS Username, c.custid 
				FROM STRING_SPLIT(UsernameList, ',') f	
					INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.username = CONVERT(VARCHAR(30), f.value)
				WHERE c.custid IN (v.CustId, v.Recommend, v.Mrecommend, v.Srecommend)
			) AS n
			WHERE IssueTypeId = 13 AND IsDeposit = 0

		/*For Deposit*/
		UPDATE v
			SET v.RelatedCustId = c.CustID, v.RelatedUsername = c.UserName
		FROM #VoidedCollectionInfo v
			INNER JOIN dbo.crmLicenseeMapping lm WITH(NOLOCK) ON lm.Site = v.SiteName 
			INNER JOIN dbo.crmCustomer c WITH(NOLOCK) ON c.CustID = lm.custid
	END

	DELETE m
	FROM #VoidedCollectionInfo m
		INNER JOIN crmCustomer c WITH(NOLOCK) ON c.CustID = m.HeadlineId
	WHERE c.Ignored = 1

	CREATE TABLE #Headline 
	(
		Id						 INT IDENTITY(1, 1)
		,HeadlineId				 INT
		,HeadlineName			 VARCHAR(30)
		,CommunicationIds		 VARCHAR(MAX)
		,CommunicationNames		 NVARCHAR(MAX)
		,SiteLable				 VARCHAR(20)
		,IsVip					 BIT
		,IsDeposit				 BIT
		,Email_CommunicationName NVARCHAR(MAX)
		,Email_Communicationid	 VARCHAR(MAX)
		,Skype_CommunicationName NVARCHAR(MAX)
		,Skype_Communicationid   VARCHAR(MAX)
	)

	INSERT INTO #Headline (HeadlineId, HeadlineName, IsDeposit)
	SELECT DISTINCT HeadlineId, HeadlineName, IsDeposit
	FROM #VoidedCollectionInfo
	
	/*Get SiteLable, IsVip*/
	UPDATE h 
		SET h.SiteLable = ISNULL(s.SiteLabel, ''), h.IsVip = ISNULL(cr.IsVIP, 0)
	FROM #Headline h 
		INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custId = h.HeadlineId
		INNER JOIN bodb02.dbo.Site s WITH(NOLOCK) ON s.site = c.site
		LEFT JOIN dbo.crmCustomer cr WITH(NOLOCK) ON cr.CustId = h.HeadlineId
	
	/*Get Default Comm Tool*/
	/*
		For Credit : Default Communication of Headline Group / Direct Account Headline Group / Direct Account without default communication shall be set to "N/A"
		For Deposit: 
			+ Skype -- Abnormal Bets, Ab real member, Abnormal Accounts
			+ Email -- Duplicated Tickets
	*/
	DECLARE @Skype_CommunicationId INT, @Email_CommunicationId INT

	SELECT
		@Skype_CommunicationId	= CASE WHEN SettingValue = 'Skype' THEN SettingID ELSE @Skype_CommunicationId END
		,@Email_CommunicationId = CASE WHEN SettingValue = 'Email' THEN SettingID ELSE @Email_CommunicationId END
    FROM bodb_CRM.dbo.crmSetting WITH (NOLOCK)
    WHERE SettingName = 'Communication' AND SiteOffer = 2 AND SettingValue IN ('Skype', 'Email')

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
		WHERE c.DefaultCommID <> 0 AND h.IsDeposit = 0 -- Only get for Credit
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
	WHERE IsDeposit = 0

	UPDATE h
	 SET h.CommunicationNames = n.CommunicationNames
	FROM #Headline h
	CROSS APPLY (
		SELECT STRING_AGG(CONVERT(NVARCHAR(MAX), s.SettingValue), '/') WITHIN GROUP (ORDER BY s.SettingValue ASC) AS CommunicationNames
		FROM STRING_SPLIT(h.CommunicationIds, ',') AS h 
			INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingID = CONVERT(INT, h.value)
	) AS n
	WHERE IsDeposit = 0

	-- For Deposit
	UPDATE #Headline
		SET Skype_Communicationid		= CONVERT(VARCHAR(MAX), @Skype_CommunicationId)
			,Skype_CommunicationName	= 'Skype'
			,Email_Communicationid		= CONVERT(VARCHAR(MAX), @Email_CommunicationId)
			,Email_CommunicationName	= 'Email'
	WHERE IsDeposit = 1
	
	/*Get Sub - Product, Bettype*/
	UPDATE m
		SET m.MainDBSportTypeId = mt.sporttype
	FROM #VoidedCollectionInfo m		
		INNER JOIN bodb02.dbo.match mt WITH(NOLOCK) ON mt.matchId = m.MatchId

	UPDATE m
		SET m.MainDBProductId = n.ProductID
	FROM #VoidedCollectionInfo m
	CROSS APPLY (
		SELECT TOP(1) sp.ProductID
		FROM bodb02.dbo.SportBettypeMatrix sp WITH(NOLOCK)
		WHERE sp.BetType = m.MainDBBettypeId AND sp.SportType = m.MainDBSportTypeId
	) AS n
	
	/*Sub-Product*/
	;WITH CTE_Sporttype AS (
		SELECT m.MainDBSportTypeId, mp.SettingId
		FROM #VoidedCollectionInfo m		
			INNER JOIN bodb02.dbo.Sports s WITH(NOLOCK) ON s.SportType = m.MainDBSportTypeId
			INNER JOIN dbo.crmSettingMapping mp WITH(NOLOCK) ON mp.SettingSource = s.SportName
			INNER JOIN dbo.crmSetting st WITH(NOLOCK) ON st.SettingName = 'SubProduct' AND st.SettingID = mp.SettingID
		GROUP BY m.MainDBSportTypeId, mp.SettingId
	), CTE_Bettype AS (
		/*Bet Type*/ 
		SELECT m.MainDBBettypeId, mp.SettingId
		FROM #VoidedCollectionInfo m		
			INNER JOIN bodb02.dbo.bettype b WITH(NOLOCK) ON b.typeId = m.MainDBBettypeId
			INNER JOIN dbo.crmSettingMapping mp WITH(NOLOCK) ON mp.SettingSource = b.typenamee
			INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingName = 'BetType' AND s.SettingID = mp.SettingID
		GROUP BY m.MainDBBettypeId, mp.SettingId 
	), CTE_Product AS (
		/*Product*/
		SELECT DISTINCT m.MainDBProductId, mp.SettingID
		FROM #VoidedCollectionInfo m
			INNER JOIN bodb02.dbo.Products p WITH(NOLOCK) ON p.ProductID = m.MainDBProductId
			INNER JOIN dbo.crmSettingMapping mp WITH(NOLOCK) ON mp.SettingSource = p.ProductName
			INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingName = 'Product' AND s.SettingID = mp.SettingID
		GROUP BY m.MainDBProductId, mp.SettingId 
	)
	UPDATE m
		SET m.SportTypeId = s.SettingId, m.BettypeId = b.SettingId, m.ProductId = p.SettingID
	FROM #VoidedCollectionInfo m
		LEFT JOIN CTE_Sporttype s ON s.MainDBSportTypeId = m.MainDBSportTypeId
		LEFT JOIN CTE_Bettype b ON b.MainDBBettypeId = m.MainDBBettypeId
		LEFT JOIN CTE_Product p ON p.MainDBProductId = m.MainDBProductId
		

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
						WHERE ServiceName = 'AutoFB - AbnormalBets'
							AND SettingName = @SettingNameOfJobStatus
							AND Value = 'running'

						RETURN;
					END;
				END

				SET @Id += 1
	END
	
	/*Sync Related Customer (Members that placed the affected tickets) to CRM*/
	;WITH CTE_Customer AS (
		SELECT DISTINCT HeadlineId AS CustId, RelatedCustId, RelatedUsername
		FROM #VoidedCollectionInfo
	), CTE_NotExistCustomer AS (
		SELECT c.CustId, c.RelatedCustId, c.RelatedUsername
		FROM CTE_Customer c
			LEFT JOIN dbo.crmCustomer cm WITH(NOLOCK) ON cm.CustID = c.RelatedCustId
		WHERE cm.CustID IS NULL AND ISNULL(c.RelatedCustId, 0) <>  0
	)
	SELECT @RelatedCustomers = (
		SELECT CustId AS '@CustId', RelatedCustId AS '@RelatedCustId', RelatedUsername AS '@Username'
		FROM CTE_NotExistCustomer
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
		WHERE ServiceName = 'AutoFB - AbnormalBets'
			AND SettingName = @SettingNameOfJobStatus
			AND Value = 'running'
		RETURN;
	END;

	DECLARE @Getdate DATETIME = GETDATE()

	DECLARE @Result TABLE 
	(
		Id							INT IdENTITY(1, 1)
		,VoidingHistoryCollectionId INT
		,IssueTypeId				INT
		,IsParlay					BIT
		,IsDeposit					BIT
		,MessageIdList				NVARCHAR(MAX)
		,RequestIdList				NVARCHAR(MAX)
		,RequestByList				NVARCHAR(MAX)
		,DecideByList				NVARCHAR(MAX)
		,VoidedByList				NVARCHAR(MAX)
		,CustId						INT
		,ProductIds					VARCHAR(MAX)
		,SubProductIds				VARCHAR(MAX)
		,BettypeIds					VARCHAR(MAX)
		,RelatedCustIds				VARCHAR(MAX)
		,RelatedUsernames			NVARCHAR(MAX)
		,Description				NVARCHAR(MAX)
		,Solution					NVARCHAR(MAX)
		,RoleId						INT
		,LanguageId					INT
		,CommunicationIds			VARCHAR(MAX)
		,AutoField					NVARCHAR(MAX)
		,msg_ContentEN				NVARCHAR(4000)
		,msg_ContentCS				NVARCHAR(4000)
		,msg_ContentYN				NVARCHAR(4000)
		,StationId					INT
		,CategoryId					INT
		,SubCategoryId				INT
	)

	;WITH CTE_Collection AS (
		SELECT 
			HeadlineId
			,VoidingHistoryCollectionId
			,IsDeposit
			,IssueTypeId
			,IsParlay
		FROM #VoidedCollectionInfo
		GROUP BY HeadlineId, VoidingHistoryCollectionId, IsDeposit, IssueTypeId, IsParlay
	), CTE_MessageList AS (
		SELECT 
			r.HeadlineId
			,r.VoidingHistoryCollectionId
			,r.IsDeposit
			,r.IssueTypeId
			,r.IsParlay
			,STUFF
			(
				(
					SELECT DISTINCT N', ' + CONVERT(NVARCHAR(2000), p.MessageId) 
					FROM #VoidedCollectionInfo p 
					WHERE p.HeadlineId						= r.HeadlineId 
						AND p.VoidingHistoryCollectionId	= r.VoidingHistoryCollectionId 
						AND p.IsDeposit						= r.IsDeposit 
						AND p.IssueTypeId					= r.IssueTypeId 
						AND p.IsParlay						= r.IsParlay
					FOR XML PATH ('')
				), 1, 1, ''
			) AS MessageIdList
			,STUFF
			(
				(
					SELECT DISTINCT N', ' + CONVERT(NVARCHAR(2000), p.RequestId) 
					FROM #VoidedCollectionInfo p 
					WHERE p.HeadlineId						= r.HeadlineId 
						AND p.VoidingHistoryCollectionId	= r.VoidingHistoryCollectionId 
						AND p.IsDeposit						= r.IsDeposit 
						AND p.IssueTypeId					= r.IssueTypeId 
						AND p.IsParlay						= r.IsParlay
					FOR XML PATH ('')
				), 1, 1, ''
			) AS RequestIdList
		FROM CTE_Collection r
	)
	INSERT INTO @Result (VoidingHistoryCollectionId, MessageIdList, RequestIdList, CustId, IssueTypeId, IsParlay, IsDeposit, msg_ContentEN, msg_ContentCS, msg_ContentYN)
	SELECT l.VoidingHistoryCollectionId, l.MessageIdList, l.RequestIdList, l.HeadlineId, l.IssueTypeId, l.IsParlay, l.IsDeposit, m.Content_EN, m.Content_SC, m.Content_YN
	FROM CTE_MessageList l
		LEFT JOIN #Message m ON m.VoidingHistoryCollectionId = l.VoidingHistoryCollectionId

	/*Common Info*/
	;WITH CTE_CommonInfo AS (
	  SELECT 
		STUFF
		(
			(
				SELECT DISTINCT ',' + CONVERT(VARCHAR(MAX), BettypeId)  
				FROM #VoidedCollectionInfo m
				WHERE m.HeadlineId = r.CustId AND m.VoidingHistoryCollectionId = r.VoidingHistoryCollectionId AND m.IsDeposit = r.IsDeposit AND m.IsParlay = r.IsParlay
				FOR XML PATH('')
			), 1, 1, ''
		) AS BettypeIds
		,STUFF
		(
			(
				SELECT DISTINCT ',' + CONVERT(VARCHAR(MAX), SportTypeId)  
				FROM #VoidedCollectionInfo m
				WHERE m.HeadlineId = r.CustId AND m.VoidingHistoryCollectionId = r.VoidingHistoryCollectionId AND m.IsDeposit = r.IsDeposit AND m.IsParlay = r.IsParlay
				FOR XML PATH('')
			), 1, 1, ''
		) AS SportTypeIds
		,STUFF
		(
			(
				SELECT DISTINCT ',' + CONVERT(VARCHAR(MAX), m.ProductId) 
				FROM #VoidedCollectionInfo m
				WHERE m.HeadlineId = r.CustId AND m.VoidingHistoryCollectionId = r.VoidingHistoryCollectionId AND m.IsDeposit = r.IsDeposit AND m.IsParlay = r.IsParlay 
				FOR XML PATH('')
			), 1, 1, ''
		) AS ProductIds 
		,STUFF
		(
			(
				SELECT DISTINCT ',' + CONVERT(VARCHAR(MAX), n.RelatedCustId)  
				FROM #VoidedCollectionInfo m
					CROSS APPLY 
					(
						SELECT m.RelatedCustId	AS RelatedCustId
						UNION ALL
						SELECT m.CustId			AS RelatedCustId
						WHERE m.IssueTypeId = 20 AND IsDeposit = 1
					) AS n
				WHERE m.HeadlineId = r.CustId AND m.VoidingHistoryCollectionId = r.VoidingHistoryCollectionId AND m.IsDeposit = r.IsDeposit AND m.IsParlay = r.IsParlay
				FOR XML PATH('')
			), 1, 1, ''
		) AS RelatedCustIds
		,STUFF
		(
			(
				SELECT DISTINCT ', ' + CONVERT(VARCHAR(MAX), n.RelatedUsername)
				FROM #VoidedCollectionInfo m
					CROSS APPLY 
					(
						SELECT m.RelatedUsername	AS RelatedUsername
						UNION ALL
						SELECT m.Username			AS RelatedUsername
						WHERE m.IssueTypeId = 20 AND IsDeposit = 1
					) AS n
				WHERE m.HeadlineId = r.CustId AND m.VoidingHistoryCollectionId = r.VoidingHistoryCollectionId AND m.IsDeposit = r.IsDeposit AND m.IsParlay = r.IsParlay
				FOR XML PATH('')
			), 1, 1, ''
		) AS RelatedUsername
		,r.Id
		FROM @Result r
	), CTE_RequestInfoDetail AS (
		SELECT DISTINCT n.HeadlineId, n.VoidingHistoryCollectionId, n.IsDeposit, n.IssueTypeId, n.IsParlay, r.RequestBy, d.DecideBy, v.VoidedBy
		FROM (
			SELECT DISTINCT HeadlineId, VoidingHistoryCollectionId, IsDeposit, IssueTypeId, IsParlay, RequestedBy, DecidedBy, VoidedBy
			FROM #VoidedCollectionInfo
		) AS n
		OUTER APPLY (SELECT r.value AS RequestBy FROM STRING_SPLIT (n.RequestedBy, ',') r ) AS r
		OUTER APPLY (SELECT d.value AS DecideBy FROM STRING_SPLIT (n.DecidedBy, ',') AS d) AS d
		OUTER APPLY (SELECT v.value AS VoidedBy FROM STRING_SPLIT (n.VoidedBy, ',') AS v) AS v
	), CTE_RequestInfo AS (
		SELECT 
			Id
			,STUFF
			(
				(
					SELECT DISTINCT N', ' + CONVERT(NVARCHAR(2000), p.RequestBy) 
					FROM CTE_RequestInfoDetail p 
					WHERE p.HeadlineId						= r.CustId 
						AND p.VoidingHistoryCollectionId	= R.VoidingHistoryCollectionId 
						AND p.IssueTypeId					= r.IssueTypeId
						AND p.IsParlay						= r.IsParlay 
						AND p.IsDeposit						= r.IsDeposit
					FOR XML PATH ('')
				), 1, 1, ''
			) AS RequestByList
			,STUFF
			(
				(
					SELECT DISTINCT N', ' + CONVERT(NVARCHAR(2000), p.DecideBy) 
					FROM CTE_RequestInfoDetail p 
					WHERE p.HeadlineId						= r.CustId 
						AND p.VoidingHistoryCollectionId	= R.VoidingHistoryCollectionId 
						AND p.IssueTypeId					= r.IssueTypeId
						AND p.IsParlay						= r.IsParlay 
						AND p.IsDeposit						= r.IsDeposit
					FOR XML PATH ('')
				), 1, 1, ''
			) AS DecideByList
			,STUFF
			(
				(
					SELECT DISTINCT N', ' + CONVERT(NVARCHAR(2000), p.VoidedBy) 
					FROM CTE_RequestInfoDetail p 
					WHERE p.HeadlineId						= r.CustId 
						AND p.VoidingHistoryCollectionId	= R.VoidingHistoryCollectionId 
						AND p.IssueTypeId					= r.IssueTypeId
						AND p.IsParlay						= r.IsParlay 
						AND p.IsDeposit						= r.IsDeposit
					FOR XML PATH ('')
				), 1, 1, ''
			) AS VoidedByList
		FROM @Result r
	) 
	UPDATE r
		SET 
			r.BettypeIds		= n.BettypeIds
			,r.SubProductIds	= n.SportTypeIds
			,r.ProductIds		= n.ProductIds
			,r.RelatedCustIds	= c.RelatedCustIds
			,r.RelatedUsernames = ISNULL(c.RelatedUsername, '')
			,r.RequestByList	= rq.RequestByList
			,r.VoidedByList		= rq.VoidedByList
			,r.DecideByList		= rq.DecideByList
	FROM @Result r	
		INNER JOIN CTE_CommonInfo c ON c.Id = r.Id
		OUTER APPLY (
			SELECT 
				CASE WHEN r.IsParlay = 1 THEN CONVERT(VARCHAR(20), @BettypeId_MixParlay) ELSE c.BettypeIds END AS BettypeIds
				,CASE WHEN r.IsParlay = 1 THEN CONVERT(VARCHAR(20), @SubProductId_MultipleSports) ELSE c.SportTypeIds END AS SportTypeIds
				,CASE WHEN r.IsParlay = 1 OR r.IssueTypeId IN (11, 15, 13) THEN @ProductId_Sportsbook ELSE c.ProductIds END AS ProductIds
		) AS n
		LEFT JOIN CTE_RequestInfo rq ON rq.Id = r.Id

	/*CS Ext./Station / Category / SubCategory*/
	BEGIN
		;WITH CTE_Station AS (
			SELECT @StationId AS StationId, IsParlay, IssueTypeId
			FROM (
				VALUES (0, 11), (1, 11), (0, 15), (0, 13), (0, 20), (1, 20)
			) AS n (IsParlay, IssueTypeId)

		), CTE_Category AS (
			SELECT @CategoryId AS CategoryId, IsParlay, IssueTypeId
			FROM (
				VALUES (0, 11), (1, 11), (0, 15), (0, 13), (0, 20), (1, 20)
			) AS n (IsParlay, IssueTypeId)
		), CTE_SubCategory AS (
			SELECT @SubCategoryId_AbnormalBets AS SubCategoryId, IsParlay, IssueTypeId
			FROM (
				VALUES (0, 11), (1, 11), (0, 15)
			) AS n (IsParlay, IssueTypeId)
			UNION ALL
			SELECT @SubCategoryId_AbnormalAccounts AS SubCategoryId, 0 AS IsParlay, 13 AS IssueTypeId
			UNION ALL
			SELECT @SubCategoryId_DuplicateTickets AS SubCategoryId, IsParlay, IssueTypeId
			FROM (
				VALUES (0, 20), (1, 20)
			) AS n (IsParlay, IssueTypeId)
		)
		UPDATE r
			SET r.StationId = s.StationId, r.CategoryId = c.CategoryId, r.SubCategoryId = sb.SubCategoryId
		FROM @Result r	
			LEFT JOIN CTE_Station s ON r.IssueTypeId = s.IssueTypeId AND r.IsParlay = s.IsParlay
			LEFT JOIN CTE_Category c ON  r.IssueTypeId = c.IssueTypeId AND r.IsParlay = c.IsParlay
			LEFT JOIN CTE_SubCategory sb ON  r.IssueTypeId = sb.IssueTypeId AND r.IsParlay = sb.IsParlay
	END

	-- Get RoleId, LanguageIdSS
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

	/*Solution and Descriptions*/
	BEGIN
		/*Description*/
		/*Credit- Single - Abnormal Bets, Ab real member*/
        CREATE TABLE #tmpSABALeagueGroupID (LeagueGroupID INT)
        INSERT INTO  #tmpSABALeagueGroupID (LeagueGroupID)
        SELECT LeagueGroupID
        FROM bodb02.dbo.f_LeagueGroupConfig()

		CREATE TABLE #Remark (HeadlinId INT, VoidingHistoryCollectionId INT, IsDeposit BIT, IssueTypeId TINYINT, IsParlay BIT, Remark NVARCHAR(MAX))
		;WITH CTE_DescriptionTemplate AS (
			SELECT 
				CONVERT(NVARCHAR(MAX),
					N'<span style="color: rgb(255, 0, 0);">This is an auto-generated entry.</span><br /><span style="color: rgb(255, 0, 0);">'
					+ N'Msg ID: {MessageList}, Request No.: {RequestList}'+ N'</span><br /><br />'
					+ N'{EventInfo}'
			) AS Remark
		), CTE_EventInfo AS (
			-- For IsParlay = 0, Credit only
			SELECT 
					VoidingHistoryCollectionId
					,HeadlineId
					,IssueTypeId
					,IsParlay
					,IsDeposit
					,STRING_AGG
						(
							CONVERT
							(
									NVARCHAR(MAX),
									'Date: ' + FORMAT(mt.eventdate, 'dd-MMM-yyyy') + '<br/>'
								+	'Sport: ' + s.SportName + '<br/>'
								+	'Event Start Time: ' + FORMAT(mt.GlobalShowTime, 'hh:mm tt') + '<br/>'	
								+	'League: ' + CASE WHEN (c.site = '777777' AND lg.LeagueGroupID IS NOT NULL) THEN REPLACE(l.leaguename, 'SABA', '') ELSE l.leaguename END + '<br/>'
								+	'Match: ' + h.teamname + ' -vs- ' + a.teamname + '<br/>'
							),  '--------------------------------------------------<br/>'
						) 
						WITHIN GROUP (ORDER BY mt.eventdate desc, mt.GlobalShowTime DESC, S.SportName DESC) AS matchList
			FROM (
				SELECT DISTINCT VoidingHistoryCollectionId, MatchId, HeadlineId, IssueTypeId, IsParlay, IsDeposit
				FROM  #VoidedCollectionInfo v
				WHERE IsDeposit = 0 AND IssueTypeId IN (11, 15) AND IsParlay = 0
			)m	
				INNER JOIN bodb02.dbo.match mt WITH(NOLOCK) ON mt.matchId = m.MatchId
				INNER JOIN bodb02.dbo.Team h WITH(NOLOCK) ON h.teamId = mt.homeId
				INNER JOIN bodb02.dbo.Team a WITH(NOLOCK) ON a.teamId = mt.awayId
				LEFT JOIN bodb02.dbo.League l WITH(NOLOCK) ON l.leagueid = mt.leagueid
                LEFT JOIN #tmpSABALeagueGroupID lg ON l.LeagueGroupID = lg.LeagueGroupID
				LEFT JOIN bodb02.dbo.Sports s WITH(NOLOCK) ON s.SportType = mt.sporttype
                LEFT JOIN bodb02.dbo.Customer c WITH (NOLOCK) ON m.HeadlineId = c.custid
			GROUP BY VoidingHistoryCollectionId, HeadlineId, IssueTypeId, IsParlay, IsDeposit
		)
		INSERT INTO #Remark (HeadlinId, VoidingHistoryCollectionId, IsDeposit, IssueTypeId, IsParlay, Remark)
		SELECT m.CustId, m.VoidingHistoryCollectionId, m.IsDeposit, m.IssueTypeId, 0 AS IsParlay, n.Remark
		FROM @Result m
			INNER JOIN CTE_EventInfo e 
				ON e.VoidingHistoryCollectionId = m.VoidingHistoryCollectionId AND e.HeadlineId = m.CustId AND e.IssueTypeId = m.IssueTypeId AND e.IsParlay = m.IsParlay AND e.IsDeposit = m.IsDeposit
			CROSS APPLY (
				SELECT REPLACE(REPLACE(REPLACE(Remark, '{MessageList}', ISNULL(m.MessageIdList, '')), '{RequestList}', ISNULL(m.RequestIdList, '')), '{EventInfo}', ISNULL(e.matchList, '')) AS Remark
				FROM CTE_DescriptionTemplate
			) AS n

		/*Credit- Parly - Abnormal Bets, Ab real member*/
		;WITH CTE_DescriptionTemplate AS (
			SELECT 
				CONVERT(NVARCHAR(MAX),
					N'<span style="color: rgb(255, 0, 0);">This is an auto-generated entry.</span><br /><span style="color: rgb(255, 0, 0);">'
					+ N'Msg ID: {MessageList}, Request No.: {RequestList}'+ N'</span><br /><br />'
					+ N'Due to Abnormal Bets, some Mix Parlay tickets were VOIDED.<br/>'
					+ N'Decided By: {DecidedByList}<br/>'
					+ N'Requested By: {RequestedByList}<br/>'
					+ N'Voided By: {VoidedByList}'
			) AS Remark
		)
		INSERT INTO #Remark (HeadlinId, VoidingHistoryCollectionId, IsDeposit, IssueTypeId, IsParlay, Remark)
		SELECT r.CustId, r.VoidingHistoryCollectionId, r.IsDeposit, r.IssueTypeId, r.IsParlay, n.Remark
		FROM @Result r
			CROSS APPLY (
				SELECT 
					REPLACE(
						REPLACE(
							REPLACE(
								REPLACE(
									REPLACE(Remark, '{MessageList}', ISNULL(r.MessageIdList, ''))
								,'{RequestList}', ISNULL(r.RequestIdList, ''))
							,'{DecidedByList}', ISNULL(r.DecideByList, ''))
						,'{RequestedByList}', ISNULL(r.RequestByList, ''))
					,'{VoidedByList}', ISNULL(r.VoidedByList, '')) AS Remark
				FROM CTE_DescriptionTemplate
			) AS n
		WHERE r.IssueTypeId IN (11, 15) AND IsParlay = 1 AND IsDeposit = 0

		/*Deposit - Abnormal Accounts*/
		;WITH CTE_Remark AS (
			SELECT 
				CONVERT(NVARCHAR(MAX), 
					N'<span style="color: rgb(255, 0, 0);">This is an auto-generated entry.</span><br /><span style="color: rgb(255, 0, 0);">'
					+ N'Msg ID: {MessageList}, Request No.: {RequestList}'+ N'</span><br /><br />'
					+ N'Event Date: {EventDateMin} - {EventDateMax}<br/>'
					+ N'Affected accounts: {AffectedUsernames}<br/>'
					+ N'Decided By: {DecidedByList}<br/>'
					+ N'Requested by: {RequestedByList}<br/>'
					+ N'Voided by:{VoidedByList}'
				) AS Remark
				,0 AS IsParlay
				,13 AS IssueType
				,0 AS IsDeposit
		), CTE_EventDate AS (
			SELECT VoidingHistoryCollectionId, HeadlineId, IssueTypeId, IsParlay, IsDeposit, MAX(WinlostDate) AS MaxWinlostDate, MIN(WinlostDate) AS MinWinlostDate
			FROM  #VoidedCollectionInfo
			WHERE IsDeposit = 0 AND IssueTypeId = 13
			GROUP BY VoidingHistoryCollectionId, HeadlineId, IssueTypeId, IsParlay, IsDeposit
		)
		INSERT INTO #Remark (HeadlinId, VoidingHistoryCollectionId, IsDeposit, IssueTypeId, IsParlay, Remark)
		SELECT r.CustId, r.VoidingHistoryCollectionId, r.IsDeposit, r.IssueTypeId, r.IsParlay, n.Remark
		FROM @Result r
			LEFT JOIN CTE_EventDate e 
				ON e.VoidingHistoryCollectionId = r.VoidingHistoryCollectionId AND e.HeadlineId = r.CustId AND e.IssueTypeId = r.IssueTypeId AND e.IsParlay = r.IsParlay AND e.IsDeposit = r.IsDeposit
			OUTER APPLY (
				SELECT 
					REPLACE(
						REPLACE(
							REPLACE(
								REPLACE(
									REPLACE(
										REPLACE(
											REPLACE(
												REPLACE(m.Remark, '{MessageList}', ISNULL(r.MessageIdList, ''))
											,'{RequestList}', ISNULL(r.RequestIdList, ''))
										,'{EventDateMin}', ISNULL(FORMAT(e.MinWinlostDate, 'dd-MMM-yyyy'), ''))
									,'{EventDateMax}', ISNULL(FORMAT(e.MaxWinlostDate, 'dd-MMM-yyyy'), ''))
								,'{AffectedUsernames}', r.RelatedUsernames)
							,'{DecidedByList}', ISNULL(r.DecideByList, ''))
						,'{RequestedByList}', ISNULL(r.RequestByList, ''))
					,'{VoidedByList}', ISNULL(r.VoidedByList, ''))
				FROM CTE_Remark m
			) AS n(Remark)
		WHERE r.IssueTypeId = 13 AND r.IsDeposit = 0 AND r.IsParlay = 0

		/*Deposit - Single/Parlay - Duplicated Tickets*/
		;WITH CTE_Remark AS (
			SELECT 
				CONVERT(NVARCHAR(MAX), 
					N'<span style="color: rgb(255, 0, 0);">This is an auto-generated entry.</span><br /><span style="color: rgb(255, 0, 0);"></span>'
					+ N'Msg ID: {MessageList}, Request No.: {RequestList}<br/>'+
					+ N'Dear Valued Customer,<br/>'
					+ N'Kindly to be informed duplicated tickets found for below event. Those affected tickets, we retained {no_of_tickets} ticket(s) as valid and had proceed to void the duplicate(s). Please refer to the below message:<br/><br/>'
					+ N'Message:<br/>'
					+ N'{en_msg}<br/>'
					+ N'{cs_msg}<br/><br/>'
					+ N'Kindly refer to below on the affected members & tickets.<br/><br/>'
					+ N'{DuplicatedTicketInfo}<br/>'
					+ N'Sorry for the inconvenience caused and thank you for your kind attention!'
				) AS Remark
				,IsParlay
				,IssueType
			FROM (
				VALUES (0, 20), (1, 20)
			) AS n (IsParlay, IssueType)
		), CTE_DuplicatedTicketsInfoDetail AS (
			SELECT HeadlineId, VoidingHistoryCollectionId, IssueTypeId, IsParlay, Username, OrigTransId,
				STRING_AGG(CONVERT(VARCHAR(MAX),TransId), ',') WITHIN GROUP(ORDER BY TransId) AS VoiedTransList
			FROM #VoidedCollectionInfo
			WHERE IssueTypeId = 20 AND IsDeposit = 1
			GROUP BY HeadlineId, VoidingHistoryCollectionId, IssueTypeId, IsParlay, Username, OrigTransId
		), CTE_NoOfTickets AS (
			SELECT d.HeadlineId, d.VoidingHistoryCollectionId, d.IssueTypeId, d.IsParlay, COUNT(DISTINCT TRIM(n.value)) AS no_of_tickets
			FROM CTE_DuplicatedTicketsInfoDetail d
				CROSS APPLY STRING_SPLIT(d.OrigTransId, ',') AS n
			GROUP BY d.HeadlineId, d.VoidingHistoryCollectionId, d.IssueTypeId, d.IsParlay
		), CTE_DuplicatedTicketsInfo AS (
			SELECT d.HeadlineId, d.VoidingHistoryCollectionId, d.IssueTypeId, d.IsParlay, MAX(t.no_of_tickets) AS no_of_tickets,
				STRING_AGG 
				(
					CONVERT
					(
						NVARCHAR(MAX), 
						'System ID: ' + d.Username + '<br/>' 
						+ 'Ref No: ' + ISNULL(CONVERT(VARCHAR(20), TRY_CONVERT(BIGINT, d.OrigTransId)), '') + ' [Remain]<br/>'
						+ 'Ref No: ' + d.VoiedTransList + ' [Voided]<br/>'
					)
					, '<br/>'
				) AS DuplicatedTicketsInfo
			FROM CTE_DuplicatedTicketsInfoDetail d
				LEFT JOIN CTE_NoOfTickets t ON t.HeadlineId = d.HeadlineId AND t.VoidingHistoryCollectionId = d.VoidingHistoryCollectionId AND t.IssueTypeId = d.IssueTypeId AND t.IsParlay = d.IsParlay
			GROUP BY d.HeadlineId, d.VoidingHistoryCollectionId, d.IssueTypeId, d.IsParlay
		)
		INSERT INTO #Remark (HeadlinId, VoidingHistoryCollectionId, IsDeposit, IssueTypeId, IsParlay, Remark)
		SELECT r.CustId, r.VoidingHistoryCollectionId, r.IsDeposit, r.IssueTypeId, r.IsParlay, n.Remark
		FROM CTE_DuplicatedTicketsInfo e
			INNER JOIN @Result r 
				ON  r.VoidingHistoryCollectionId = e.VoidingHistoryCollectionId AND r.CustId = e.HeadlineId AND r.IssueTypeId = e.IssueTypeId AND r.IsParlay = e.IsParlay AND r.IsDeposit = 1
			OUTER APPLY (
				SELECT 
					REPLACE(
						REPLACE(
							REPLACE(
								REPLACE(
									REPLACE(
										REPLACE(m.Remark, '{MessageList}', ISNULL(r.MessageIdList, ''))
									,'{RequestList}', ISNULL(r.RequestIdList, ''))
								,'{no_of_tickets}', ISNULL(CONVERT(VARCHAR(20), e.no_of_tickets), ''))
							,'{en_msg}', ISNULL(r.msg_ContentEN, ''))
						,'{cs_msg}', ISNULL(r.msg_ContentCS, ''))
					,'{DuplicatedTicketInfo}', ISNULL(e.DuplicatedTicketsInfo, '')) AS Remark
				FROM CTE_Remark m
				WHERE m.IssueType = e.IssueTypeId AND m.IsParlay = e.IsParlay
			) AS n

		/*Deposit - Abnormal Bets, AB real member*/
		;WITH CTE_DescriptionTemplate AS (
			SELECT 
				-- For single tickets (Abnormal Bets, Ab real Member)
				CONVERT(NVARCHAR(MAX), 
					N'<span style="color: rgb(255, 0, 0);">This is an auto-generated entry.</span><br /><span style="color: rgb(255, 0, 0);">'
					+ N'Msg ID: {MessageList}, Request No.: {RequestList}'+ N'</span><br />'
					+ N'Announcement sent to affected Licensees and informed our related department found abnormal tickets of members for the match.<br/><br/>'
					+ N'Please refer to the system email subject "Voided Bets Report" for those affected customers & tickets for reference.'
				) AS Remark
				,IsParlay
				,IssueTypeId
			FROM (
				VALUES (0, 11), (0, 15)
			) AS n (IsParlay, IssueTypeId)
			UNION ALL
			SELECT 
				-- For Parlay Tickets (Abnormal Bets, Ab real Member)
				CONVERT(NVARCHAR(MAX),
					N'<span style="color: rgb(255, 0, 0);">This is an auto-generated entry.</span><br /><span style="color: rgb(255, 0, 0);">'
					+ N'Msg ID: {MessageList}, Request No.: {RequestList}'+ N'</span><br /><br />'
					+ N'Announcement sent to affected Licensees and informed our related department found tickets of abnormal accounts.<br/>'
					+ N'Please refer to the system email subject "Voided Bets Report" for those affected customers & tickets for reference.'
				) AS Remark
				,IsParlay
				,IssueTypeId
			FROM (
				VALUES (1, 11), (1, 15)
			) AS n (IsParlay, IssueTypeId)
			UNION ALL
			SELECT 
				-- For single tickets (Abnormal Bets, Ab real Member)
				CONVERT(NVARCHAR(MAX), 
					N'<span style="color: rgb(255, 0, 0);">This is an auto-generated entry.</span><br /><span style="color: rgb(255, 0, 0);">'
					+ N'Msg ID: {MessageList}, Request No.: {RequestList}'+ N'</span><br />'
					+ N'Announcement sent to affected Licensees and informed our related department found tickets of abnormal accounts.<br/><br/>'
					+ N'Please refer to the system email subject "Voided Bets Report" for those affected customers & tickets for reference.'
				) AS Remark
				,0 AS IsParlay
				,13 AS IssueTypeId
		)
		INSERT INTO #Remark (HeadlinId, VoidingHistoryCollectionId, IsDeposit, IssueTypeId, IsParlay, Remark)
		SELECT r.CustId, r.VoidingHistoryCollectionId, r.IsDeposit, r.IssueTypeId, r.IsParlay, n.Remark
		FROM @Result r
		CROSS APPLY (
			SELECT REPLACE(REPLACE(Remark, '{MessageList}', ISNULL(r.MessageIdList, '')),'{RequestList}', ISNULL(r.RequestIdList, '')) AS Remark
			FROM CTE_DescriptionTemplate d
			WHERE d.IssueTypeId = r.IssueTypeId AND d.IsParlay = r.IsParlay
		) n
		WHERE r.IssueTypeId IN (11, 15, 13) AND IsDeposit = 1

		/*Solution*/
		CREATE TABLE #Solution (HeadlinId INT, VoidingHistoryCollectionId INT, IsDeposit BIT, IssueTypeId TINYINT, IsParlay BIT, Solution NVARCHAR(MAX))
		;WITH CTE_SolutionTemplate AS (
			/*Credit - Abnormal Bets, Ab real member*/
			SELECT 
				CONVERT(NVARCHAR(MAX),
					N'{EN Announcement}<br/><br/>'
					+ N'{CN Announcement}<br><br/>'
					+ N'Kindly refer to Agency site "Cancelled Bets" for Voided user.<br><br/>'
					+ N'Affected users and tickets:<br>'
					+ N'{AfftectedInfo}'
				) AS Solution_ENSC
				,'' AS Solution_ENYN
				,IsDeposit
				,IsParlay
				,IssueTypeId
			FROM (
				VALUES (0, 0, 11), (0, 0, 15)
			) AS n (IsDeposit, IsParlay, IssueTypeId)
			UNION ALL
			/*Credit - Parlay - Ab normal Bets*/
			SELECT 
				CONVERT(NVARCHAR(MAX),
					N'Dear Sir, Customer service would like to inform that your member have abnormal bet, affected ticket has been VOIDED. Thank you.<br/><br/>'
					+ N'{EN Announcement}<br/><br/>'
					+ N'Kindly refer to Agency site ""Cancelled Bets"" for Voided user.<br/><br/>'
					+ N'您好, 客服部在此通知您, 公司发现您旗下会员有非正常投注. 注單已被作廢. 謝謝!<br/><br/>'
					+ N'{SC Announcement}<br><br/>'
					+ N'请浏览代理网 “已删除/作废注单” 查询有关作废账号.<br/><br/>'
					+ N'Affected user/受影响会员:<br/>'
					+ N'{AfftectedInfo}'
				) AS Solution_ENSC
				,CONVERT(NVARCHAR(MAX),
					N'Dear Sir, Customer service would like to inform that your member have abnormal bet, affected ticket has been VOIDED. Thank you.<br/>'
					+ N'Xin chào, bộ phận Dịch vụ Khách hàng của chúng tôi xin thông báo rằng thành viên của bạn có cá cược bất thường, do đó vé cược đã bị vô hiệu hoá. Xin cảm ơn.<br/><br/>'
					+ N'{EN Announcement}<br/><br/>'
					+ N'Kindly refer to Agency site "Cancelled Bets" for Voided user.<br/>'
					+ N'Vui lòng tham khảo thông tin bổ sung tại mục "Cược bị huỷ" trên trang web đại lý cho phần "Vô hiệu hoá".<br/><br/>'
					+ N'Affected user/Danh sách khách hàng:<br/>'
					+ N'{AfftectedInfo}'
				) AS Solution_ENYN
				,0 AS IsDeposit
				,1 AS IsParlay
				,11 AS IssueType
			UNION ALL
			/*Credit - Abnormal Accounts*/
			SELECT CONVERT(NVARCHAR(MAX),
					N'{EN Announcement}<br/>'
					+ N'{CN Announcement}<br/><br/>'
					+ N'Kindly refer to agency site "Cancelled Bets" for Voided user.'
				) AS Solution_ENSC
				,'' AS Solution_ENYN
				,0 AS IsDeposit
				,0 AS IsParlay
				,13 AS IssueType
			UNION ALL
			SELECT
			/*Deposit - Abnormal Bets, AB real member, Abnormal Accounts*/
				CONVERT(NVARCHAR(MAX),
					N'{EN Announcement}<br/><br/>'
					+ N'{CN Announcement}'
				) AS Solution_ENSC
				,'' AS Solution_ENYN
				,n.IsDeposit
				,n.IsParlay
				,n.IssueType
			FROM (
				VALUES (1, 0, 11), (1, 1, 11), (1, 0, 15), (1, 0, 13)
			) AS n(IsDeposit, IsParlay, IssueType)
			/*Deposit - Duplicated Tickets*/
			UNION ALL
			SELECT 
				'Sent done' AS Solution_ENSC
				,'' AS Solution_ENYN
				,n.IsDeposit
				,n.IsParlay
				,n.IssueType
			FROM (
				VALUES (1, 1, 20), (1, 0, 20)
			)  AS n(IsDeposit, IsParlay, IssueType) 
		), CTE_AffectedInfo AS (
			SELECT
				r.Id
				,k.AfftectedInfo
			FROM @Result r
			CROSS APPLY (
				SELECT STRING_AGG (CONVERT(NVARCHAR(MAX), n.Username + ' ' + CONVERT(VARCHAR(50), n.TransId)), '<br/>') AS AfftectedInfo
				FROM 
				(
					SELECT DISTINCT m.HeadlineId, m.VoidingHistoryCollectionId, m.IsDeposit, m.IsParlay, CASE WHEN r.IsParlay = 1 THEN '- ' ELSE '' END + m.Username AS Username, m.TransId
					FROM #VoidedCollectionInfo m
					WHERE m.HeadlineId = r.CustId AND m.VoidingHistoryCollectionId = r.VoidingHistoryCollectionId AND m.IsDeposit = r.IsDeposit AND m.IsParlay = r.IsParlay
				) AS n
			) as k
			WHERE r.IssueTypeId IN (11, 15)	
		)
		INSERT INTO #Solution 
		(
			HeadlinId
			,VoidingHistoryCollectionId
			,IsDeposit
			,IssueTypeId
			,IsParlay
			,Solution
		)
		SELECT 
			r.CustId
			,r.VoidingHistoryCollectionId
			,r.IsDeposit
			,r.IssueTypeId
			,r.IsParlay
			,CASE WHEN h.SiteLable = '789y' AND h.IsVip = 1 AND r.IssueTypeId = 11 AND r.IsDeposit = 0 AND r.IsParlay = 1 THEN n_ENYN.Solution 
			 ELSE n_ENSC.Solution END AS Solution
		FROM @Result r
			LEFT JOIN #Headline h ON h.headlineId = r.CustId
			LEFT JOIN CTE_AffectedInfo a ON a.Id = r.Id
			OUTER APPLY (
				SELECT 
					REPLACE(
						REPLACE(
							REPLACE(
								REPLACE(s.Solution_ENSC, '{EN Announcement}', ISNULL(r.msg_ContentEN, ''))
							,'{CN Announcement}', ISNULL(r.msg_ContentCS, ''))
						,'{SC Announcement}', ISNULL(r.msg_ContentCS, ''))
					,'{AfftectedInfo}', ISNULL(a.AfftectedInfo, '')) AS Solution
				FROM CTE_SolutionTemplate s
				WHERE s.IssueTypeId = r.IssueTypeId AND s.IsParlay = r.IsParlay AND r.IsDeposit = s.IsDeposit
			) AS n_ENSC
			OUTER APPLY (
				SELECT 
					REPLACE(
						REPLACE(s.Solution_ENYN, '{EN Announcement}', ISNULL(r.msg_ContentEN, ''))
					,'{AfftectedInfo}', ISNULL(a.AfftectedInfo, '')) AS Solution
				FROM CTE_SolutionTemplate s
				WHERE s.IssueTypeId = r.IssueTypeId AND s.IsParlay = r.IsParlay AND r.IsDeposit = s.IsDeposit
			) AS n_ENYN
		WHERE r.IssueTypeId IN (11, 15, 20, 13)

		UPDATE r
			SET r.AutoField = n.AutoField
				,r.CommunicationIds = ci.CommunicationIds
		FROM @Result r	
			LEFT JOIN #Headline h ON h.HeadlineId = r.CustId
			OUTER APPLY (
				SELECT 
					N'Date Time & Tool: ' + FORMAT(DATEADD(HOUR, 12, @Getdate), 'yyyyMMdd/hh:mmtt') + '/' 
					+ CASE WHEN r.IsDeposit = 1 AND r.IssueTypeId = 20 THEN h.Email_CommunicationName
						   WHEN r.IsDeposit = 1 AND r.IssueTypeId IN (11, 15, 13) THEN h.Skype_CommunicationName
					  ELSE ISNULL(h.CommunicationNames, '') END 
					+ CHAR(13) + CHAR(10)
					+ N'System ID: ' + ISNULL(r.RelatedUsernames, '')
			) AS n(AutoField)
			OUTER APPLY (
				SELECT CASE WHEN r.IsDeposit = 1 AND r.IssueTypeId = 20 THEN h.Email_Communicationid
							WHEN r.IsDeposit = 1 AND r.IssueTypeId IN (11, 15, 13) THEN h.Skype_Communicationid
					   ELSE h.CommunicationIds END AS CommunicationIds
			) AS ci

		-- Get Description
		UPDATE r
			SET r.Description = n.Description
		FROM @Result r
			LEFT JOIN #Remark rm 
				ON  rm.HeadlinId = r.CustId AND rm.VoidingHistoryCollectionId = r.VoidingHistoryCollectionId AND rm.IsDeposit = r.IsDeposit AND rm.IsParlay = r.IsParlay AND rm.IssueTypeId = r.IssueTypeId
		OUTER APPLY (
			SELECT r.AutoField AS '@AutoField', rm.Remark AS '@Remark' 
			FOR XML PATH('row'), ROOT('ROOT') 
		) AS n (Description)

		-- Get Solution
		UPDATE r
			SET r.Solution = rm.Solution
		FROM @Result r
			LEFT JOIN #Solution rm 
				ON  rm.HeadlinId = r.CustId AND rm.VoidingHistoryCollectionId = r.VoidingHistoryCollectionId AND rm.IsDeposit = r.IsDeposit AND rm.IsParlay = r.IsParlay AND rm.IssueTypeId = r.IssueTypeId
	END

	/*Setting*/
	DECLARE @SettingResult TABLE (Id INT, SettingId INT, SubSettingId INT, SubSettingIDLevel3 INT)

	;WITH CTE_SettingCommon AS (
		SELECT r.Id, s.SettingId, s.SubSettingId, s.SubSettingIdLevel3
		FROM @Result r
		CROSS APPLY (
			SELECT StationId AS SettingId, 0 AS SubSettingId, 0 AS SubSettingIdLevel3 --CS Ex./Station
			UNION ALL
			SELECT CategoryId, SubCategoryId, 0 -- Category, Sub Category
		) AS s
	), CTE_Product AS (
			SELECT DISTINCT r.Id, ISNULL(pr.Value, 0) AS ProductId, ISNULL(sub.value, 0) AS SubProductId, ISNULL(bt.value, 0) AS BettypeId
			FROM @Result r
				OUTER APPLY (SELECT CONVERT(INT, Value) AS Value FROM STRING_SPLIT(r.SubProductIds, ',') sub) sub
				OUTER APPLY (SELECT CONVERT(INT, value) AS Value FROM STRING_SPLIT(r.BettypeIds, ',') AS bt) bt
				OUTER APPLY (SELECT CONVERT(INT, value) AS Value FROM STRING_SPLIT(r.ProductIds, ',') AS bt) pr
	), CTE_Communication AS (
			SELECT r.Id, ISNULL(c.Value, 0) AS CommunicationId
			FROM @Result r	
			OUTER APPLY (SELECT CONVERT(INT, Value) AS Value FROM STRING_SPLIT(r.CommunicationIds, ',') c) c
	), CTE_Setting AS (
			SELECT Id, SettingId, SubSettingId, SubSettingIdLevel3
			FROM CTE_SettingCommon
			UNION ALL
			SELECT Id, ISNULL(ProductId, 0), ISNULL(SubProductId, 0), ISNULL(BettypeId, 0) -- Product, Sub-Product, Bet Type
			FROM CTE_Product
			UNION ALL
			SELECT Id, CommunicationId, 0, 0 -- Communication Tool	
			FROM CTE_Communication
	)
	INSERT INTO @SettingResult (id, SettingId, SubSettingId, SubSettingIdLevel3)
	SELECT Id, ISNULL(SettingId, 0), ISNULL(SubSettingId, 0), ISNULL(SubSettingIdLevel3, 0)
	FROM CTE_Setting

	SET @Id = 1
	WHILE 1 = 1
	BEGIN
		IF NOT EXISTS (SELECT 1 FROM @Result WHERE ID = @Id)
			BREAK

		INSERT INTO dbo.crmFeedback 
		(
			CustId
			,TitleId
			,Birthday
			,FirstName
			,LastName
			,Phone
			,PhoneCountryCode
			,PhoneAreaCode
			,Phone2
			,Phone2CountryCode
			,Phone2AreaCode
			,Phone3
			,Phone3CountryCode
			,Phone3AreaCode
			,MobilePhone
			,MobilePhoneCountryCode
			,MobilePhoneAreaCode
			,Fax
			,FaxCountryCode
			,FaxAreaCode
			,Email
			,Skype
			,MSN
			,LanguageId
			,CountryId
			,Pic1
			,Pic2
			,Pic3
			,Pic4
			,Pic1Name
			,Pic2Name
			,Pic3Name
			,Pic4Name
			,Passport
			,RefCode1
			,RefCode2
			,IsVip
			,CreatorId
			,CreateDate
			,Subject
			,FeedbackDate
			,ResolutionDate
			,RoleId
			,ResponseId
			,StatusId
			,Description
			,Solution
			,IsReviewed
			,Review
			,ReviewerId
			,SiteId
			,LicenseeType
			,WhatsApp
			,Line
			,WeChat
			,Yahoo
			,QQ
			,BBM
			,ProvinceId
			,Inquiries
		)
		SELECT 
			r.CustId
			,c.TitleId
			,c.Birthday
			,c.FirstName
			,c.LastName
			,c.Phone
			,c.PhoneCountryCode
			,c.PhoneAreaCode
			,c.Phone2
			,c.Phone2CountryCode
			,c.Phone2AreaCode
			,c.Phone3
			,c.Phone3CountryCode
			,c.Phone3AreaCode
			,c.MobilePhone
			,c.MobilePhoneCountryCode
			,c.MobilePhoneAreaCode
			,c.Fax
			,c.FaxCountryCode
			,c.FaxAreaCode
			,c.Email
			,c.Skype
			,c.MSN
			,r.LanguageId
			,c.CountryId
			,c.Pic1
			,c.Pic2
			,c.Pic3
			,c.Pic4
			,c.Pic1Name
			,c.Pic2Name
			,c.Pic3Name
			,c.Pic4Name
			,c.Passport
			,c.RefCode1
			,c.RefCode2
			,c.IsVip
			,@CreatorId AS CreatorId
			,GETDATE() AS CreateDate
			,'Special Notification' AS Subject
			,@Getdate AS FeedbackDate, DATEADD(MINUTE, 1, @Getdate) AS ResolutionDate
			,r.RoleId
			,@ResponseId
			,@StatusId
			,r.Description
			,r.Solution
			,0 AS IsReviewed
			,'' AS Review
			,NULL AS ReviewerId
			,c.SiteId
			,c.LicenseeType
			,c.WhatsApp
			,c.Line
			,c.WeChat
			,c.Yahoo
			,c.QQ
			,c.BBM
			,c.ProvinceId
			,0 AS NoInquiries
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
			WHERE l.value <> r.CustId AND ISNULL(l.value, '') <> '' 
			UNION ALL
			SELECT r.CustId, 0 AS IsRelated
		) AS n
		WHERE r.Id = @Id
				
		INSERT INTO dbo.crmFeedbackSetting (FeedbackId, SettingId, SubSettingId, SubSettingIdLevel3)
		SELECT @FeedbackId, SettingId, SubSettingId, SubSettingIdLevel3
		FROM @SettingResult
		WHERE Id = @Id

		INSERT INTO dbo.crmFeedbackReference (FeedbackId, ReferenceId, DataSource, CreatedDate)
		SELECT @FeedbackId, f.Messageid, 'DBMSG.bodb_Message.dbo.Msg', GETDATE()
		FROM @Result r
		OUTER APPLY (	
			SELECT value AS Messageid FROM STRING_SPLIT (r.MessageIdList, ',') f
		) f
		WHERE Id = @Id

		SET @Id += 1
	END

	UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = CONVERT(VARCHAR(20), @MaxVoidingHistoryCollectionId)
	WHERE ServiceName = 'AutoFB - AbnormalBets'
		AND SettingName = @SettingNameOfLastVoidingHistoryCollectionId AND ISNULL(@MaxVoidingHistoryCollectionId, '') <> 0

	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = 'Completed'
	WHERE ServiceName = 'AutoFB - AbnormalBets'
		AND SettingName = @SettingNameOfJobStatus
		AND Value = 'running'

	DROP TABLE #CustHeadline
	DROP TABLE #Headline
	DROP TABLE #Message
    DROP TABLE #tmpSABALeagueGroupID
	DROP TABLE #Remark
	DROP TABLE #Solution
	DROP TABLE #VoidedCollectionInfo
	
END
GO

