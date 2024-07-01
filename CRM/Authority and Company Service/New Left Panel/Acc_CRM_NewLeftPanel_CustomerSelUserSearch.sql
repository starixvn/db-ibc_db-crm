/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_NewLeftPanel_CustomerSelUserSearch @SearchInfo VARCHAR(200),
                                                               @IsGuest    BIT,
                                                               @UserRole   TINYINT
AS

/*
    Created: 20231212@Ned.Le
    Task: Support auto search suggestion for Search function
    DB: DBCRM/bodb_CRM
    Original: Acc_CRM_CustomerSelUserSearch
    
    Revisions:
        20231212@Ned.Le: CRM - Manage Headline/PIC/Staff authority and Company services (#193385)
        20240701@Ned.Le: CRM - Update 2 SPs to increase performance (#207290)

    Example:
        EXEC bodb_CRM.dbo.Acc_CRM_NewLeftPanel_CustomerSelUserSearch @SearchInfo = '0919862710',
                                                                     @IsGuest    = 0,
                                                                     @UserRole   = 2
*/

BEGIN

    SET NOCOUNT ON

    -- Prepare data
    DECLARE @CountRow INT = 10
    CREATE TABLE #tmpResult (UserName NVARCHAR(100), SearchCount INT)

    -- Get data from crmCustomerSearch|crmCustomer [search for both username and phone]
    IF (@CountRow > 0)
    BEGIN
        INSERT INTO #tmpResult (UserName, SearchCount)
        SELECT TOP (@CountRow) cs.UserName, cs.SearchCount
        FROM bodb_CRM.dbo.crmCustomerSearch cs WITH (NOLOCK)
             INNER JOIN bodb_CRM.dbo.crmCustomer c WITH (NOLOCK) ON cs.CustID = c.CustID
        WHERE ((@IsGuest = 0 AND cs.CustID > 0) OR (ISNULL(@IsGuest, 0) <> 0 AND cs.CustID < 0))
              AND (cs.UserName LIKE @SearchInfo + '%'
                   OR PhoneNumber1 = @SearchInfo
                   OR PhoneNumber2 = @SearchInfo
                   OR PhoneNumber3 = @SearchInfo
                   OR cs.MobilePhone = @SearchInfo)
              AND ((@UserRole = 2 AND ISNULL(c.SiteID, 0) <> 33002) 
                   OR (@UserRole = 1 AND c.SiteID = 33002))
        ORDER BY cs.SearchCount DESC, cs.UserName
    END

    -- Get data from Customer [search for both username and phone]
    SELECT @CountRow = (10 - COUNT(1)) FROM #tmpResult
    IF (@CountRow > 0)
    BEGIN
        INSERT INTO #tmpResult (UserName, SearchCount)
        SELECT TOP (@CountRow) username UserName, -1 as SearchCount
        FROM bodb02.dbo.Customer WITH (NOLOCK)
        WHERE ((@IsGuest = 0 AND custid > 0) OR (ISNULL(@IsGuest, 0) <> 0 AND custid < 0))
              AND username LIKE @SearchInfo +'%' 
              AND username NOT IN (SELECT UserName FROM #tmpResult)
              AND ((@UserRole = 2 AND ISNULL(srecommend, -1) <> 0 AND ISNULL(srecommend, -1) NOT IN (SELECT custid FROM bodb02.dbo.CustSuper WITH (NOLOCK) WHERE UplineId IS NOT NULL))
                   OR (@UserRole = 1 AND (srecommend IN (SELECT custid FROM bodb02.dbo.CustSuper WITH (NOLOCK) WHERE UplineId IS NOT NULL) OR srecommend=0)))
        ORDER BY username
    END

    -- Get data from crmPicManagement|crmCustomer|crmPIC|crmPICCommunication [search only for phone]
    SELECT @CountRow = (10 - COUNT(1)) FROM #tmpResult
    IF (@CountRow > 0)
    BEGIN
        INSERT INTO #tmpResult (UserName, SearchCount)
        SELECT DISTINCT TOP (@CountRow) c.UserName, -1 as SearchCount
        FROM bodb_CRM.dbo.crmPicManagement pm WITH (NOLOCK)
             INNER JOIN bodb_CRM.dbo.crmCustomer c WITH (NOLOCK) ON pm.HeadlineID = c.CustID
             INNER JOIN bodb_CRM.dbo.crmPIC p WITH (NOLOCK) ON pm.PicID = p.PicID
             INNER JOIN bodb_CRM.dbo.crmPICCommunication pc WITH (NOLOCK) ON p.PicID = pc.PicID
        WHERE ((@IsGuest = 0 AND c.CustID > 0) OR (ISNULL(@IsGuest, 0) <> 0 AND c.CustID < 0))
              AND pc.CommunicationID = 49001
              AND pc.CommunicationValue LIKE '%' + @SearchInfo + '%'
              AND c.UserName NOT IN (SELECT UserName FROM #tmpResult)
              AND ((@UserRole = 2 AND ISNULL(c.SiteID, 0) <> 33002) 
                   OR (@UserRole = 1 AND c.SiteID = 33002))
        ORDER BY c.UserName
    END

    -- Get data from crmCustomerNewCommunicationTool|crmCustomer [search only for phone]
    SELECT @CountRow = (10 - COUNT(1)) FROM #tmpResult
    IF (@CountRow > 0)
    BEGIN
        INSERT INTO #tmpResult (UserName, SearchCount)
        SELECT TOP (@CountRow) c.UserName, -1 as SearchCount
        FROM bodb_CRM.dbo.crmCustomerNewCommunicationTool cc WITH (NOLOCK)
             INNER JOIN bodb_CRM.dbo.crmCustomer c WITH (NOLOCK) ON cc.CustID = c.CustID
        WHERE ((@IsGuest = 0 AND c.CustID > 0) OR (ISNULL(@IsGuest, 0) <> 0 AND c.CustID < 0))
              AND cc.CommunicationID = 49001
              AND cc.CommunicationValue LIKE '%' + @SearchInfo + '%'
              AND c.UserName NOT IN (SELECT UserName FROM #tmpResult)
              AND ((@UserRole = 2 AND ISNULL(c.SiteID, 0) <> 33002) 
                   OR (@UserRole = 1 AND c.SiteID = 33002))
        ORDER BY c.UserName
    END

    -- Return data
    SELECT UserName FROM #tmpResult ORDER BY SearchCount DESC, UserName

    -- Drop data
    DROP TABLE #tmpResult
END
GO