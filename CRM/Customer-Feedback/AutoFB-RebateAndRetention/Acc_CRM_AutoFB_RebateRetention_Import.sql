/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_AutoFB_RebateRetention_Import]  
	@XmlData	 XML,
	@NewLogSID	 XML,
	@Environment VARCHAR(50)    = '',
	@ErrCode	 INT            = 0  OUTPUT,
	@ErrMsg		 NVARCHAR(4000) = '' OUTPUT,
	@IP          VARCHAR(45)    = ''
AS

/*
    Created: 20241111@Virgil
    DB: DBCRM-bodb_CRM
    Task: CRM - Auto create feedback for Rebate & Retention [RedmineID: #210688]

    Revisions:
        - 20241111@Virgil: Initialize SP [RedmineID: #210688]
		- 20251201@Dave: CRM - Notification for Rebate and Retention - Implement Batch-Based Processing [RedmineID: #245494]

    Param's Explanation:
		- @XmlData: <root>
						<r SID = "201" SiteDBGroupID="3" CustId="81944297" Recommend="11760526" Mrecommend="4174" Srecommend="2" AffectedMember="A68M09N 200 RM" IsTest="0" />
						<r SID = "201" SiteDBGroupID="3" CustId="82084466" Recommend="11760526" Mrecommend="4174" Srecommend="2" AffectedMember="A68M09O 200 RM" IsTest="0" />
						<r SID = "201" SiteDBGroupID="3" CustId="117835198" Recommend="117835197" Mrecommend="117835196" Srecommend="117835195" AffectedMember="supertestte7770M0M000 200.75 UUS" IsTest="1" />
					</root>
		- @NewLogSID: <root>
						  <r LastLogSID="201" SiteDBGroupId="3" ListPendingSIDs=""/>
						</root>
*/
BEGIN

    SET NOCOUNT ON

    ---------------------------
    -- [01] Global variables --

    DECLARE @CreatorId				  INT         = 10278938
    DECLARE @ServiceName			  VARCHAR(50) = 'AutoFB - RebateRetention'

    DECLARE @IncludeUUSCurrency		  BIT
    SELECT  @IncludeUUSCurrency		  = CONVERT(BIT, Value) FROM bodb_CRM.dbo.SystemSetting WITH (NOLOCK) WHERE ServiceName = @ServiceName AND SettingName = 'IncludeUUSCurrency'

    DECLARE @SettingNameOfLastRuntime VARCHAR(50)
    SELECT  @SettingNameOfLastRuntime = CASE WHEN @Environment = 'UAT' THEN 'LastRuntimeUAT' ELSE 'LastRuntime' END
    DECLARE @LastRuntime			  DATETIME
    SELECT  @LastRuntime			  = CONVERT(DATETIME, Value) FROM bodb_CRM.dbo.SystemSetting WITH (NOLOCK) WHERE SettingName = @SettingNameOfLastRuntime AND ServiceName = @ServiceName

    DECLARE @SettingNameOfJobStatus   VARCHAR(50)
    SELECT  @SettingNameOfJobStatus   = CASE WHEN @Environment = 'UAT' THEN 'JobStatusUAT' ELSE 'JobStatus' END
    
    DECLARE @SettingNameOfLastLogSId  VARCHAR(50)
    SELECT  @SettingNameOfLastLogSId  = CASE WHEN @Environment = 'UAT' THEN 'LastLogSIdUAT' ELSE 'LastLogSId' END

    ---------------------------------------------
    -- [02] Check and update some job settings --

    -- Declare variables
    DECLARE @ServerName NVARCHAR(100) = @@SERVERNAME
    DECLARE @DBName     NVARCHAR(100) = DB_NAME()
    DECLARE @SPName     NVARCHAR(300) = OBJECT_NAME(@@PROCID)

    -- Update status to running
    UPDATE s
    SET s.Value = 'Running'
    FROM bodb_CRM.dbo.SystemSetting s WITH (ROWLOCK)
    WHERE s.ServiceName = @ServiceName
          AND s.SettingName = @SettingNameOfJobStatus
          AND s.Value = 'Completed'

    -- If nothing happened, it means job is already running and we need to do something else
    IF (@@ROWCOUNT = 0)
    BEGIN
        -- + Check if the job run for more than 5mi
        IF (DATEDIFF(SECOND, @LastRuntime, GETDATE()) >= 5 * 60)
        BEGIN
            UPDATE s
            SET s.Value = 'Completed'
            FROM bodb_CRM.dbo.SystemSetting s WITH (ROWLOCK)
            WHERE s.ServiceName = @ServiceName
                  AND s.SettingName = @SettingNameOfJobStatus
                  AND s.Value = 'Running'

            UPDATE s
            SET s.Value = CONVERT(VARCHAR(20), GETDATE(), 120)
            FROM bodb_CRM.dbo.SystemSetting s WITH (ROWLOCK)
            WHERE s.ServiceName = @ServiceName
                  AND s.SettingName = @SettingNameOfLastRuntime
        END
        -- + If not, it means the job still running and still not over 5mi
        ELSE
        BEGIN
            SELECT @ErrCode = 100
            SELECT @ErrMsg = 'Server Name: ' + @ServerName + ' - Database Name: ' + @DBName + ' - SP Name: ' + @SPName + ' - Error Message: ' + @ServiceName + ' - Job is running.'
        END
        -- + Return
        RETURN
    END

    -- Update LastRuntime
    UPDATE s
    SET s.Value = CONVERT(VARCHAR(20), GETDATE(), 120)
    FROM bodb_CRM.dbo.SystemSetting s WITH (ROWLOCK)
    WHERE s.ServiceName = @ServiceName
          AND s.SettingName = @SettingNameOfLastRuntime


    -------------------------
    -- [03] Parse XML data --

    -- Create temp table and parse XML data
    CREATE TABLE #tmpXMLData (
        [SID]           INT,
		SiteDBGroupID	SMALLINT,
		CustId			INT,
		Recommend		INT,
		Mrecommend		INT,
		Srecommend		INT,
		AffectedMember	VARCHAR(100),
		IsTest			BIT
    )
    INSERT INTO #tmpXMLData([SID], SiteDBGroupID, CustId, Recommend, Mrecommend, Srecommend, AffectedMember, IsTest)
    SELECT
		t.c.value('@SID',           'INT')		    AS SID,
		t.c.value('@SiteDBGroupID', 'SMALLINT')		AS SiteDBGroupID,
        t.c.value('@CustId',		'INT')			AS CustId,
        t.c.value('@Recommend',		'INT')			AS Recommend,
        t.c.value('@Mrecommend',	'INT')			AS Mrecommend,
        t.c.value('@Srecommend',	'INT')			AS Srecommend,
        t.c.value('@AffectedMember','VARCHAR(100)') AS AffectedMember,
        t.c.value('@IsTest',		'BIT')			AS IsTest
    FROM @XmlData.nodes('root/r') t(c)
    OPTION (OPTIMIZE FOR (@XmlData = NULL))

    -- If nothing happened, need to update setting and return
    IF (@@ROWCOUNT = 0)
    BEGIN

		UPDATE s
        SET s.Value = CAST(@NewLogSID AS VARCHAR(300))
        FROM bodb_CRM.dbo.SystemSetting s WITH(ROWLOCK, UPDLOCK)
        WHERE s.ServiceName = @ServiceName
                AND s.SettingName = @SettingNameOfLastLogSID

        UPDATE s
        SET s.Value = 'Completed'
        FROM bodb_CRM.dbo.SystemSetting s WITH(ROWLOCK, UPDLOCK)
        WHERE s.ServiceName = @ServiceName
                AND s.SettingName = @SettingNameOfJobStatus
                AND s.Value = 'Running'

        RETURN
    END

	-- Only import testing accounts with uat environment
	IF @Environment = 'UAT'
	BEGIN
		DELETE i FROM #tmpXMLData i WHERE i.IsTest = 0
	END
	-- Exclude UUS currency with LIVE environment
	IF @Environment = 'LIVE' AND @IncludeUUSCurrency = 0
	BEGIN
		DELETE i FROM #tmpXMLData i WHERE i.IsTest = 1
	END

	-- Break down XMLData to get LastLogSID of each SiteDBGroupId for ReferenceId column of table dbo.crmFeedbackReference
	CREATE TABLE #NewLogSID (
        LastLogSID		SMALLINT,
        SiteDBGroupId	SMALLINT,
        ListPendingSIDs VARCHAR(MAX)
    )
    INSERT INTO #NewLogSID (LastLogSID, SiteDBGroupId, ListPendingSIDs)
    SELECT
        t.c.value('@LastLogSID', 'SMALLINT')				AS LastLogSID,
        t.c.value('@SiteDBGroupId', 'SMALLINT')				AS SiteDBGroupId,
        t.c.value('@ListPendingSIDs', 'VARCHAR(MAX)')		AS ListPendingSIDs
    FROM @NewLogSID.nodes('root/r') t(c)
    OPTION (OPTIMIZE FOR (@NewLogSID = NULL))

	----------------------------------------------------------------------------------------------
    -- [04] Base on SMA and member information, we collect headline information                 --
    ----------------------------------------------------------------------------------------------

    -- + Create temp table
    CREATE TABLE #tmpHeadlineData (
        CustId            INT,
        HeadlineId        INT,
        HeadlineName      NVARCHAR(50),
        HeadlineSite      NVARCHAR(50),
        HeadlineSiteLabel NVARCHAR(50),
        IsVip             BIT
    )

    -- + Get list of custid
    DECLARE @ListCustId NVARCHAR(MAX)

    ;WITH CTE_CustId AS (
        SELECT DISTINCT CustId FROM #tmpXMLData
    )
    SELECT @ListCustId = ISNULL(STRING_AGG(CONVERT(VARCHAR(MAX), CustId), ','), '') 
	FROM CTE_CustId

    -- + Gen data to temp table
    INSERT INTO #tmpHeadlineData (CustId, HeadlineId, HeadlineName)
    EXEC bodb02.dbo.Acc_CRM_GroupHeadlineSel @custIds = @ListCustId

    -- + Update value for temp table
    UPDATE h
    SET h.HeadlineSite      = c.site,
        h.HeadlineSiteLabel = s.SiteLabel,
        h.IsVip             = ISNULL(cr.IsVIP, 0)
    FROM #tmpHeadlineData h
		LEFT JOIN bodb02.dbo.Dep_CustSuper d WITH (NOLOCK)	
			ON h.HeadlineId = d.custid
		LEFT JOIN bodb02.dbo.Customer c WITH (NOLOCK)
			ON h.CustId = c.custid
		LEFT JOIN bodb02.dbo.Site s WITH (NOLOCK) 
			ON c.site = s.site
		LEFT JOIN bodb_CRM.dbo.crmCustomer cr WITH (NOLOCK) 
			ON h.HeadlineId = cr.CustID


    -- + Delete ignored data
    -- + --> for #tmpHeadlineData
    DELETE h
    FROM #tmpHeadlineData h
	INNER JOIN bodb_CRM.dbo.crmCustomer c WITH (NOLOCK) 
		ON c.CustID = h.HeadlineId
    WHERE c.Ignored = 1


	-- + Create index
    CREATE CLUSTERED INDEX CIX_CustId ON #tmpHeadlineData(CustId)

	-----------------------------------------------
    -- [05] Sync data from maindb to crmCustomer --

    -- Sync Headline
    -- + Declare variables
    DECLARE @SyncHeadline_Id       INT = 1
    DECLARE @SyncHeadline_CustId   INT
    DECLARE @SyncHeadline_Username NVARCHAR(50)

    -- + Create temp table and gen data
    CREATE TABLE #tmpSyncHeadline (
		Id INT IDENTITY(1, 1),
		HeadlineId INT,
		HeadlineName NVARCHAR(50)
	)
    INSERT INTO  #tmpSyncHeadline (HeadlineId, HeadlineName)
	SELECT DISTINCT HeadlineId, HeadlineName 
	FROM #tmpHeadlineData

    -- + Run the loop to sync data
    WHILE EXISTS (SELECT 1 FROM #tmpSyncHeadline WHERE Id = @SyncHeadline_Id)
    BEGIN
        -- + --> Set value for some variables
        SELECT @SyncHeadline_CustId   = HeadlineId,
               @SyncHeadline_Username = HeadlineName
        FROM #tmpSyncHeadline
        WHERE Id = @SyncHeadline_Id

        -- + --> Run sp to sync data
        IF NOT EXISTS (SELECT 1 FROM bodb_CRM.dbo.crmCustomer WITH (NOLOCK) WHERE CustId = @SyncHeadline_CustID) AND @SyncHeadline_CustId IS NOT NULL
        BEGIN
            EXECUTE bodb_CRM.dbo.Acc_CRM_CustomerIns_New @UserId                 = @CreatorId,
                                                         @CustId                 = @SyncHeadline_CustId,
                                                         @UserName               = @SyncHeadline_Username,
                                                         @FirstName              = NULL,
                                                         @LastName               = NULL,
                                                         @TitleId                = NULL,
                                                         @Birthday               = NULL,
                                                         @LanguageId             = 0,
                                                         @Phone                  = NULL,
                                                         @PhoneCountryCode       = NULL,
                                                         @PhoneAreaCode          = NULL,
                                                         @Phone2                 = NULL,
                                                         @Phone2CountryCode      = NULL,
                                                         @Phone2AreaCode         = NULL,
                                                         @Phone3                 = NULL,
                                                         @Phone3CountryCode      = NULL,
                                                         @Phone3AreaCode         = NULL,
                                                         @MobilePhone            = NULL,
                                                         @MobilePhoneCountryCode = NULL,
                                                         @MobilePhoneAreaCode    = NULL,
                                                         @Fax                    = NULL,
                                                         @FaxCountryCode         = NULL,
                                                         @FaxAreaCode            = NULL,
                                                         @Email                  = NULL,
                                                         @Passport               = NULL,
                                                         @BettingCode            = NULL,
                                                         @RefCode2               = NULL,
                                                         @Skype                  = NULL,
                                                         @MSN                    = NULL,
                                                         @CountryId              = NULL,
                                                         @IsVIP                  = 0,
                                                         @SiteId                 = NULL,
                                                         @CreatorId              = @CreatorId,
                                                         @LicenseeType           = NULL,
                                                         @WhatsApp               = NULL,
                                                         @Line                   = NULL,
                                                         @WeChat                 = NULL,
                                                         @Yahoo                  = NULL,
                                                         @QQ                     = NULL,
                                                         @BBM                    = NULL,
                                                         @IP                     = @IP,
                                                         @Pic1                   = NULL,
                                                         @Pic2                   = NULL,
                                                         @Pic3                   = NULL,
                                                         @Pic4                   = NULL,
                                                         @ProvinceId             = NULL,                    
                                                         @ErrCode                = @ErrCode OUTPUT,
                                                         @ErrMsg                 = @ErrMsg  OUTPUT

            IF (@ErrCode <> 0)
            BEGIN
                SET @ErrMsg  = ISNULL(@ErrMsg, '') + ' - ' +
                               'Insert failed: Acc_CRM_CustomerIns_New [CustId='    + ISNULL(CONVERT(VARCHAR(20), @SyncHeadline_CustId), '') + ',' +
                                                                       'Username='  + ISNULL(@SyncHeadline_Username, '')                     + ',' +
                                                                       'CreatorId=' + ISNULL(CONVERT(VARCHAR(20), @CreatorId), '')           + ',' +
                                                                       'IP='        + ISNULL(CONVERT(VARCHAR(20), @IP), '')                  + ']'

                UPDATE s
                SET s.Value = 'Completed'
                FROM bodb_CRM.dbo.SystemSetting s WITH (ROWLOCK)
                WHERE s.ServiceName = @ServiceName
                      AND s.SettingName = @SettingNameOfJobStatus
                      AND s.Value = 'Running'

                RETURN
            END
        END

        -- + --> Continue the loop
        SET @SyncHeadline_Id += 1
    END

	-- Sync Member
    -- + Declare variables
    DECLARE @RelatedCustomers NVARCHAR(MAX)
    ;WITH
    CTE_Data AS (
        SELECT DISTINCT
               h.HeadlineId CustId,
               h.CustId     RelatedCustId,
               b.Username   Username
        FROM #tmpHeadlineData h
			JOIN bodb02.dbo.Customer b ON h.CustId = b.CustId
    )
    SELECT @RelatedCustomers = (
        SELECT CustId        AS '@CustId',
               RelatedCustId AS '@RelatedCustId',
               Username      AS '@Username'
        FROM CTE_Data
        FOR XML PATH ('Row'), ROOT('ROOT')
    )

    -- + Run sp to sync data
    EXECUTE bodb_CRM.dbo.Acc_CRM_AmendmentNoti_MultiCustIns @RelatedCustomers = @RelatedCustomers,
                                                            @UserId           = @CreatorId,
                                                            @CreatorId        = @CreatorId,
                                                            @IP               = @IP,
                                                            @ErrCode          = @ErrCode OUTPUT,
                                                            @ErrMsg           = @ErrMsg  OUTPUT

    IF (@ErrCode <> 0)
    BEGIN
        SET @ErrCode = 101
        SET @ErrMsg  = ISNULL(@ErrMsg, '') + ' - ' +
                       'Insert failed: Acc_CRM_AmendmentNoti_MultiCustIns [RelatedCustomers=' + ISNULL(@RelatedCustomers, '')                + ',' +
                                                                          'CreatorId='        + ISNULL(CONVERT(VARCHAR(20), @CreatorId), '') + ',' +
                                                                          'IP='               + ISNULL(@IP, '')                              + ']'

        UPDATE s
        SET s.Value = 'Completed'
        FROM bodb_CRM.dbo.SystemSetting s WITH (ROWLOCK)
        WHERE s.ServiceName = @ServiceName
              AND s.SettingName = @SettingNameOfJobStatus
              AND s.Value = 'Running'

        RETURN
    END

	-----------------------------------------------------------------------------------------------------------------
    -- [06] Collect necessary data to prepare for creating Feedback                                                --
    --      _ Base on the requirement to create Feedback we divide them into group and collect data for each group --
    --      _ Group 01, fixed information                                                                          --
    --      _ Group 02, base information																		   --
    -----------------------------------------------------------------------------------------------------------------

    -- Group 01, Feedback fixed information > From spec
    --                                      > We can know Feedback's field that info is fixed
    --                                      > And we just collect data for them first
    DECLARE @Feedback_Date			 DATETIME     = GETDATE()
	DECLARE @Feedback_ResolutionDate DATETIME     = DATEADD(MINUTE, 1, @Feedback_Date)
	DECLARE @Feedback_Subject		 VARCHAR(200) = 'Special Notification'
	DECLARE @Feedback_StationId		 INT
	DECLARE @Feedback_CategoryId	 INT
	DECLARE @Feedback_SubCategoryId  INT
	DECLARE @Feedback_ProductId		 INT
	DECLARE @Feedback_SubProductId	 INT
	DECLARE @Feedback_BettypeId		 INT
	DECLARE @Feedback_StatusId       INT
	DECLARE @Feedback_ResponseId     INT

	SELECT  @Feedback_StationId     = MAX(CASE WHEN SettingName = 'Station'      AND SettingValue = 'N/A'					THEN SettingId ELSE NULL END),
			@Feedback_CategoryId    = MAX(CASE WHEN SettingName = 'MainCategory' AND SettingValue = 'Special Notification'	THEN SettingId ELSE NULL END),
			@Feedback_SubCategoryId = MAX(CASE WHEN SettingName = 'SubCategory'  AND SettingValue = 'Credit Reward'			THEN SettingId ELSE NULL END),
			@Feedback_ProductId     = MAX(CASE WHEN SettingName = 'Product'      AND SettingValue = 'N/A.'					THEN SettingId ELSE NULL END),
			@Feedback_SubProductId	= MAX(CASE WHEN SettingName = 'SubProduct'	 AND SettingValue = 'N/A.'					THEN SettingId ELSE NULL END),
			@Feedback_BettypeId		= MAX(CASE WHEN SettingName = 'Bettype'		 AND SettingValue = 'N/A.'					THEN SettingId ELSE NULL END),
			@Feedback_StatusId      = MAX(CASE WHEN SettingName = 'Status'       AND SettingValue = 'Closed'				THEN SettingId ELSE NULL END),
			@Feedback_ResponseId    = MAX(CASE WHEN SettingName = 'Response'     AND SettingValue = 'Neutral'				THEN SettingId ELSE NULL END)
	FROM bodb_CRM.dbo.crmSetting WITH (NOLOCK)
	WHERE SiteOffer = 2

	-- Group 02, Feedback base information > For each HeadlineId we will create one Feedback
    --                                     > We collect list_relatecust|list_subproduct|list_bettype belong to each Feedback
    --                                     > We also collect info about communicationtool|role|language|country belong to each Feedback
    -- + Get Cust data
    -- + --> Create temp table
    CREATE TABLE #tmpFeedback_base_cust (
        [SID]           INT,
		SiteDBGroupID	SMALLINT,
        HeadlineId      INT,
        Supername		VARCHAR(50),
        RelatedCustId   VARCHAR(MAX),
        RelatedUsername NVARCHAR(MAX),
        MappingCustId   INT,
		AffectedMember	VARCHAR(100)
    )
    -- + --> Gen credit data to temp table
    INSERT INTO #tmpFeedback_base_cust (
        [SID],
		SiteDBGroupID,
        HeadlineId,
		Supername,
        RelatedCustId,
        RelatedUsername,
        MappingCustId,
		AffectedMember
    )
    SELECT DISTINCT
            b.SID,
			b.SiteDBGroupID  SiteDBGroupID,
			h.HeadlineId	 HeadlineId,
			sup.username	 Supername,
            b.CustId		 RelatedCustId,
            c.Username		 RelatedUsername,
            b.CustId		 MappingCustId,
			b.AffectedMember AffectedMember 
    FROM #tmpXMLData b
	INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK)
		ON b.custid = c.CustId
	INNER JOIN bodb02.dbo.Customer sup WITH(NOLOCK) 
		ON c.srecommend = sup.custid 
		AND sup.roleid = 4
    INNER JOIN #tmpHeadlineData h 
		ON b.CustId = h.CustId


	-- + Get final data
    -- + --> Create temp table
    CREATE TABLE #tmpFeedback_base (
        Id                 INT IDENTITY(1, 1),
        [SID]              INT,
		SiteDBGroupID	   SMALLINT,
        HeadlineId         INT,
        RelatedCustIds     VARCHAR(MAX),
        RelatedUsernames   NVARCHAR(MAX),
		AffectedList	   NVARCHAR(MAX),
        CommunicationIds   VARCHAR(MAX),
        CommunicationNames NVARCHAR(MAX),
        RoleId             INT,
        LanguageId         INT,
        CountryId          INT
    )
	-- + --> Gen aggregated data to temp table| De code them phan tuong minh va de hieu
    --										  | O day ta chia data thanh tung cum aggregate khac nhau roi cuoi cung join chung lai voi nhau
    --										  | Viec nay se phat sinh them nhieu CTE va lam code hoi dai dong nhung de hieu
	;WITH
		CTE_cust AS (
			SELECT [SID],
                    SiteDBGroupID,
					HeadlineId,
					STRING_AGG(CAST(RelatedCustId AS VARCHAR(MAX)), ',') AS RelatedCustIds,
					STRING_AGG(CAST(RelatedUsername AS VARCHAR(MAX)), ', ') WITHIN GROUP (ORDER BY RelatedUsername ASC) AS RelatedUsernames
			FROM (
				SELECT DISTINCT [SID], SiteDBGroupID, HeadlineId, RelatedCustId, RelatedUsername
				FROM #tmpFeedback_base_cust
			) c
			GROUP BY [SID], SiteDBGroupID, HeadlineId
		),
		CTE_Group_AggregatedData_AffectedList_RemoveDuplicate AS (
			SELECT DISTINCT
                    [SID],
					SiteDBGroupID,
					HeadlineId,
					AffectedMember,
					Supername
			FROM #tmpFeedback_base_cust
		),
		CTE_Group_AggregatedData_AffectedList_Username AS (
			SELECT [SID],
                    SiteDBGroupID,
					HeadlineId,
					Supername,
					STRING_AGG(CAST(AffectedMember AS VARCHAR(MAX)), ', ') UsernameList
			FROM CTE_Group_AggregatedData_AffectedList_RemoveDuplicate
			GROUP BY [SID],
                    SiteDBGroupID,
					HeadlineId,
					Supername
		),
		CTE_Group_AggregatedData_AffectedList AS (
			SELECT [SID],
                    SiteDBGroupID,
					HeadlineId,
					STRING_AGG(CAST(('- ' + Supername + ': ' + UsernameList) AS VARCHAR(MAX)), '<br/>') AffectedList
			FROM CTE_Group_AggregatedData_AffectedList_Username
			GROUP BY [SID],SiteDBGroupID, HeadlineId
		)
	INSERT INTO #tmpFeedback_base (
        [SID],
		SiteDBGroupID,
        HeadlineId,
        RelatedCustIds,
        RelatedUsernames,
		AffectedList
    )
	SELECT X.[SID],
            X.SiteDBGroupID,
			X.HeadlineId,
			X.RelatedCustIds,
			X.RelatedUsernames,
			Y.AffectedList
	FROM CTE_cust X
	LEFT JOIN CTE_Group_AggregatedData_AffectedList Y
		ON X.HeadlineId = Y.HeadlineId
		AND X.SiteDBGroupID = Y.SiteDBGroupID
        AND X.SID = Y.SID;


	-- + Update CommunicationIds
    -- + --> For Credit Model (base on setting)
    ;WITH
    CTE_Headline AS (
        SELECT DISTINCT HeadlineId
        FROM #tmpHeadlineData
    ),
    CTE_Setting AS (
        SELECT c.DefaultCommID,
               c.CustID,
               STRING_AGG(IIF(c.SettingType = 1, CONVERT(VARCHAR(MAX), c.SettingId), NULL), ',') WITHIN GROUP (ORDER BY c.SettingId ASC) AS Categorystr,
               STRING_AGG(IIF(c.SettingType = 2, CONVERT(VARCHAR(MAX), c.SettingId), NULL), ',') WITHIN GROUP (ORDER BY c.SettingId ASC) AS SubCategorystr,
               STRING_AGG(IIF(c.SettingType = 3, CONVERT(VARCHAR(MAX), c.SettingId), NULL), ',') WITHIN GROUP (ORDER BY c.SettingId ASC) AS CommunicationIds
        FROM bodb_CRM.dbo.crmDefaultCommTool c WITH (NOLOCK)
        LEFT JOIN bodb_CRM.dbo.crmSetting se WITH (NOLOCK) 
			ON c.SettingID = se.SettingID
        WHERE c.CustID IN (SELECT HeadlineId FROM CTE_Headline)
              AND c.DefaultCommID <> 0
        GROUP BY c.DefaultCommId,
                 c.CustID
    ),
    CTE_CommTool AS (
        SELECT CustID,
                CommunicationIds,
                CASE WHEN Categorystr = CONVERT(VARCHAR(20), @Feedback_CategoryId) THEN 1
                    WHEN ',' + Categorystr + ',' LIKE '%,0,%' THEN 2 
                    ELSE 3 
				END AS Category_MappedLevel,
                CASE WHEN SubCategorystr = CONVERT(VARCHAR(20), @Feedback_SubCategoryId) THEN 1
                    WHEN ',' + SubCategorystr + ',' LIKE '%,0,%' THEN 2
                    ELSE 3 
				END AS SubCategory_MappedLevel
        FROM CTE_Setting
    )
    UPDATE h
    SET h.CommunicationIds = ISNULL(df.CommunicationIds, '1005') --CommunicationIds=1005 : N/A
    FROM #tmpFeedback_base h
    OUTER APPLY (
		SELECT TOP (1)
				CASE 
					WHEN c.Category_MappedLevel = 3 OR c.SubCategory_MappedLevel = 3 THEN '1005' 
					ELSE c.CommunicationIds 
				END AS CommunicationIds
		FROM CTE_CommTool c
		WHERE c.CustID = h.HeadlineId
		ORDER BY c.Category_MappedLevel ASC,
				c.SubCategory_MappedLevel ASC
	) df


    -- + Update CommunicationNames
    UPDATE h
    SET h.CommunicationNames = n.CommunicationNames
    FROM #tmpFeedback_base h
    CROSS APPLY (
		SELECT STRING_AGG(CONVERT(VARCHAR(MAX), s.SettingValue), '/') WITHIN GROUP (ORDER BY s.SettingValue ASC) AS CommunicationNames
		FROM STRING_SPLIT(h.CommunicationIds, ',') AS h
		INNER JOIN bodb_CRM.dbo.crmSetting s WITH (NOLOCK) 
			ON s.SettingID = CONVERT(INT, h.value)
	) AS n

    -- + Update RoleId|LanguageId|CountryId
    UPDATE h
    SET h.RoleId = CASE c.roleid WHEN 1 THEN 7000
                                 WHEN 2 THEN 7001
                                 WHEN 3 THEN 7002
                                 WHEN 4 THEN 7003
                                 ELSE 7004 END,
        h.LanguageId = l.LanguageId,
        h.CountryId = cr.CountryID
    FROM #tmpFeedback_base h
    LEFT JOIN bodb_CRM.dbo.crmCustomer cr WITH (NOLOCK) 
		ON h.HeadlineId = cr.CustID
    OUTER APPLY (
		SELECT TOP (1) l.LanguageId 
		FROM bodb_CRM.dbo.crmCustomerLanguage l WITH (NOLOCK) 
		WHERE l.CustID = h.HeadlineId 
		ORDER BY l.LanguageID DESC
	) l
    LEFT JOIN bodb02.dbo.Customer c WITH (NOLOCK) 
		ON h.HeadlineId = c.custid
    LEFT JOIN bodb02.dbo.Site s WITH (NOLOCK) 
		ON c.site = s.site

    -- + Create index
    CREATE NONCLUSTERED INDEX IX_Id ON #tmpFeedback_base(Id)

	----------------------------------------------------------------------------------------------------------
    -- [07] Create Feedback                                                                                 --
    --      _ Description and Solution are two most complicated fields and we need spend more time for them --
    --      _ When everything is ready, we run the loop to create Feedback                                  --
    ----------------------------------------------------------------------------------------------------------

    -- Declare variables
    DECLARE @Id         INT = 1
    DECLARE @FeedbackId INT

    DECLARE @CustId          INT
    DECLARE @IsGroupHeadLine BIT = 0

    -- Build Feedback Description
    -- + Create temp table
    CREATE TABLE #tmpFeedback_description (
        [SID]           INT,
		SiteDBGroupID	SMALLINT,
        HeadlineId		INT,
        Description		NVARCHAR(MAX)
    )
	-- + Gen data for credit model
    INSERT INTO #tmpFeedback_description (
        [SID],
		SiteDBGroupID,
        HeadlineId,
        Description
    )
    SELECT b.[SID],
            b.SiteDBGroupID,
			b.HeadlineId,
			d.Description
    FROM #tmpFeedback_base b
    OUTER APPLY (
		SELECT (
					'Date Time & Tool: ' + FORMAT(DATEADD(HOUR, 12, @Feedback_Date), 'yyyyMMdd/hh:mmtt') + '/' + ISNULL(b.CommunicationNames, '') + CHAR(13) + CHAR(10)
					+ 'System ID: ' + ISNULL(b.RelatedUsernames, '')
				) AS '@AutoField'
				,
				(
					'<span style="color: rgb(255, 0, 0);">This is an auto-generated entry.</span><br/>'
					+ 'Announcement sent to Headline and informed our related department rewarded their member.'
				) AS '@Remark'
		FOR XML PATH('row'), ROOT('ROOT')
	) AS d(Description)

	-- Build Feedback solution
    -- + Create temp table
    CREATE TABLE #tmpFeedback_solution (
        [SID]           INT,
		SiteDBGroupID	SMALLINT,
        HeadlineId		INT,
        Solution		NVARCHAR(MAX)
    )
    -- + Gen data for credit model
    ;WITH
    CTE_Headline AS (
        SELECT DISTINCT HeadlineId, HeadlineSiteLabel, IsVip
        FROM #tmpHeadlineData
    ),
    CTE_Template AS (
        SELECT CONVERT(NVARCHAR(MAX), N'Dear Sir,/尊敬的先生，<br/>'
                                    + N'Below is the list of Members who have received rewards from the company:<br/>' 
                                    + N'以下是获得公司奖励的会员名单：<br/>'
									+ N'Super & Member: <br/>'
									+ N'超级总代理和会员：<br/>'
									+ N'{Affected List}<br/>' 
                                    + N'The company is responsible for all relevant Reward amounts. Kindly refer to the "Reward Detail" for details and assist in distributing the funds to your downlines.<br/>'
                                    + N'公司负责所有奖励金额。请参阅“奖励详情”了解详情，并协助将金额分配给您的下线。<br/><br/>'
									+ N'Thank you for your kind attention!<br/>'
									+ N'感谢您的关注！') AS SolutionENCS,
               CONVERT(NVARCHAR(MAX), N'Dear Sir,/Xin chào quý khách,<br/>'
									+ N'Below is the list of Members who have received rewards from the company:<br/>'
									+ N'Dưới đây là danh sách các Member nhận tiền thưởng từ công ty:<br/>'
									+ N'Super & Member: <br/>'
									+ N'{Affected List}<br/>' 
                                    + N'The company is responsible for all relevant Reward amounts. Kindly refer to the "Reward Detail" for details and assist in distributing the funds to your downlines.<br/>'
                                    + N'Công ty sẽ chi trả toàn bộ số tiền thưởng này. Quý khách vui lòng xem thêm "Chi tiết tiền thưởng" để biết thêm thông tin và hỗ trợ phân phối tiền thưởng đến các cấp dưới của mình.<br/><br/>'
									+ N'Thank you for your kind attention!<br/>'
									+ N'Xin cảm ơn sự hợp tác của Quý khách!') AS SolutionENYN
    )
    INSERT INTO #tmpFeedback_solution (
        [SID],
		SiteDBGroupID,
		HeadlineId,
		Solution
    )
    SELECT b.[SID],
            b.SiteDBGroupID,
			b.HeadlineId,
			CASE WHEN h.HeadlineSiteLabel = '789y' AND h.IsVip = 1 THEN REPLACE(t.SolutionENYN, '{Affected List}', b.AffectedList)
				ELSE REPLACE(t.SolutionENCS, '{Affected List}', b.AffectedList) 
			END Solution
    FROM #tmpFeedback_base b
    LEFT JOIN CTE_Headline h ON b.HeadlineId = h.HeadlineId
    CROSS JOIN CTE_Template t

	-- Run the loop to process data
    WHILE EXISTS (SELECT 1 FROM #tmpFeedback_base WHERE Id = @Id)
    BEGIN
        -- + Insert data to table crmFeedback
        INSERT INTO bodb_CRM.dbo.crmFeedback (
            CustID,
            TitleID,
            FirstName,
            LastName,
            Phone,
            MobilePhone,
            Fax,
            Email,
            LanguageID,
            CountryID,
            CreateDate,
            CreatorID,
            FeedbackDate,
            SolveDate,
            CommunicationID,
            StationID,
            MainCategoryID,
            SubCategoryID,
            SiteID,
            RoleID,
            ProductID,
            BetTypeID,
            ResponseID,
            StatusID,
            Description,
            Solution,
            IsReviewed,
            Review,
            ReviewerID,
            Subject,
            Skype,
            MSN,
            ResolutionDate,
            Pic1,
            Pic2,
            Pic3,
            PhoneCountryCode,
            PhoneAreaCode,
            Phone2,
            Phone2CountryCode,
            Phone2AreaCode,
            Phone3,
            Phone3CountryCode,
            Phone3AreaCode,
            MobilePhoneCountryCode,
            MobilePhoneAreaCode,
            FaxCountryCode,
            FaxAreaCode,
            Pic4,
            Passport,
            Line1,
            Line2,
            Line3,
            City,
            Postcode,
            State,
            BankLine1,
            BankLine2,
            BankLine3,
            BankCity,
            BankCode,
            BankState,
            Birthday,
            RefCode1,
            RefCode2,
            IsVip,
            Pic1Name,
            Pic2Name,
            Pic3Name,
            Pic4Name,
            WhatsApp,
            Line,
            WeChat,
            Yahoo,
            QQ,
            BBM,
            LicenseeType,
            SubProductID,
            ProvinceID,
            Inquiries
        )
        SELECT b.HeadlineId             CustID,
               c.TitleID                TitleID,
               c.FirstName              FirstName,
               c.LastName               LastName,
               c.Phone                  Phone,
               c.MobilePhone            MobilePhone,
               c.Fax                    Fax,
               c.Email                  Email,
               b.LanguageId             LanguageID,
               b.CountryId              CountryID,
               GETDATE()                CreateDate,
               @CreatorId               CreatorID,
               @Feedback_Date           FeedbackDate,
               NULL                     SolveDate,
               NULL                     CommunicationID,
               NULL                     StationID,
               NULL                     MainCategoryID,
               NULL                     SubCategoryID,
               c.SiteID                 SiteID,
               b.RoleId                 RoleID,
               NULL                     ProductID,
               NULL                     BetTypeID,
               @Feedback_ResponseId     ResponseID,
               @Feedback_StatusId       StatusID,
               d.Description            Description,
               s.Solution               Solution,
               0                        IsReviewed,
               ''                       Review,
               NULL                     ReviewerID,
               @Feedback_Subject        Subject,
               c.Skype                  Skype,
               c.MSN                    MSN,
               @Feedback_ResolutionDate ResolutionDate,
               c.Pic1                   Pic1,
               c.Pic2                   Pic2,
               c.Pic3                   Pic3,
               c.PhoneCountryCode       PhoneCountryCode,
               c.PhoneAreaCode          PhoneAreaCode,
               c.Phone2                 Phone2,
               c.Phone2CountryCode      Phone2CountryCode,
               c.Phone2AreaCode         Phone2AreaCode,
               c.Phone3                 Phone3,
               c.Phone3CountryCode      Phone3CountryCode,
               c.Phone3AreaCode         Phone3AreaCode,
               c.MobilePhoneCountryCode MobilePhoneCountryCode,
               c.MobilePhoneAreaCode    MobilePhoneAreaCode,
               c.FaxCountryCode         FaxCountryCode,
               c.FaxAreaCode            FaxAreaCode,
               c.Pic4                   Pic4,
               c.Passport               Passport,
               c.Line1                  Line1,
               c.Line2                  Line2,
               c.Line3                  Line3,
               c.City                   City,
               c.Postcode               Postcode,
               c.State                  State,
               c.BankLine1              BankLine1,
               c.BankLine2              BankLine2,
               c.BankLine3              BankLine3,
               c.BankCity               BankCity,
               c.BankCode               BankCode,
               c.BankState              BankState,
               c.Birthday               Birthday,
               c.RefCode1               RefCode1,
               c.RefCode2               RefCode2,
               c.IsVip                  IsVip,
               c.Pic1Name               Pic1Name,
               c.Pic2Name               Pic2Name,
               c.Pic3Name               Pic3Name,
               c.Pic4Name               Pic4Name,
               c.WhatsApp               WhatsApp,
               c.Line                   Line,
               c.WeChat                 WeChat,
               c.Yahoo                  Yahoo,
               c.QQ                     QQ,
               c.BBM                    BBM,
               c.LicenseeType           LicenseeType,
               NULL                     SubProductID,
               c.ProvinceID             ProvinceID,
               0                        Inquiries
        FROM #tmpFeedback_base b
        LEFT JOIN bodb_CRM.dbo.crmCustomer c WITH (NOLOCK) 
			ON b.HeadlineId = c.CustID
        LEFT JOIN #tmpFeedback_solution s 
			ON b.HeadlineId = s.HeadlineId
			AND b.SiteDBGroupID = s.SiteDBGroupID
            AND b.SID = s.SID
        LEFT JOIN #tmpFeedback_description d 
			ON b.HeadlineId = d.HeadlineId
			AND b.SiteDBGroupID = d.SiteDBGroupID
            AND b.SID = d.SID
        WHERE b.Id = @Id

        -- + Get data for @FeedbackId|@CustId|@IsGroupHeadLine
        SELECT @FeedbackId      = SCOPE_IDENTITY()
        SELECT @CustId          = HeadlineId FROM #tmpFeedback_base WHERE Id = @Id
        SELECT @IsGroupHeadLine = ISNULL(IsGroupHeadLine, 0) FROM bodb02.dbo.custAccount WITH (NOLOCK) WHERE custid = @CustId AND IsGroupHeadLine = 1

        -- + Insert data to table crmFeedbackCustomer
        INSERT INTO bodb_CRM.dbo.crmFeedbackCustomer (
            FeedbackId,
            CustId,
            IsRelated
        )
        SELECT @FeedbackId FeedbackId,
               n.CustId    CustId,
               n.IsRelated IsRelated
        FROM #tmpFeedback_base b
        CROSS APPLY (SELECT CAST(c.value AS INT) CustId, 1 IsRelated
                    FROM STRING_SPLIT(b.RelatedCustIds, ',') c
                    WHERE c.value <> b.HeadlineId
                    UNION ALL
                    SELECT b.HeadlineId CustId, 0 IsRelated) n
        WHERE b.Id = @Id

        -- + Insert data to table crmFeedbackSetting
        INSERT INTO bodb_CRM.dbo.crmFeedbackSetting (
            FeedbackId,
            SettingId,
            SubSettingId,
            SubSettingIdLevel3
        )
        -- + --> CS Ex./Station
        SELECT @FeedbackId         FeedbackId,
               @Feedback_StationId SettingId,
               0                   SubSettingId,
               0                   SubSettingIdLevel3
        UNION ALL
        -- + --> Category|SubCategory
        SELECT @FeedbackId             FeedbackId,
               @Feedback_CategoryId    SettingId,
               @Feedback_SubCategoryId SubSettingId,
               0                       SubSettingIdLevel3
        UNION ALL
        -- + --> Communication Tool
        SELECT @FeedbackId                  FeedbackId,
               ISNULL(c.CommunicationId, 0) SettingId,
               0                            SubSettingId,
               0                            SubSettingIdLevel3
        FROM #tmpFeedback_base b
        OUTER APPLY(
			SELECT CAST(c.value AS INT) CommunicationId 
			FROM STRING_SPLIT(b.CommunicationIds, ',') c
		) c
        WHERE b.Id = @Id
        UNION ALL
        -- + --> Product|Sub-product|Bet Type
        SELECT DISTINCT
               @FeedbackId			  FeedbackId,
               @Feedback_ProductId	  SettingId,
               @Feedback_SubProductId SubSettingId,
               @Feedback_BettypeId    SubSettingIdLevel3

        -- + Insert data to table crmFeedbackNewCommunicationTool
        IF (@IsGroupHeadLine = 1)
        BEGIN
            ;WITH CTE_HeadlineInfo AS (
                SELECT DISTINCT
                       p.PicID         PicID,
                       p.Username      PicName,
                       sr.SettingValue PicRoleName
                FROM bodb_CRM.dbo.crmPicManagement pm WITH (NOLOCK)
                LEFT JOIN bodb_CRM.dbo.crmPIC p WITH (NOLOCK) 
					ON pm.PicID = p.PicID
                LEFT JOIN bodb_CRM.dbo.crmSetting sr WITH (NOLOCK) 
					ON sr.SettingName = 'PICRole' 
					AND p.Role = sr.SettingID
                WHERE pm.HeadlineID = @CustId
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
                   @CustId                                                  CustID,
                   ISNULL(@IsGroupHeadLine, 0)                              isHeadline,
                   ISNULL((cte.PicName + ' (' + cte.PicRoleName + ')'), '') PicInfo,
                   pc.CommunicationID                                       CommunicationID,
                   pc.CommunicationValue                                    PicCommunicationValue
            FROM CTE_HeadlineInfo cte
            LEFT JOIN bodb_CRM.dbo.crmPICCommunication pc WITH (NOLOCK) 
				ON cte.PicID = pc.PicID
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
            SELECT @FeedbackId                 FeedbackID,
                   @CustId                     CustID,
                   ISNULL(@IsGroupHeadLine, 0) isHeadline,
                   ''                          PicInfo,
                   ccc.CommunicationID         CommunicationID,
                   ccc.CommunicationValue      CommunicationValue
            FROM bodb_CRM.dbo.crmCustomerNewCommunicationTool ccc WITH (NOLOCK)
            WHERE ccc.CustID = @CustId
        END

        -- + Insert data to table crmFeedbackReference
        INSERT INTO bodb_CRM.dbo.crmFeedbackReference (
            FeedbackId,
            ReferenceId,
            DataSource,
            CreatedDate
        )
        SELECT @FeedbackId		AS FeedbackId,
				[SID]	        AS ReferenceId,
				'SiteDB'+RIGHT('00' + CAST(fb.SiteDBGroupID AS VARCHAR(2)), 2)+'.bodb02.dbo.SabaProgramStatus' AS DataSource,
				GETDATE()		AS CreatedDate
        FROM #tmpFeedback_base fb
        WHERE Id = @Id

        -- + Continue the loop
        SET @Id += 1
    END

	-----------------------------------------------
    -- [08] Update job setting & drop temp table --

    UPDATE s
    SET s.Value = CONVERT(VARCHAR(MAX), @NewLogSID)
    FROM bodb_CRM.dbo.SystemSetting s WITH (ROWLOCK)
    WHERE s.ServiceName = @ServiceName
          AND s.SettingName = @SettingNameOfLastLogSId

    UPDATE s
    SET s.Value = 'Completed'
    FROM bodb_CRM.dbo.SystemSetting s WITH (ROWLOCK)
    WHERE s.ServiceName = @ServiceName
          AND s.SettingName = @SettingNameOfJobStatus
          AND s.Value = 'Running'


	DROP TABLE #tmpHeadlineData
	DROP TABLE #tmpSyncHeadline
	DROP TABLE #tmpXMLData
	DROP TABLE #tmpFeedback_base
	DROP TABLE #tmpFeedback_base_cust
	DROP TABLE #tmpFeedback_description
	DROP TABLE #tmpFeedback_solution
	DROP TABLE #NewLogSID

END