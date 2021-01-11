/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_TOControl_CustOutstandingSel] 
	@xml XML
AS
/*
	Created: 20201126@Johnson
	Task : get outstanding for list customers reach TO level to create auto feedback
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20201126@Johnson: Initial sp [redmine:#145274]
	
	Parameter's Explanation:
		- @xml = '<Root>
						<r custid="123" matchid="10001" />
						<r custid="123" matchid="10002" />
						<r custid="345" matchid="10001" />
					</Root>'
*/	
BEGIN
	SET NOCOUNT ON
		
	CREATE TABLE #Result (custid INT, matchid INT, roleid INT, outstanding MONEY)
	
	INSERT INTO #Result(custid, matchid)
	SELECT t.c.value('@custid','int') ,
		t.c.value('@matchid','int')
	FROM @xml.nodes('Root/r') as t(c)
	
	UPDATE rs 
	SET rs.roleid = ci.roleid
	FROM #Result rs
		INNER JOIN custinfo ci (NOLOCK) ON rs.custid = ci.custid
		
	IF EXISTS(SELECT 1 FROM #Result WHERE roleid = 4)
	BEGIN
		;WITH T AS
		(	
			SELECT srecommend as custid,
				matchid,
				SUM(ABS(actual_stake)) AS Outstanding
			FROM dbo.bettrans b WITH (NOLOCK)  
			WHERE statusId IN (0, 1)
				AND EXISTS (SELECT 1
							FROM #Result rs
							WHERE b.matchid = rs.matchid
								AND b.srecommend = rs.custid
							)
			GROUP BY srecommend,matchid				
		)
		UPDATE rs
		SET rs.Outstanding = t.outstanding
		FROM #Result rs
			INNER JOIN T ON rs.custid = t.custid
							AND rs.matchid = t.matchid
	END
	
	IF EXISTS(SELECT 1 FROM #Result WHERE roleid = 3)
	BEGIN
		;WITH T AS
		(	
			SELECT mrecommend as custid,
				matchid,
				SUM(ABS(actual_stake)) AS Outstanding
			FROM dbo.bettrans b WITH (NOLOCK)  
			WHERE statusId IN (0, 1)
				AND EXISTS (SELECT 1
							FROM #Result rs
							WHERE b.matchid = rs.matchid
								AND b.mrecommend = rs.custid
							)
			GROUP BY mrecommend,matchid				
		)
		UPDATE rs
		SET rs.Outstanding = t.outstanding
		FROM #Result rs
			INNER JOIN T ON rs.custid = t.custid
							AND rs.matchid = t.matchid
	END
	
	IF EXISTS(SELECT 1 FROM #Result WHERE roleid = 2)
	BEGIN
		;WITH T AS
		(	
			SELECT recommend as custid,
				matchid,
				SUM(ABS(actual_stake)) AS Outstanding
			FROM dbo.bettrans b WITH (NOLOCK)  
			WHERE statusId IN (0, 1)
				AND EXISTS (SELECT 1
							FROM #Result rs
							WHERE b.matchid = rs.matchid
								AND b.recommend = rs.custid
							)
			GROUP BY recommend,matchid				
		)
		UPDATE rs
		SET rs.Outstanding = t.outstanding
		FROM #Result rs
			INNER JOIN T ON rs.custid = t.custid
							AND rs.matchid = t.matchid
	END
	
	SELECT custid, matchid, ISNULL(outstanding,0) outstanding
	FROM #Result 
	
	DROP TABLE #Result
END