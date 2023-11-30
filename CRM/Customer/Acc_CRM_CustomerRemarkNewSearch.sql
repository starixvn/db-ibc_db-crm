/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROC [dbo].[Acc_CRM_CustomerRemarkNewSearch]
	@Username		NVARCHAR(1000) = NULL,  
	@Fromdate		DATETIME = NULL,  
	@Todate			DATETIME = NULL, 
	@Remark			NVARCHAR(MAX)	= '',
	@RemarkTitle	VARCHAR(MAX)= '',
	@IsGuest		BIT = 0,
	@RelatedPICs	NVARCHAR(MAX)	= '',
	@ShowHeadline	BIT = 0,
	@Lang			VARCHAR(10)='en-US'  ,
    @UserRole       TINYINT = 2,
    @LicenseeType   TINYINT = 0,
    @SiteLabel      VARCHAR(MAX) = NULL,
	@PageSize		INT	=	50,
	@PageIndex		INT	=	0,
	@TotalRows 		INT	=	0 OUTPUT
AS

/*
Created: Winfred
Date: 20220315
Task : Get remarks for main tab
DB: DBCRM.bodb_CRM
Original:

Revisions:	
	- 20220315@Winfred: Special remarks renovation  [RedmineID:#167941]   
	- 20220603@Winfred: HF CRM - Remark - Not show sufficient data  [RedmineID:#173703] 
    - 20231003@Ned.Le: CRM - Security improvement - Separate accessible data for Credit and Licensee Users (#192556)
    - 20231128@Ned.Le: CRM - Security improvement - Separate accessible data for Credit Sites (#197343)

Param's Explanation:
	@RemarkTitle : All ID RemarkTitle
	@IsHistory   0 : Search Remark , 1 : List History
    @LicenseeType = 0: Both
                    1: Credit
                    2: Licensee
    @SiteLabel: Value depend on user's permission and maybe NULL
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @RowStart INT,@RowEnd INT ,@AffectedList VARCHAR(MAX) = ''
	SELECT @PageIndex = @PageIndex - 1,@RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

    -- #tmpSiteLabel
    CREATE TABLE #tmpSiteLabel (SiteLabel VARCHAR(50))

    INSERT INTO #tmpSiteLabel (SiteLabel)
    SELECT value SiteLabel
    FROM STRING_SPLIT(@SiteLabel, ',')

    -- #tmpSite
    CREATE TABLE #tmpSite (
        SiteID     INT,
        SiteName   NVARCHAR(100),
        SiteLabel  VARCHAR(50),
        IsLicensee INT
    )

    IF (@UserRole = 2)
    BEGIN
        INSERT INTO #tmpSite (
            SiteID,
            SiteName,
            SiteLabel,
            IsLicensee
        )
        SELECT s.SettingID SiteID,
               s.SettingValue SiteName,
               s.ExtraInfo SiteLabel,
               CASE WHEN sr.ParentID = 33000 THEN 1
                    WHEN sr.ParentID = 33001 THEN 0
                    ELSE -1 END IsLicensee
        FROM bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK)
             INNER JOIN	bodb_CRM.dbo.crmSetting s WITH(NOLOCK) ON sr.SettingID = s.SettingID AND s.SettingName = 'Site'
        WHERE sr.ParentID IN (33000, 33001)
    END
    ELSE IF (@UserRole = 1)
	BEGIN
        INSERT INTO #tmpSite (
            SiteID,
            SiteName,
            SiteLabel,
            IsLicensee
        )
        SELECT s.SettingID SiteID,
               s.SettingValue SiteName,
               s.ExtraInfo SiteLabel,
               0 IsLicensee
        FROM bodb_CRM.dbo.crmSetting s WITH (NOLOCK)
		WHERE s.SettingID = 33002
    END

    CREATE CLUSTERED INDEX CIX_tmpSite ON #tmpSite(SiteID)

    -- #Pic
	CREATE TABLE #Pic(PicID	INT PRIMARY KEY CLUSTERED,Username	NVARCHAR(200))
	CREATE TABLE #Result (RowNumber	INT,
						RemarkID INT,HeadlineID INT ,HeadlineName NVARCHAR(50), 
						CustID INT , Remark NVARCHAR(MAX),IsGroupHeadLine BIT, 
						RemarkTitle INT , RelatedPICs  VARCHAR(100), UserNameRelatedPICs  NVARCHAR(MAX),
						Ext	INT, HandlerID INT , ApproverID INT , AcknowledgerID INT ,
						Requester NVARCHAR(500), ModifierID INT , LastUpdate DATETIME ,
						CreatedDate DATETIME ,CreatorID INT, UserName NVARCHAR(50), Creator NVARCHAR(50),
						Handler NVARCHAR(50), Acknowledger NVARCHAR(50), Approver NVARCHAR(50), 
						RemarkName NVARCHAR(100), ExtStation NVARCHAR(100), Updater NVARCHAR(50)
						)
	CREATE TABLE #Customer (
					CustID			INT,					
					UserName		NVARCHAR(50)
					)

	CREATE TABLE #CustHeadline (
					CustID			INT,
					HeadlineID		INT,					
					HeadlineName	VARCHAR(50)
					)
	
	INSERT INTO #Pic(PicID, Username) 
	SELECT PicID, Username
	FROM crmPIC p  WITH(NOLOCK)
	OUTER APPLY ( SELECT VALUE FROM STRING_SPLIT(@RelatedPICs,',') WHERE VALUE <> '' ) tmp
	WHERE  p.Username like '%' + tmp.value +'%'

	INSERT INTO #Customer(CustID, Username) 
	SELECT p.CustID, Username
	FROM crmCustomer p  WITH(NOLOCK)
	OUTER APPLY ( SELECT VALUE FROM STRING_SPLIT(@Username,',') WHERE VALUE <> '' ) tmp
	WHERE  p.Username = tmp.value 

    -- #Result
	INSERT INTO #Result(RemarkID, CreatedDate, CreatorID, CustID, UserName, RemarkTitle, Ext
		, RemarkName, ExtStation, Remark, RelatedPICs, HandlerID, ModifierID, Requester, ApproverID
		, AcknowledgerID, LastUpdate, Creator, Handler, Approver,  Acknowledger, Updater )
	SELECT 
		a.RemarkID, a.CreatedDate, a.CreatorID, a.CustID, b.UserName , a.RemarkTitle, a.Ext,
		CASE WHEN @Lang='zh-TW' THEN ISNULL(c.SettingValueCT,c.SettingValue)  
			 WHEN @Lang='zh-CN' THEN ISNULL(c.SettingValueCS,c.SettingValue)  
			 ELSE c.SettingValue END AS RemarkName,
		CASE WHEN @Lang='zh-TW' THEN ISNULL(d.SettingValueCT,d.SettingValue)  
			 WHEN @Lang='zh-CN' THEN ISNULL(d.SettingValueCS,d.SettingValue)  
			 ELSE d.SettingValue END AS ExtStation,	 
		a.Remark, a.RelatedPICs,	a.HandlerID, a.ModifierID, a.Requester, a.ApproverID,a.AcknowledgerID,
		a.LastUpdate , e.UserName AS Creator, her.UserName AS Handler, app.UserName AS Approver,
		ack.UserName AS Acknowledger, upd.UserName AS Updater
	FROM crmCustomerRemarkNew a WITH(NOLOCK) 
		LEFT JOIN crmCustomer b WITH(NOLOCK) ON a.CustID = b.CustID
		LEFT JOIN crmSetting c WITH(NOLOCK) ON a.RemarkTitle = c.SettingID AND c.SettingName = 'RemarkTitles'
		LEFT JOIN crmSetting d WITH(NOLOCK) ON a.Ext = d.SettingID AND d.SettingName = 'Station'
		LEFT JOIN bodb02.dbo.Custinfo e WITH(NOLOCK) ON a.CreatorID = e.CustID
		LEFT JOIN bodb02.dbo.Custinfo her WITH(NOLOCK) ON a.HandlerID = her.CustID
		LEFT JOIN bodb02.dbo.Custinfo app WITH(NOLOCK) ON a.ApproverID = app.CustID
		LEFT JOIN bodb02.dbo.Custinfo ack WITH(NOLOCK) ON a.AcknowledgerID = ack.CustID
		LEFT JOIN bodb02.dbo.Custinfo upd WITH(NOLOCK) ON a.ModifierID = upd.CustID
        LEFT JOIN #tmpSite s ON b.SiteID = s.SiteID
        LEFT JOIN #tmpSiteLabel sl ON s.SiteLabel = sl.SiteLabel
	WHERE  (@Username = '' OR b.CustID IN (SELECT CustID FROM #Customer))
	AND a.Remark LIKE '%' + @Remark + '%' 
	AND (a.RemarkTitle IS NULL OR a.RemarkTitle IN (SELECT VALUE FROM STRING_SPLIT(@RemarkTitle,',')  WHERE  value <> ''))
	AND ((@IsGuest = 0 AND a.CustID > 0)OR (@IsGuest = 1 AND a.CustID < 0))
	AND (@RelatedPICs = '' OR (ISNUlL(a.RelatedPICs,'') <> '' AND EXISTS (SELECT TOP 1 1 
								FROM STRING_SPLIT(a.RelatedPICs,',') s
								INNER JOIN #Pic p ON S.value = p.PicID
								WHERE  S.VALUE <> ''))) 
	AND (a.CreatedDate IS NULL OR a.CreatedDate BETWEEN @Fromdate AND @Todate )
    AND (s.IsLicensee IS NULL
         OR s.IsLicensee = CASE WHEN @LicenseeType = 0 THEN s.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
    AND (ISNULL(s.SiteLabel, '') = CASE WHEN @LicenseeType = 0 THEN CASE WHEN s.IsLicensee = 0 THEN sl.SiteLabel ELSE ISNULL(s.SiteLabel, '') END
                                        WHEN @LicenseeType = 1 THEN sl.SiteLabel
                                        WHEN @LicenseeType = 2 THEN ISNULL(s.SiteLabel, '') END)

    INSERT INTO #Customer(CustID, Username)
    SELECT CustID, Username
    FROM #Result
    WHERE CustID NOT IN (SELECT CustID FROM #Customer)
	
	SELECT @AffectedList =  STUFF((SELECT DISTINCT ',' + cast(custid AS VARCHAR(10))
								FROM #Customer
								FOR XML PATH('')), 1, 1, '')
	
	INSERT INTO #CustHeadline(CustID,HeadlineID,HeadlineName)
	EXEC bodb02.dbo.Acc_CRM_GroupHeadlineSel @custids = @AffectedList

	UPDATE a
	SET a.HeadlineID = c.HeadlineID,a.HeadlineName = c.HeadlineName 
	FROM #Result a
		INNER JOIN #CustHeadline c WITH(NOLOCK) ON a.custid = c.custid

    -- #Result
	IF @ShowHeadline = 1
	BEGIN
		INSERT INTO #Result(RemarkID, CreatedDate, CreatorID, CustID, UserName, RemarkTitle, Ext
		, RemarkName, ExtStation, Remark, RelatedPICs, HandlerID, ModifierID, Requester, ApproverID
		, AcknowledgerID, LastUpdate, Creator, Handler, Approver,  Acknowledger, Updater,HeadlineID,HeadlineName )
		SELECT 
			a.RemarkID, a.CreatedDate, a.CreatorID, a.CustID, b.UserName , a.RemarkTitle, a.Ext,
			CASE WHEN @Lang='zh-TW' THEN ISNULL(c.SettingValueCT,c.SettingValue)  
				 WHEN @Lang='zh-CN' THEN ISNULL(c.SettingValueCS,c.SettingValue)  
				 ELSE c.SettingValue END AS RemarkName,
			CASE WHEN @Lang='zh-TW' THEN ISNULL(d.SettingValueCT,d.SettingValue)  
				 WHEN @Lang='zh-CN' THEN ISNULL(d.SettingValueCS,d.SettingValue)  
				 ELSE d.SettingValue END AS ExtStation,	 
			a.Remark, a.RelatedPICs,	a.HandlerID, a.ModifierID, a.Requester, a.ApproverID,a.AcknowledgerID,
			a.LastUpdate , e.UserName AS Creator, her.UserName AS Handler, app.UserName AS Approver,
			ack.UserName AS Acknowledger, upd.UserName AS Updater , a.CustID AS HeadlineID, b.UserName AS HeadlineName
		FROM crmCustomerRemarkNew a WITH(NOLOCK) 
			LEFT JOIN crmCustomer b WITH(NOLOCK) ON a.CustID = b.CustID
			LEFT JOIN crmSetting c WITH(NOLOCK) ON a.RemarkTitle = c.SettingID AND c.SettingName = 'RemarkTitles'
			LEFT JOIN crmSetting d WITH(NOLOCK) ON a.Ext = d.SettingID AND d.SettingName = 'Station'
			LEFT JOIN bodb02.dbo.Custinfo e WITH(NOLOCK) ON a.CreatorID = e.CustID
			LEFT JOIN bodb02.dbo.Custinfo her WITH(NOLOCK) ON a.HandlerID = her.CustID
			LEFT JOIN bodb02.dbo.Custinfo app WITH(NOLOCK) ON a.ApproverID = app.CustID
			LEFT JOIN bodb02.dbo.Custinfo ack WITH(NOLOCK) ON a.AcknowledgerID = ack.CustID
			LEFT JOIN bodb02.dbo.Custinfo upd WITH(NOLOCK) ON a.ModifierID = upd.CustID
            LEFT JOIN #tmpSite s ON b.SiteID = s.SiteID
            LEFT JOIN #tmpSiteLabel sl ON s.SiteLabel = sl.SiteLabel
		WHERE  a.Remark LIKE '%' + @Remark + '%' 
		AND (a.RemarkTitle IS NULL OR a.RemarkTitle IN (SELECT VALUE FROM STRING_SPLIT(@RemarkTitle,',')  WHERE  value <> ''))
		AND ((@IsGuest = 0 AND a.CustID > 0)OR (@IsGuest = 1 AND a.CustID < 0))
		AND (@RelatedPICs = '' OR (ISNUlL(a.RelatedPICs,'') <> '' AND EXISTS (SELECT TOP 1 1 
									FROM STRING_SPLIT(a.RelatedPICs,',') s
									INNER JOIN #Pic p ON S.value = p.PicID
									WHERE  S.VALUE <> ''))) 
		AND (a.CreatedDate IS NULL OR a.CreatedDate BETWEEN @Fromdate AND @Todate )
		AND a.CustID IN (SELECT HeadlineID FROM #CustHeadline)
		AND a.RemarkID NOT IN (SELECT RemarkID FROM #Result)
        AND (s.IsLicensee IS NULL
             OR s.IsLicensee = CASE WHEN @LicenseeType = 0 THEN s.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
        AND (ISNULL(s.SiteLabel, '') = CASE WHEN @LicenseeType = 0 THEN CASE WHEN s.IsLicensee = 0 THEN sl.SiteLabel ELSE ISNULL(s.SiteLabel, '') END
                                            WHEN @LicenseeType = 1 THEN sl.SiteLabel
                                            WHEN @LicenseeType = 2 THEN ISNULL(s.SiteLabel, '') END)
	END
	
	UPDATE a
	SET a.UserNameRelatedPICs = c.UserNameRelatedPICs 
	FROM #Result a
		OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ', '+ cast(b.Username as nvarchar(200))  as [text()]
					FROM STRING_SPLIT(RelatedPICs,',') a
					INNER JOIN  crmPIC b  WITH(NOLOCK)  ON a.value = b.PicID
					WHERE  value <> ''
					FOR XML PATH('')
					),1,1,'')
			)c (UserNameRelatedPICs)
	
	UPDATE a
	SET a.IsGroupHeadLine = 1
	FROM #Result a
		INNER JOIN bodb02.dbo.CustAccount c WITH(NOLOCK) ON a.custid = c.custid AND c.IsGroupHeadLine = 1

	UPDATE a
	SET a.RowNumber = KQ.row_num
	FROM #Result a
	OUTER APPLY (
				SELECT 
					   ROW_NUMBER() OVER (
						ORDER BY CreatedDate DESC, RemarkID DESC
					   ) row_num,
					   RemarkID
					FROM #Result
			) KQ
	WHERE a.RemarkID = KQ.RemarkID
	SELECT @TotalRows = COUNT(1) FROM #Result
	
	SELECT 
		RemarkID, CreatedDate, CreatorID, CustID, UserName, RemarkTitle, Ext , IsGroupHeadLine,
		RemarkName, ExtStation, Remark, RelatedPICs, HandlerID, ModifierID, Requester, ApproverID, 
		AcknowledgerID, LastUpdate, Creator, Handler, Approver,  Acknowledger, Updater , HeadlineID , HeadlineName,UserNameRelatedPICs
	FROM #Result
	WHERE RowNumber BETWEEN @RowStart AND @RowEnd
	ORDER BY CreatedDate DESC, RemarkID DESC

    DROP TABLE #tmpSiteLabel
    DROP TABLE #tmpSite
    DROP TABLE #Pic	
	DROP TABLE #Result							
	DROP TABLE #CustHeadline
	DROP TABLE #Customer
END
GO 
