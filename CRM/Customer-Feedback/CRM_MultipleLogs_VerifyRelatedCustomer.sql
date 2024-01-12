/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.CRM_MultipleLogs_VerifyRelatedCustomer @HeadlineIds    VARCHAR(MAX)  = '',
                                                           @Username       NVARCHAR(MAX) = '',
                                                           @UserRole       TINYINT       = 2,
                                                           @LicenseeType   TINYINT       = 0,
                                                           @SitePermission NVARCHAR(MAX) = NULL
AS

/*
    Created: 20200303@Tim
    Task : Support "is related customers" function in Create Multiple Logs
    DB: DBCRM/bodb_CRM
    Original:

    Revisions:
	    20200303@Tim: Support "is related customers" function in Create Multiple Logs - RedmineId: #129144
	    20200327@Tim: fix bug get member under direct account
        20231128@Ned.Le: CRM - Security improvement - Separate accessible data for Credit Sites (#197343)

    Param's Explanation:
*/

BEGIN

	SET NOCOUNT ON

	CREATE TABLE #tblHeadlineId (CustId INT)
	CREATE TABLE #tblUsername (Username VARCHAR(50), IsAuthorized BIT DEFAULT 0)
	CREATE TABLE #tblHeadline (CustId INT, GroupId INT)
	CREATE TABLE #tblResult (
		HeadlineId INT
		,CustId INT
		,Username VARCHAR(50)
		,RoleId TINYINT
		,srecommend INT
		,GroupId INT
		,ResultTypeId TINYINT -- 0: valid, 1: invalid username, 2: guest accounts, 3: licensee members, 4: not belong to any headline or direct account, 5: itself, 6: internal account
		)

	INSERT INTO #tblHeadlineId (CustId)
	SELECT tbl.val
	FROM dbo.f_CRM_strSplit(@HeadlineIds, ',') AS tbl

	INSERT INTO #tblHeadline (CustId, GroupId)
	SELECT tbl.CustId, ca.GroupId
	FROM #tblHeadlineId AS tbl WITH (NOLOCK)
		LEFT JOIN bodb02.dbo.custAccount AS ca WITH (NOLOCK) ON tbl.CustId = ca.CustId

	INSERT INTO #tblUsername (Username)
	SELECT DISTINCT ltrim(rtrim(tbl.val))
	FROM dbo.f_CRM_strSplit(@Username, ',') AS tbl

    ------------------------------
    -- BEGIN - Check permission --

    -- #tmpUserSitePermission
    -- + Create temp table
    CREATE TABLE #tmpUserSitePermission (SitePermission NVARCHAR(100))
    -- + Gen data to temp table
    INSERT INTO #tmpUserSitePermission (SitePermission)
    SELECT value SitePermission
    FROM STRING_SPLIT(@SitePermission, ',')

    -- #tmpSite
    -- + Create temp table
    CREATE TABLE #tmpSite (
        SiteID     INT,
        SiteName   NVARCHAR(100),
        IsLicensee INT,
        IsActive   BIT,
        SiteLabel  VARCHAR(50),
        SiteOffer  INT
    )
    -- + Gen data to temp table
    INSERT INTO #tmpSite (
        SiteID,
        SiteName,
        IsLicensee,
        IsActive,
        SiteLabel,
        SiteOffer
    )
    SELECT si.SettingID SiteID,
           si.SettingValue SiteName,
           CASE WHEN sr.ParentID = 33000 THEN 1
                WHEN sr.ParentID = 33001 THEN 0
                ELSE -1 END IsLicensee,
           si.IsActive IsActive,
           si.ExtraInfo SiteLabel,
           sc.SiteOffer SiteOffer
    FROM bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK)
         INNER JOIN bodb_CRM.dbo.crmSetting sc WITH (NOLOCK) ON sc.SettingName = 'SiteCategory' AND sr.ParentID = sc.SettingID
         INNER JOIN bodb_CRM.dbo.crmSetting si WITH (NOLOCK) ON si.SettingName = 'Site' AND sr.SettingID = si.SettingID
    WHERE sr.ParentID IN (33000, 33001)
    UNION ALL
    SELECT sc.SettingID SiteID,
           sc.SettingValue SiteName,
           0 IsLicensee,
           sc.IsActive IsActive,
           NULL SiteLabel,
           sc.SiteOffer SiteOffer
    FROM bodb_CRM.dbo.crmSetting sc WITH (NOLOCK)
    WHERE sc.SettingName = 'SiteCategory' AND sc.SettingID = 33002
    -- + Create index for temp table
    CREATE CLUSTERED INDEX CIX_tmpSite ON #tmpSite(SiteID)

    -- #tmpSitePermission
    -- + Create temp table
    CREATE TABLE #tmpSitePermission (
        SiteID         INT,
        SiteName       NVARCHAR(100),
        SitePermission NVARCHAR(100)
    )
    -- + Gen data to temp table
    INSERT INTO #tmpSitePermission (
        SiteID,
        SiteName,
        SitePermission
    )
    SELECT sr.SettingID    SiteID,
           si.SettingValue SiteName,
           sp.SettingValue SitePermission
    FROM bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK)
         INNER JOIN bodb_CRM.dbo.crmSetting sp WITH (NOLOCK) ON sp.SettingName = 'SitePermission' AND sr.ParentID = sp.SettingID
         INNER JOIN bodb_CRM.dbo.crmSetting si WITH (NOLOCK) ON si.SettingName = 'Site' AND sr.SettingID = si.SettingID
    -- + Create index for temp table
    CREATE CLUSTERED INDEX CIX_tmpSitePermission ON #tmpSitePermission(SiteID)

    -- Process to check permission
    -- + Create temp table
    CREATE TABLE #tmpData (
        Username       VARCHAR(50),
        isLicensee     INT,
        SitePermission NVARCHAR(100)
    )
    -- + Get data from MainDB
    INSERT INTO #tmpData (
        Username,
        isLicensee,
        SitePermission
    )
    SELECT c.username,
           s.IsLicensee,
           sp.SitePermission
    FROM bodb02.dbo.Customer c WITH (NOLOCK)
         LEFT JOIN #tmpSite s ON CASE WHEN c.site = 'IBO' THEN 'Kzing'
                                      WHEN c.site = 'KeenOcean' THEN 'LIVV88'
                                      ELSE c.site END = s.SiteName
         LEFT JOIN #tmpSitePermission sp ON s.SiteID = sp.SiteID
    WHERE c.username IN (SELECT Username FROM #tblUsername)
    -- + Get data from CRM
    INSERT INTO #tmpData (
        Username,
        isLicensee,
        SitePermission
    )
    SELECT c.UserName,
           s.IsLicensee,
           sp.SitePermission
    FROM bodb_CRM.dbo.crmCustomer c WITH (NOLOCK)
         LEFT JOIN #tmpSite s ON c.SiteID = s.SiteID
         LEFT JOIN #tmpSitePermission sp ON s.SiteID = sp.SiteID
    WHERE c.UserName IN (SELECT Username FROM #tblUsername)
          AND c.UserName NOT IN (SELECT Username FROM #tmpData)

    ;WITH CTE_Data AS (
        SELECT c.Username
        FROM #tmpData c
             LEFT JOIN #tmpUserSitePermission usp ON c.SitePermission = usp.SitePermission
        WHERE (c.IsLicensee IS NULL
               OR c.IsLicensee = CASE WHEN @LicenseeType = 0 THEN c.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
              AND
              (c.SitePermission IS NULL
               OR c.SitePermission = usp.SitePermission)
    )
    UPDATE t
    SET t.IsAuthorized = 1
    FROM #tblUsername t
    WHERE t.Username IN (SELECT Username FROM CTE_Data)

    DROP TABLE #tmpUserSitePermission
    DROP TABLE #tmpSite
    DROP TABLE #tmpSitePermission
    DROP TABLE #tmpData

    -- END - Check permission --
    ----------------------------

	INSERT INTO #tblResult (
		CustId
		,Username
		,RoleId
		,srecommend
		,GroupId
		,ResultTypeId
		)
	SELECT DISTINCT c.custid
		,CASE WHEN c.custid IS NOT NULL THEN c.username ELSE tbl.Username END
		,c.roleid
		,c.srecommend
		,c.GroupId
		,CASE 
			WHEN c.IsDeposit = 1 THEN 3
			ELSE 0
			END
	FROM #tblUsername AS tbl WITH (NOLOCK)
		OUTER APPLY (
		SELECT c.custid
			,c.username
			,c.roleid
			,c.srecommend
			,upline.groupId
			,CASE WHEN s.custid IS NULL THEN 0 ELSE 1 END AS IsDeposit
		FROM bodb02.dbo.Customer AS c WITH (NOLOCK)
			LEFT JOIN bodb02.dbo.Dep_CustSuper AS s WITH (NOLOCK) ON c.srecommend = s.custid
			OUTER APPLY (
			SELECT upline.custid
				,upline.groupId
			FROM bodb02.dbo.custAccount AS upline WITH (NOLOCK)
			WHERE (
					c.srecommend = upline.custid
					OR c.mrecommend = upline.custid
					OR c.recommend = upline.custid
					)
				AND ISNULL(upline.groupID, 0) <> 0
				AND NOT EXISTS (
					SELECT 1
					FROM bodb02.dbo.Acc_CustDirect AS cd WITH (NOLOCK)
					WHERE upline.custid = cd.custid
					)
			) AS upline
		WHERE tbl.Username = c.username
			AND ISNULL(c.[site], '') <> 'CN88'
		) AS c

	-- check add related customers for itself
	UPDATE tbl
	SET tbl.ResultTypeId = 5
	FROM #tblResult AS tbl WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tblHeadline AS h WITH (NOLOCK) ON tbl.CustId = h.CustId
	WHERE tbl.ResultTypeId = 0
	
	-- check internal account
	UPDATE tbl
	SET tbl.ResultTypeId = 6
	FROM #tblResult AS tbl WITH (ROWLOCK, UPDLOCK)
		INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON c.custid = tbl.CustId
		AND tbl.ResultTypeId = 0
		AND c.roleid IN (4, 3, 2, 1)
	WHERE EXISTS (
			SELECT 1
			FROM bodb02.dbo.CustSuper AS cs WITH (NOLOCK)
			WHERE c.custid = cs.custid AND cs.IsInternal = 1
			)
		OR EXISTS (
			SELECT 1
			FROM bodb02.dbo.CustMaster AS cm WITH (NOLOCK)
			WHERE c.custid = cm.custid AND cm.IsInternal = 1
			)
		OR EXISTS (
			SELECT 1
			FROM bodb02.dbo.CustAgent AS ca WITH (NOLOCK)
			WHERE (c.custid = ca.custid OR c.recommend = ca.custid) AND ca.IsInternal = 1
			)

	-- check guest accounts
	UPDATE tbl
	SET tbl.CustId = c.CustId
		,tbl.ResultTypeId = 2
	FROM #tblResult AS tbl WITH (ROWLOCK, UPDLOCK)
		INNER JOIN dbo.crmCustomer AS c WITH (NOLOCK) ON tbl.Username = c.Username
		AND c.CustId < 0
	WHERE tbl.CustId IS NULL
		AND tbl.ResultTypeId = 0

	-- check invalid username
	UPDATE #tblResult WITH (ROWLOCK, UPDLOCK)
	SET ResultTypeId = 1
	WHERE CustId IS NULL
		AND ResultTypeId = 0

	IF EXISTS (
			SELECT 1
			FROM #tblResult WITH (NOLOCK)
			WHERE ResultTypeId = 0
			)
	BEGIN
		-- super belong to group headline
		UPDATE tbl
		SET tbl.HeadlineId = h.CustId
		FROM #tblResult AS tbl WITH (ROWLOCK, UPDLOCK)
			INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON c.custid = tbl.CustId
			AND c.roleid = 4
			INNER JOIN bodb02.dbo.CustSuper AS cs WITH (NOLOCK) ON c.custid = cs.custid
			AND cs.IsInternal = 0
			INNER JOIN #tblHeadline AS h WITH (NOLOCK) ON tbl.GroupId = h.GroupId
		WHERE tbl.ResultTypeId = 0
			AND NOT EXISTS (
				SELECT 1
				FROM bodb02.dbo.Acc_CustDirect AS cd WITH (NOLOCK)
				WHERE c.custid = cd.custid
				)

		-- master, agent, member belong to group headline
		UPDATE tbl
		SET tbl.HeadlineId = h.CustId
		FROM #tblResult AS tbl WITH (ROWLOCK, UPDLOCK)
			INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON c.custid = tbl.CustId
			AND c.roleid IN (3, 2, 1)
			INNER JOIN #tblHeadline AS h WITH (NOLOCK) ON h.GroupId = tbl.GroupId
		WHERE tbl.ResultTypeId = 0
			AND NOT EXISTS (
				SELECT 1
				FROM bodb02.dbo.Acc_CustDirect AS cd WITH (NOLOCK)
				WHERE c.custid = cd.custid
				)

		-- super
		UPDATE tbl
		SET tbl.HeadlineId = h.CustId
		FROM #tblResult AS tbl WITH (ROWLOCK, UPDLOCK)
			INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON c.custid = tbl.CustId
			INNER JOIN #tblHeadline AS h WITH (NOLOCK) ON h.CustId = c.srecommend
		WHERE tbl.ResultTypeId = 0
			AND NOT EXISTS (
				SELECT 1
				FROM bodb02.dbo.Acc_CustDirect AS cd WITH (NOLOCK)
				WHERE c.custid = cd.custid OR c.srecommend = cd.custid
				)

		-- direct master
		UPDATE tbl
		SET tbl.HeadlineId = h.CustId
		FROM #tblResult AS tbl WITH (ROWLOCK, UPDLOCK)
			INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON c.custid = tbl.CustId
			INNER JOIN #tblHeadline AS h WITH (NOLOCK) ON h.CustId = c.mrecommend
		WHERE tbl.ResultTypeId = 0
			AND NOT EXISTS (
				SELECT 1
				FROM bodb02.dbo.Acc_CustDirect AS cd WITH (NOLOCK)
				WHERE c.custid = cd.custid OR c.mrecommend = cd.custid
				)

		-- direct agent
		UPDATE tbl
		SET tbl.HeadlineId = h.CustId
		FROM #tblResult AS tbl WITH (ROWLOCK, UPDLOCK)
			INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON c.custid = tbl.CustId
			INNER JOIN #tblHeadline AS h WITH (NOLOCK) ON h.CustId = c.recommend
		WHERE tbl.ResultTypeId = 0
			AND NOT EXISTS (
				SELECT 1
				FROM bodb02.dbo.Acc_CustDirect AS cd WITH (NOLOCK)
				WHERE c.custid = cd.custid OR c.recommend = cd.custid
				)

		-- not belong to any headline or direct account
		UPDATE #tblResult WITH (ROWLOCK, UPDLOCK)
		SET ResultTypeId = 4
		WHERE HeadlineId IS NULL
			AND ResultTypeId = 0
	END
	
	--Hardcode headline incase username in ('ET789','ET889','XT')
	CREATE TABLE #GroupETUS (custid INT, GroupName VARCHAR(50), headlineID INT)
	
	SELECT t.*, c.username
	INTO #tblHeadlineETUS
	FROM #tblHeadline t
		INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON c.custid = t.custid
	WHERE c.username IN ('ET789','ET889','XT','ETUS')
	
	IF EXISTS(SELECT 1 FROM #tblHeadlineETUS)
		AND EXISTS(SELECT 1 FROM #tblResult WHERE groupID = 60)
	BEGIN
		UPDATE #tblResult 
		SET HeadlineId = NULL,
			ResultTypeId = 0
		WHERE groupID = 60 -- ETUS
		
		INSERT INTO #GroupETUS(custid)
		SELECT DISTINCT srecommend 
		FROM #tblResult
		WHERE groupID = 60
		
		UPDATE gr
		SET GroupName = cg.GroupName
		FROM #GroupETUS gr
			INNER JOIN bodb02.dbo.Acc_CustGroup cg WITH(NOLOCK) ON gr.custid = cg.custid
		WHERE cg.GroupName IN ('ACCYEN668','ACCYEN789','ACCYEN889')
				
		;WITH tmp AS (
			SELECT t.custid, t.username, g.GroupName				
			FROM #tblHeadlineETUS t
			INNER JOIN (SELECT 'ET789' username, 'ACCYEN668' GroupName
					UNION ALL SELECT 'ET789', 'ACCYEN789'
					UNION ALL SELECT 'ET889', 'ACCYEN889'					
				)g ON t.username = g.username			
		)
		UPDATE gr
		SET gr.HeadlineId = t.custid
		FROM #GroupETUS gr
			LEFT JOIN tmp t ON gr.GroupName = t.GroupName
		
		--set headline for other supers to XT
		IF EXISTS(SELECT 1 FROM #tblHeadlineETUS WHERE username = 'XT')
		BEGIN
			UPDATE gr
			SET headlineID = (SELECT custid FROM #tblHeadlineETUS WHERE username = 'XT')
			FROM #GroupETUS gr
			WHERE GroupName IS NULL
		END
		
		UPDATE tbl
		SET headlineID = gr.headlineID
		FROM #tblResult tbl
			INNER JOIN #GroupETUS gr ON tbl.srecommend = gr.custid
		WHERE groupID = 60
		
		UPDATE #tblResult WITH (ROWLOCK, UPDLOCK)
		SET ResultTypeId = 4
		WHERE HeadlineId IS NULL
			AND ResultTypeId = 0
			AND groupID =60	
	END	
	
	SELECT DISTINCT r.HeadlineId,
                    r.CustId,
                    r.Username,
                    r.ResultTypeId,
                    ISNULL(u.IsAuthorized, 0) IsAuthorized
	FROM #tblResult r
         LEFT JOIN #tblUsername u ON r.Username = u.Username
	ORDER BY r.Username
	
	DROP TABLE #tblHeadlineId
	DROP TABLE #tblHeadline
	DROP TABLE #tblUsername
	DROP TABLE #tblResult
	DROP TABLE #tblHeadlineETUS
	DROP TABLE #GroupETUS
END
GO