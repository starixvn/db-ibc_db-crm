/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_AbnormalTicketsCheck]
	@TranIDs VARCHAR(MAX),
	@ConfigUAT BIT = 0,
	@ConfigPRO BIT = 0,
	@Environment	VARCHAR(10) = 'LIVE',
	@SiteDBGroupID	SMALLINT = 1
AS
/*
	Created: 20220308@Winfred
	Task : Get abnormal tickets for batch messages siteDB and Central DB
	DB: DBTXN\bodb02
	Original:

	Revisions:
		- 20220803@Winfred: CRM - Scale out DBTRANS [RedmineId : #175877]
		
	Param's Explanation:
		- @MessageIDs: batch msg need to get abnormal tickets
		@MessageIds = '<ROOT>
						<r MsgID="1074539881" ReqID="67130" TransID="10071367596638214"/>
						<r MsgID="1074539881" ReqID="67130" TransID="10071367596638215"/>
						<r MsgID="1074539891" ReqID="67135" TransID="10071367596638209"/>
						<r MsgID="1074539899" ReqID="67136" TransID="10071367596638208"/>
						<r MsgID="1074539904" ReqID="67137" TransID="10130818533949440"/>
						<r MsgID="1074539905" ReqID="67139" TransID="10140722728534130"/>
						<r MsgID="1074539905" ReqID="67139" TransID="10140722728534131"/>
						<r MsgID="1074539905" ReqID="67139" TransID="10140761383239823"/>
						<r MsgID="1074539905" ReqID="67139" TransID="10140761383239824"/>
						<r MsgID="1074539905" ReqID="67139" TransID="10140761383239825"/>
					  </ROOT>'
		- @ConfigUAT: get uus ticket or not
		- @ConfigPRO: get real tickets or not
		- @Environment = 'LIVE'/'UAT' config service for each enviroment 
		- @SiteDBGroupID : SiteDB ID
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmpMessage TABLE (MessageId INT, RequestID INT, TransIDs VARCHAR(MAX))	
	DECLARE @xml XML = CAST(@TranIDs AS XML)	
	
	INSERT INTO @tmpMessage (MessageId,RequestID, TransIDs)
	SELECT t.c.value('@MsgID[1]','int') MsgID,
		t.c.value('@ReqID[1]','int') ReqID,
		t.c.value('@TransID[1]', 'VARCHAR(MAX)') AS TransIDs
	FROM @xml.nodes('/ROOT/r') t(c)	

	--tickets info	
	DECLARE @tblTrans TABLE (MessageId INT, 
							RequestID INT,
							TransID BIGINT,
							custid INT, 
							username VARCHAR(50),
							srecommend INT, 
							recommend INT,
							bettype SMALLINT,
							RelatedUserName VARCHAR(50),
							RelatedCustID INT
							)
		
	INSERT INTO @tblTrans (MessageId, RequestID, transid, custid, username,srecommend,recommend, bettype)
	SELECT vh.MessageId, 
		vh.RequestID,
		t.TransId,
		custid, 
		username, 
		srecommend,
		b.recommend, 
		b.bettype		
	FROM @tmpMessage vh
		CROSS APPLY (
			SELECT value AS TransId FROM string_split(vh.TransIDs, ',')  WHERE Value <> ''
		) t
		CROSS APPLY (
			SELECT TOP 1 transid, custid, username,srecommend, recommend, b.bettype, b.currency
			FROM dbo.bettrans b WITH (NOLOCK)
			WHERE b.transid = t.TransId AND SiteDBGroupID = @SiteDBGroupID  
		) b		
	WHERE 1= CASE WHEN b.currency = 20 AND (@ConfigUAT = 1 OR @Environment = 'UAT') THEN 1
			WHEN b.currency <> 20 AND @ConfigPRO = 1 AND @Environment <> 'UAT' THEN 1
			ELSE 0 END	
		
	INSERT INTO @tblTrans (MessageId, RequestID, transid, custid, username,srecommend,recommend, bettype)
	SELECT vh.MessageId, 
		vh.RequestID,
		t.TransId,
		custid, 
		username, 
		srecommend,
		b.recommend, 
		b.bettype		
	FROM @tmpMessage vh
		CROSS APPLY (
			SELECT value AS TransId FROM string_split(vh.TransIDs, ',')  WHERE Value <> ''
		) t
		CROSS APPLY (
			SELECT TOP 1 transid, custid, username,srecommend, recommend, b.bettype, b.currency
			FROM dbo.bettrans14 b WITH (NOLOCK)
			WHERE  b.transid = t.TransId AND SiteDBGroupID = @SiteDBGroupID 
		) b		
	WHERE t.TransId  NOT IN (SELECT transid FROM @tblTrans) AND
	1= CASE WHEN b.currency = 20 AND (@ConfigUAT = 1 OR @Environment = 'UAT') THEN 1
			WHEN b.currency <> 20 AND @ConfigPRO = 1 AND @Environment <> 'UAT' THEN 1
			ELSE 0 END						
		
	--exclude cn88 tickets
	DELETE t
	FROM @tblTrans t
		INNER JOIN CustDB.dbo.customer c WITH(NOLOCK) ON t.custid = c.custid
	WHERE c.site = 'CN88'

	--tickets info
	SELECT MessageId, 
		RequestID,
		transid,
		t.custid, 
		t.username, 
		b.typenamee as bettype,
		CASE WHEN s.custid IS NULL THEN 0 ELSE 1 END as isDeposit,
		ISNULL(s.site,'') as site,
		t.RelatedCustID,
		t.RelatedUserName		
	FROM @tblTrans t
		LEFT JOIN bettype b WITH(NOLOCK) ON t.bettype = b.typeid
		LEFT JOIN CustDB.dbo.Dep_CustSuper s WITH(NOLOCK) ON t.srecommend = s.custid
	ORDER BY MessageId,RequestID,isDeposit,custid

END	

