/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROC [dbo].[Acc_CRM_CustomerRemarkNewSearch]
	@Username		NVARCHAR(1000) = NULL,  
	@Fromdate		DATETIME = NULL,  
	@Todate			DATETIME = NULL, 
	@Remark			NVARCHAR(MAX)	= '',
	@RemarkTitle	VARCHAR(50)= '',
	@IsGuest		BIT = 0,
	@RelatedPICs	NVARCHAR(MAX)	= '',
	@ShowHeadline	BIT = 0,
	@Lang			VARCHAR(10)='en-US'  ,
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
Param's Explanation:	
	@RemarkTitle 0 : All, <> 0 : RemarkTitle
	@IsHistory   0 : Search Remark , 1 : List History				 
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @RowStart INT,@RowEnd INT ,@AffectedList VARCHAR(MAX) = ''
	SELECT @PageIndex = @PageIndex - 1,@RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 	
	
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
		LEFT JOIN DBACC.bodb02.dbo.Custinfo e WITH(NOLOCK) ON a.CreatorID = e.CustID
		LEFT JOIN DBACC.bodb02.dbo.Custinfo her WITH(NOLOCK) ON a.HandlerID = her.CustID
		LEFT JOIN DBACC.bodb02.dbo.Custinfo app WITH(NOLOCK) ON a.ApproverID = app.CustID
		LEFT JOIN DBACC.bodb02.dbo.Custinfo ack WITH(NOLOCK) ON a.AcknowledgerID = ack.CustID
		LEFT JOIN DBACC.bodb02.dbo.Custinfo upd WITH(NOLOCK) ON a.ModifierID = upd.CustID
	WHERE  (@Username = '' OR b.UserName IN (SELECT VALUE FROM STRING_SPLIT(@Username,',') WHERE  value <> ''))
	AND a.Remark LIKE '%' + @Remark + '%' 
	AND (a.RemarkTitle IS NULL OR a.RemarkTitle IN (SELECT VALUE FROM STRING_SPLIT(@RemarkTitle,',')  WHERE  value <> ''))
	AND (@IsGuest = 0 OR (@IsGuest = 1 AND a.CustID < 0))
	AND (@RelatedPICs = '' OR (ISNUlL(a.RelatedPICs,'') <> '' AND EXISTS (SELECT TOP 1 1 
								FROM STRING_SPLIT(a.RelatedPICs,',') s
								INNER JOIN #Pic p ON S.value = p.PicID
								WHERE  S.VALUE <> ''))) 
	AND (a.CreatedDate IS NULL OR a.CreatedDate BETWEEN @Fromdate AND @Todate )

	
	SELECT @AffectedList =  STUFF((SELECT DISTINCT ',' + cast(custid AS VARCHAR(10))
								FROM #Result
								FOR XML PATH('')), 1, 1, '')
	
	INSERT INTO #CustHeadline(CustID,HeadlineID,HeadlineName)
	EXEC bodb02.dbo.Acc_CRM_GroupHeadlineSel @custids = @AffectedList

	UPDATE a
	SET a.HeadlineID = c.HeadlineID,a.HeadlineName = c.HeadlineName 
	FROM #Result a
		INNER JOIN #CustHeadline c WITH(NOLOCK) ON a.custid = c.custid

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
			LEFT JOIN DBACC.bodb02.dbo.Custinfo e WITH(NOLOCK) ON a.CreatorID = e.CustID
			LEFT JOIN DBACC.bodb02.dbo.Custinfo her WITH(NOLOCK) ON a.HandlerID = her.CustID
			LEFT JOIN DBACC.bodb02.dbo.Custinfo app WITH(NOLOCK) ON a.ApproverID = app.CustID
			LEFT JOIN DBACC.bodb02.dbo.Custinfo ack WITH(NOLOCK) ON a.AcknowledgerID = ack.CustID
			LEFT JOIN DBACC.bodb02.dbo.Custinfo upd WITH(NOLOCK) ON a.ModifierID = upd.CustID
		WHERE  a.Remark LIKE '%' + @Remark + '%' 
		AND (a.RemarkTitle IS NULL OR a.RemarkTitle IN (SELECT VALUE FROM STRING_SPLIT(@RemarkTitle,',')  WHERE  value <> ''))
		AND (@IsGuest = 0 OR (@IsGuest = 1 AND a.CustID < 0))
		AND (@RelatedPICs = '' OR (ISNUlL(a.RelatedPICs,'') <> '' AND EXISTS (SELECT TOP 1 1 
									FROM STRING_SPLIT(a.RelatedPICs,',') s
									INNER JOIN #Pic p ON S.value = p.PicID
									WHERE  S.VALUE <> ''))) 
		AND (a.CreatedDate IS NULL OR a.CreatedDate BETWEEN @Fromdate AND @Todate )
		AND a.CustID IN (SELECT HeadlineID FROM #CustHeadline)
		AND a.RemarkID NOT IN (SELECT RemarkID FROM #Result)
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
	
	DROP TABLE #Result							
	DROP TABLE #CustHeadline
END
GO 
