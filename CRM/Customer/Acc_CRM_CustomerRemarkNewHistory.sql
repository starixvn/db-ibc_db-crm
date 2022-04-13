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
Param's Explanation:	
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @RowStart INT,@RowEnd INT ,@Logdata VARCHAR(MAX) = '' ,@UpdaterID INT, @LastUpdate DATETIME, @Version INT, @iDoc INT
	SELECT @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 	
	
	CREATE TABLE #TempHistory (VersionID INT IDENTITY (1,1), RemarkID INT, CustID INT, 
								Logdata NVARCHAR(MAX), UpdaterID INT, LastUpdate DATETIME, isfinished BIT DEFAULT(0) )
	
	INSERT INTO #TempHistory(RemarkID,CustID,Logdata,UpdaterID,LastUpdate)
	SELECT RemarkID,CustID,Logdata,UpdaterID,LastUpdate 
	FROM crmCustomerRemarkHistory a WITH(NOLOCK)
	WHERE a.RemarkID = @RemarkID AND a.CustID = @CustID
	ORDER BY LastUpdate
	
	SELECT @Version = MAX(VersionID) + 1 FROM #TempHistory
	CREATE TABLE #Result (RowNumber	INT IDENTITY (1,1), VersionID	INT, RemarkID INT, HeadlineID INT, HeadlineName NVARCHAR(50), 
						CustID INT, Remark NVARCHAR(MAX),	RemarkTitle INT, RelatedPICs  VARCHAR(100), UserNameRelatedPICs  NVARCHAR(MAX),
						Ext	INT, HandlerID INT, ApproverID INT, AcknowledgerID INT,	Requester NVARCHAR(500), UpdaterID INT, LastUpdate DATETIME,
						CreatedDate DATETIME ,CreatorID INT, UserName NVARCHAR(50), Creator NVARCHAR(50),
						Handler NVARCHAR(50), Acknowledger NVARCHAR(50), Approver NVARCHAR(50), 
						RemarkName NVARCHAR(100), ExtStation NVARCHAR(100), Updater NVARCHAR(50)
						)

	INSERT INTO	#Result	(RemarkID, CreatedDate, VersionID, CustID, LastUpdate,  Remark, RemarkTitle, RelatedPICs, Ext, HandlerID, ApproverID, AcknowledgerID, Requester, UpdaterID, CreatorID)
	SELECT	RemarkID, CreatedDate, @Version AS VersionID, @CustID AS CustID,LastUpdate , a.Remark, a.RemarkTitle, a.RelatedPICs, a.Ext, a.HandlerID, a.ApproverID, 
			a.AcknowledgerID, a.Requester, a.UpdaterID , a.CreatorID
	FROM crmCustomerRemarkNew a WITH(NOLOCK) 
	WHERE a.CustID = @CustID AND a.RemarkID = @RemarkID

	WHILE (1 = 1)
	BEGIN
		SET @Version = @Version - 1
		UPDATE TOP (1) #TempHistory 		 
		SET IsFinished = 1,
			@Logdata = Logdata,
			@UpdaterID = UpdaterID,
			@LastUpdate = LastUpdate
		WHERE IsFinished = 0 AND VersionID = @Version
		
		IF @@ROWCOUNT=0	BREAK	
		-- Read XML
		EXECUTE sys.sp_xml_preparedocument @iDoc OUTPUT, @Logdata

		INSERT INTO	#Result	(VersionID, CustID, LastUpdate,RemarkID,  Remark, RemarkTitle, RelatedPICs, Ext, HandlerID, ApproverID, AcknowledgerID, Requester, UpdaterID)
		SELECT	@Version AS VersionID, @CustID AS CustID,@LastUpdate AS LastUpdate, @RemarkID AS RemarkID, ox.Remark, ox.RemarkTitle, ox.RelatedPICs, ox.Ext, ox.HandlerID, ox.ApproverID, 
				ox.AcknowledgerID, ox.Requester, ox.UpdaterID
		FROM	OPENXML(@iDoc, '/Root', 2)
				WITH (
					Remark NVARCHAR(MAX),
					RemarkTitle INT,
					RelatedPICs  VARCHAR(1000),
					Ext	INT,
					HandlerID INT,
					ApproverID INT,
					AcknowledgerID INT,
					Requester NVARCHAR(500),
					UpdaterID INT
				) AS ox
		EXECUTE sys.sp_xml_removedocument @iDoc
		
		UPDATE a
		SET a.CustID = b.CustID
			,a.Remark = CASE WHEN ISNULL(a.Remark,'') <> '' THEN a.Remark ELSE b.Remark END
			,a.RemarkTitle = CASE WHEN ISNULL(a.RemarkTitle,0) <> 0 THEN a.RemarkTitle ELSE b.RemarkTitle END
			,a.RelatedPICs = CASE WHEN ISNULL(a.RelatedPICs,'') <> '' THEN a.RelatedPICs ELSE b.RelatedPICs END
			,a.Ext = CASE WHEN ISNULL(a.Ext,0) <> 0 THEN a.Ext ELSE b.Ext END
			,a.HandlerID = CASE WHEN ISNULL(a.HandlerID,0) <> 0 THEN a.HandlerID ELSE b.HandlerID END
			,a.ApproverID = CASE WHEN ISNULL(a.ApproverID,0) <> 0 THEN a.ApproverID ELSE b.ApproverID END
			,a.AcknowledgerID = CASE WHEN ISNULL(a.AcknowledgerID,0) <> 0 THEN a.AcknowledgerID ELSE b.AcknowledgerID END
			,a.Requester = CASE WHEN ISNULL(a.Requester,'') <> '' THEN a.Requester ELSE b.Requester END
			,a.UpdaterID = CASE WHEN ISNULL(a.UpdaterID,0) <> 0 THEN a.UpdaterID ELSE b.UpdaterID END
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
		LEFT JOIN crmCustomer e WITH(NOLOCK) ON a.CreatorID = e.CustID
		LEFT JOIN crmCustomer her WITH(NOLOCK) ON a.HandlerID = her.CustID
		LEFT JOIN crmCustomer app WITH(NOLOCK) ON a.ApproverID = app.CustID
		LEFT JOIN crmCustomer ack WITH(NOLOCK) ON a.AcknowledgerID = ack.CustID
		LEFT JOIN crmCustomer upd WITH(NOLOCK) ON a.UpdaterID = upd.CustID

	SELECT @TotalRows = COUNT(1) FROM #Result
	
	SELECT 
		VersionID, RemarkID, CreatedDate, CreatorID, CustID, UserName, RemarkTitle, Ext ,
		RemarkName, ExtStation, Remark, RelatedPICs, HandlerID, UpdaterID, Requester, ApproverID, 
		AcknowledgerID, LastUpdate, Creator, Handler, Approver,  Acknowledger, Updater
	FROM #Result
	WHERE RowNumber BETWEEN @RowStart AND @RowEnd
	ORDER BY RowNumber,UserName
	
	DROP TABLE #Result							
	DROP TABLE #CustHeadline
	DROP TABLE #TempHistory
END
GO 
