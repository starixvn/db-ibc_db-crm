/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROC [dbo].[Acc_CRM_CustomerRemarkNewHistory]
	@RemarkID		INT,
	@CustID			INT,
	@Lang			VARCHAR(10)='en-US'  ,
	@PageSize		INT	=	50,
	@PageIndex		INT	=	0,
	@TotalRows 		INT	=	0 OUTPUT
AS

/*
Created: Winfred
Date: 20220315
Task : Get history remarks
DB: DBCRM.bodb_CRM
Original:

Revisions:	
	- 20220315@Winfred: Special history remarks renovation  [RedmineID:#167941]  
    - 20230616@Ned.Le: CRM | Remark - System gets internal error 500 when viewing history a remark (#189828)
    
Param's Explanation:	
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @RowStart INT,@RowEnd INT ,@Logdata NVARCHAR(MAX) = '' ,@ModifierID INT, @LastUpdate DATETIME, @Version INT, @iDoc INT
	SELECT @PageIndex = @PageIndex - 1,@RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 	
	
	CREATE TABLE #TempHistory (VersionID INT IDENTITY (1,1), RemarkID INT, CustID INT, 
								Logdata NVARCHAR(MAX), ModifierID INT, LastUpdate DATETIME, isfinished BIT DEFAULT(0) )
	
	INSERT INTO #TempHistory(RemarkID,CustID,Logdata,ModifierID,LastUpdate)
	SELECT RemarkID,CustID,Logdata,ModifierID,LastUpdate 
	FROM crmCustomerRemarkHistory a WITH(NOLOCK)
	WHERE a.RemarkID = @RemarkID AND a.CustID = @CustID
	ORDER BY LastUpdate
	
	SELECT @Version = MAX(VersionID) + 1 FROM #TempHistory
	CREATE TABLE #Result (RowNumber	INT IDENTITY (1,1), VersionID	INT, RemarkID INT, HeadlineID INT, HeadlineName NVARCHAR(50), 
						CustID INT, Remark NVARCHAR(MAX),	RemarkTitle INT, RelatedPICs  VARCHAR(100), UserNameRelatedPICs  NVARCHAR(MAX),
						Ext	INT, HandlerID INT, ApproverID INT, AcknowledgerID INT,	Requester NVARCHAR(500), ModifierID INT, LastUpdate DATETIME,
						CreatedDate DATETIME ,CreatorID INT, UserName NVARCHAR(50), Creator NVARCHAR(50),
						Handler NVARCHAR(50), Acknowledger NVARCHAR(50), Approver NVARCHAR(50), 
						RemarkName NVARCHAR(100), ExtStation NVARCHAR(100), Updater NVARCHAR(50)
						)

	INSERT INTO	#Result	(RemarkID, CreatedDate, VersionID, CustID, LastUpdate,  Remark, RemarkTitle, RelatedPICs, Ext, HandlerID, ApproverID, AcknowledgerID, Requester, ModifierID, CreatorID)
	SELECT	RemarkID, CreatedDate, @Version AS VersionID, @CustID AS CustID,LastUpdate , a.Remark, a.RemarkTitle, a.RelatedPICs, a.Ext, a.HandlerID, a.ApproverID, 
			a.AcknowledgerID, a.Requester, a.ModifierID , a.CreatorID
	FROM crmCustomerRemarkNew a WITH(NOLOCK) 
	WHERE a.CustID = @CustID AND a.RemarkID = @RemarkID

	WHILE (1 = 1)
	BEGIN
		SET @Version = @Version - 1
		UPDATE TOP (1) #TempHistory 		 
		SET IsFinished = 1,
			@Logdata = Logdata,
			@ModifierID = ModifierID,
			@LastUpdate = LastUpdate
		WHERE IsFinished = 0 AND VersionID = @Version
		
		IF @@ROWCOUNT=0	BREAK	
		-- Read XML
		EXECUTE sys.sp_xml_preparedocument @iDoc OUTPUT, @Logdata

		INSERT INTO	#Result	(VersionID, CustID, LastUpdate,RemarkID,  Remark, RemarkTitle, RelatedPICs, Ext, HandlerID, ApproverID, AcknowledgerID, Requester, ModifierID)
		SELECT	@Version AS VersionID, @CustID AS CustID,@LastUpdate AS LastUpdate, @RemarkID AS RemarkID, 
				CASE WHEN ox.Remark = 'NULL' THEN NULL ELSE ISNULL(ox.Remark,'') END AS Remark, 
				CASE WHEN ox.RemarkTitle = 'NULL' THEN -1 ELSE CAST(ox.RemarkTitle AS INT) END AS RemarkTitle, 
				CASE WHEN ox.RelatedPICs = 'NULL' THEN NULL ELSE ISNULL(ox.RelatedPICs,'') END AS RelatedPICs, 
				CASE WHEN ox.Ext = 'NULL' THEN -1 ELSE CAST(ox.Ext AS INT) END AS Ext, 
				CASE WHEN ox.HandlerID = 'NULL' THEN -1 ELSE CAST(ox.HandlerID AS INT) END AS HandlerID, 
				CASE WHEN ox.ApproverID = 'NULL' THEN -1 ELSE CAST(ox.ApproverID AS INT) END AS ApproverID, 
				CASE WHEN ox.AcknowledgerID = 'NULL' THEN -1 ELSE CAST(ox.AcknowledgerID AS INT) END AS AcknowledgerID, 
				CASE WHEN ox.Requester = 'NULL' THEN NULL ELSE ISNULL(ox.Requester,'') END AS Requester, 
				CASE WHEN ox.ModifierID = 'NULL' THEN -1 ELSE CAST(ox.ModifierID AS INT) END AS ModifierID
		FROM	OPENXML(@iDoc, '/Root', 2)
				WITH (
					Remark NVARCHAR(MAX),
					RemarkTitle VARCHAR(20),
					RelatedPICs  VARCHAR(1000),
					Ext	VARCHAR(20),
					HandlerID VARCHAR(20),
					ApproverID VARCHAR(20),
					AcknowledgerID VARCHAR(20),
					Requester NVARCHAR(500),
					ModifierID VARCHAR(20)
				) AS ox
		EXECUTE sys.sp_xml_removedocument @iDoc
		
		UPDATE a
		SET a.CustID = b.CustID
			,a.Remark = CASE WHEN a.Remark IS NULL THEN NULL ELSE (CASE WHEN a.Remark <> '' THEN a.Remark ELSE b.Remark END)END
			,a.Requester = CASE WHEN a.Requester IS NULL THEN NULL ELSE (CASE WHEN a.Requester <> '' THEN a.Requester ELSE b.Requester END)END
			,a.RemarkTitle =  CASE WHEN a.RemarkTitle <> 0 THEN 
									 (CASE WHEN a.RemarkTitle = -1 THEN NULL ELSE a.RemarkTitle END) ELSE b.RemarkTitle END
			,a.RelatedPICs = CASE WHEN a.RelatedPICs IS NULL THEN NULL ELSE (CASE WHEN a.RelatedPICs <> '' THEN a.RelatedPICs ELSE b.RelatedPICs END)END
			,a.Ext = CASE WHEN a.Ext <> 0 THEN 
									 (CASE WHEN a.Ext = -1 THEN NULL ELSE a.Ext END) ELSE b.Ext END
			,a.HandlerID = CASE WHEN a.HandlerID <> 0 THEN  
									 (CASE WHEN a.HandlerID = -1 THEN NULL ELSE a.HandlerID END) ELSE b.HandlerID END
			,a.ApproverID = CASE WHEN a.ApproverID <> 0 THEN  
									 (CASE WHEN a.ApproverID = -1 THEN NULL ELSE a.ApproverID END) ELSE b.ApproverID END
			,a.AcknowledgerID = CASE WHEN a.AcknowledgerID <> 0 THEN   
									 (CASE WHEN a.AcknowledgerID = -1 THEN NULL ELSE a.AcknowledgerID END) ELSE b.AcknowledgerID END
			,a.ModifierID = CASE WHEN a.ModifierID <> 0 THEN    
									 (CASE WHEN a.ModifierID = -1 THEN NULL ELSE a.ModifierID END) ELSE b.ModifierID END
			,a.CreatedDate = b.CreatedDate
			,a.CreatorID = b.CreatorID
			,a.RemarkID =  b.RemarkID
		FROM #Result a
			INNER JOIN #Result b ON a.CustID = b.CustID AND a.RemarkID = b.RemarkID AND b.VersionID = a.VersionID + 1
		WHERE a.VersionID = @Version
	END
	
	UPDATE a
	SET a.UserNameRelatedPICs = c.UserNameRelatedPICs 
	FROM #Result a
		OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(b.Username as nvarchar(200))  as [text()]
					FROM STRING_SPLIT(RelatedPICs,',') a
					INNER JOIN  crmPIC b  WITH(NOLOCK)  ON a.value = b.PicID
					WHERE a.value <> ''
					FOR XML PATH('')
					),1,1,'')
			)c (UserNameRelatedPICs)
	
	CREATE TABLE #CustHeadline (
					CustID			INT,
					HeadlineID		INT,					
					HeadlineName	VARCHAR(50)
					)

	INSERT INTO #CustHeadline(CustID,HeadlineID,HeadlineName)
	EXEC bodb02.dbo.Acc_CRM_GroupHeadlineSel @custids = @CustID

	UPDATE a
	SET a.HeadlineID = c.HeadlineID,a.HeadlineName = c.HeadlineName 
	FROM #Result a
		INNER JOIN #CustHeadline c WITH(NOLOCK) ON a.custid = c.custid
	
	UPDATE a
	SET a.UserName =  b.UserName 
		,a.RemarkName = CASE WHEN @Lang='zh-TW' THEN ISNULL(c.SettingValueCT,c.SettingValue)
							 WHEN @Lang='zh-CN' THEN ISNULL(c.SettingValueCS,c.SettingValue)  
							 ELSE c.SettingValue END
		,a.ExtStation = CASE WHEN @Lang='zh-TW' THEN ISNULL(d.SettingValueCT,d.SettingValue)  
			 WHEN @Lang='zh-CN' THEN ISNULL(d.SettingValueCS,d.SettingValue)  
			 ELSE d.SettingValue END 
		,a.Creator = e.UserName	 		
		,a.Handler = her.UserName 		
		,a.Approver = app.UserName		
		,a.Acknowledger = ack.UserName	
		,a.Updater = upd.UserName
	FROM #Result a
		INNER JOIN crmCustomer b WITH(NOLOCK) ON a.CustID = b.CustID
		LEFT JOIN crmSetting c WITH(NOLOCK) ON a.RemarkTitle = c.SettingID AND c.SettingName = 'RemarkTitles'
		LEFT JOIN crmSetting d WITH(NOLOCK) ON a.Ext = d.SettingID AND d.SettingName = 'Station'
		LEFT JOIN bodb02.dbo.Custinfo e WITH(NOLOCK) ON a.CreatorID = e.CustID
		LEFT JOIN bodb02.dbo.Custinfo her WITH(NOLOCK) ON a.HandlerID = her.CustID
		LEFT JOIN bodb02.dbo.Custinfo app WITH(NOLOCK) ON a.ApproverID = app.CustID
		LEFT JOIN bodb02.dbo.Custinfo ack WITH(NOLOCK) ON a.AcknowledgerID = ack.CustID
		LEFT JOIN bodb02.dbo.Custinfo upd WITH(NOLOCK) ON a.ModifierID = upd.CustID

	SELECT @TotalRows = COUNT(1) FROM #Result
	
	SELECT 
		ISNULL(VersionID,1) AS VersionID, RemarkID, CreatedDate, CreatorID, CustID, UserName, RemarkTitle, Ext ,
		RemarkName, ExtStation, Remark, RelatedPICs, HandlerID, ModifierID, Requester, ApproverID, 
		AcknowledgerID, LastUpdate, Creator, Handler, Approver,  Acknowledger, Updater,UserNameRelatedPICs
	FROM #Result
	WHERE RowNumber BETWEEN @RowStart AND @RowEnd
	ORDER BY RowNumber,UserName
	
	DROP TABLE #Result							
	DROP TABLE #CustHeadline
	DROP TABLE #TempHistory
END
GO 
