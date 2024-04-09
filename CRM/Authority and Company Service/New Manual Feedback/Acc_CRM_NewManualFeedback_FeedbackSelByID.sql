/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_NewManualFeedback_FeedbackSelByID @FeedbackID INT,
                                                              @UserRole   TINYINT
AS

/*
    Created:  Ned.Le
    Date:     20240220
    Task:     Get feedback info
    DB:       DBCRM.bodb_CRM
    Original: Acc_CRM_FeedbackSelByID

    Revisions:
        20240220@Ned.Le: CRM - Manage Headline/PIC/Staff authority and Company services (#193385)

    Param's Explanation:
        @FeedbackID: ID be used to search data
        @UserRole:   0 - Manager 
                     1 - CN88 staff
                     2 - Company staff

    Executive Example:
        EXEC bodb_CRM.dbo.Acc_CRM_NewManualFeedback_FeedbackSelByID @FeedbackID=1234, @UserRole=2
*/

BEGIN

    SET NOCOUNT ON

    -- crmFeedback
    DECLARE @xmlDoc XML
    SELECT  @xmlDoc = CAST(Description AS XML) FROM bodb_CRM.dbo.crmFeedback WITH (NOLOCK) WHERE FeedbackID = @FeedbackID

    DECLARE @iDoc INT
    EXECUTE sp_xml_preparedocument @iDoc OUTPUT, @xmlDoc

    DECLARE @AutoField NVARCHAR(MAX),
            @Remark    NVARCHAR(MAX)
    SELECT  @AutoField = ox.AutoField,
            @Remark    = ox.Remark
    FROM OPENXML (@iDoc, '/ROOT/row', 1)
    WITH (AutoField NVARCHAR(MAX), Remark NVARCHAR(MAX)) AS ox

    SELECT fb.FeedbackID                                                                 FeedbackID,
           fb.CustID                                                                     CustID,
           ctm.UserName                                                                  UserName,
           ISNULL(fb.TitleID, 0)                                                         TitleID,
           fb.FirstName                                                                  FirstName,
           fb.LastName                                                                   LastName,
           fb.Birthday                                                                   Birthday,
           fb.Passport                                                                   Passport,
           ISNULL(fb.SiteID, 0)                                                          SiteID,
           fb.RefCode1                                                                   RefCode1,
           fb.RefCode2                                                                   RefCode2,
           fb.LicenseeType                                                               LicenseeType,
           fb.FeedbackDate                                                               FeedbackDate,
           fb.ResolutionDate                                                             ResolutionDate,
           ISNULL(fb.ResponseID, 0)                                                      ResponseID,
           ISNULL(fb.LanguageID, 0)                                                      LanguageID,
           ISNULL(fb.StatusID, 0)                                                        StatusID,
           ISNULL(fb.RoleID, 0)                                                          RoleID,
           ISNULL(fb.CountryID, 0)                                                       CountryID,
           ISNULL(fb.Inquiries,0)                                                        NoInquiries,
           fb.Subject                                                                    Subject,
           @AutoField                                                                    AutoField,
           @Remark                                                                       Description,
           fb.Solution                                                                   Solution,
           fb.IsReviewed                                                                 IsReviewed,
           fb.Review                                                                     Review,
           fb.CreateDate                                                                 CreateDate,
           fb.SolveDate                                                                  SolveDate,
           fb.CreatorID                                                                  CreatorID,
           c.username AS                                                                 CreatorName,
           ISNULL(fb.ReviewerID, 0)                                                      ReviewerID,
           rv.username                                                                   ReviewerName,
           CASE WHEN @UserRole=1 AND fb.ProvinceID IS NULL THEN 1 ELSE fb.ProvinceID END ProvinceID,           
           ISNULL(fb.IsVip, 0)                                                           IsVip,
           CASE WHEN sr.SettingID IS NOT NULL THEN 1 ELSE 0 END                          IsLicensee,
           ISNULL(s.IsActive,0)                                                          IsSiteActive
    FROM bodb_CRM.dbo.crmFeedback fb WITH (NOLOCK)
         INNER JOIN bodb_CRM.dbo.crmCustomer ctm WITH (NOLOCK) ON fb.CustID = ctm.CustID
         INNER JOIN bodb02.dbo.custInfo c WITH (NOLOCK) ON fb.CreatorID = c.custid
         LEFT JOIN bodb02.dbo.custInfo rv WITH (NOLOCK) ON fb.ReviewerID = rv.custid
         LEFT JOIN bodb_CRM.dbo.crmSetting s WITH (NOLOCK) ON ctm.SiteID = s.SettingID
         LEFT JOIN bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK) ON s.SettingID = sr.SettingID AND sr.ParentID = 33000
    WHERE fb.FeedbackID = @FeedbackID
          AND ((@UserRole=1 AND ctm.SiteID=33002) OR (@UserRole=2 AND ctm.SiteID<>33002))

    -- crmFeedbackNewCommunicationTool
    ;WITH CTE_Data AS (
        SELECT ft.FeedbackID,
               ft.CustID,
               ft.isHeadline,
               ft.PicInfo,
               ft.CommunicationID,
               sc.SettingValue CommunicationName,
               ft.CommunicationValue,
               LEFT(ft.PicInfo, CASE WHEN (CHARINDEX('(', ft.PicInfo) - 2) < 0 THEN 0 ELSE (CHARINDEX('(', ft.PicInfo) - 2) END) PicName,
               REPLACE(RIGHT(ft.PicInfo, LEN(ft.PicInfo) - CHARINDEX('(', ft.PicInfo)), ')', '') PicRoleName
        FROM bodb_CRM.dbo.crmFeedbackNewCommunicationTool ft WITH (NOLOCK)
             LEFT JOIN bodb_CRM.dbo.crmSetting sc WITH (NOLOCK) ON sc.SettingName = 'PICCommunicationTool' AND ft.CommunicationID = sc.SettingID
        WHERE ft.FeedbackID = @FeedbackID
    )
    SELECT FeedbackID,
           CustID,
           isHeadline,
           PicInfo,
           CommunicationID,
           CommunicationName,
           CommunicationValue
    FROM CTE_Data
    ORDER BY FeedbackID,
             CASE WHEN PicRoleName = 'Boss' THEN 1 ELSE 2 END,
             CASE WHEN PicRoleName = 'Boss' THEN PicName END,
             PicRoleName,
             PicName,
             CommunicationName

    -- crmFeedbackSetting
    SELECT fs.FeedbackID,
           fs.SettingID,
           fs.SubSettingID,
           fs.SubSettingIDLevel3,
           CASE WHEN m.MainCategoryID IS NOT NULL THEN 'Category' 
                WHEN s.StationID      IS NOT NULL THEN 'Station' 
                WHEN p.SettingID      IS NOT NULL THEN 'Product' 
                WHEN c.SettingID      IS NOT NULL THEN 'Communication' END AS SettingType
    FROM bodb_CRM.dbo.f_GetFeedbackSetting(@FeedbackID, 0, 0, 3) fs
         LEFT JOIN bodb_CRM.dbo.crmMainCategory m WITH (NOLOCK) ON fs.SettingID=m.MainCategoryID
         LEFT JOIN bodb_CRM.dbo.crmStation s WITH (NOLOCK) ON fs.SettingID=s.StationID
         LEFT JOIN bodb_CRM.dbo.crmSetting p WITH (NOLOCK) ON fs.SettingID=p.SettingID AND p.SettingName='Product'
         LEFT JOIN bodb_CRM.dbo.crmSetting c WITH (NOLOCK) ON fs.SettingID=c.SettingID AND c.SettingName='Communication'

    -- crmFeedbackCustomer
    SELECT cf.FeedbackID,
           cf.CustID,
           ISNULL(c.UserName, c1.username ) UserName,
           CASE WHEN sr.SettingID IS NOT NULL THEN 1 ELSE 0 END AS IsLicensee,
           ISNULL(s.IsActive,0) as IsSiteActive
    FROM bodb_CRM.dbo.crmFeedbackCustomer cf WITH (NOLOCK)
         LEFT JOIN bodb_CRM.dbo.crmCustomer c WITH (NOLOCK) ON c.CustID = cf.CustID
         LEFT JOIN bodb02.dbo.Customer c1 WITH (NOLOCK) ON c1.custid = cf.CustID
         LEFT JOIN bodb_CRM.dbo.crmSetting s WITH (NOLOCK) ON (c.SiteID = s.SettingID AND c.CustID IS NOT NULL) OR (c1.site = s.SettingValue AND s.SettingName = 'Site' AND c.custid IS NULL)
         LEFT JOIN bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK) ON s.SettingID = sr.SettingID AND sr.ParentID = 33000
    WHERE cf.FeedbackID = @FeedbackID 
          AND cf.IsRelated = 1

END
GO