/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_CategoryClassificationList @Category     VARCHAR(MAX),
                                                       @RemarkSearch NVARCHAR(MAX) = '',
                                                       @Active       TINYINT       = 1
AS

/*
	Created: Ned.Le
	Date:    20230922
	Task:    Get list of MainCategory/SubCategory with Remark
	DB:      DBCRM.bodb_CRM

	Revisions:
        20230922@Ned.Le: CRM - Category Classification (Remark management) (#193383)

	Param's Explanation:
        @Category:     <ROOT>
			               <Category
                            MainCategoryID="86000"
                            SubCategoryID="97000"/>
                           <Category
                            MainCategoryID="86000"
                            SubCategoryID="97001"/>
                           <Category
                            MainCategoryID="86000"
                            SubCategoryID="97002"/>
                       </ROOT>
        @RemarkSearch: Value that be used in searching by Remark
        @Active:       1-Get only active (IsActive=1)
                       2-Get all (IsActive=0|1)

    Example
        DECLARE @Category_in VARCHAR(MAX) = '<ROOT>
			                                     <Category
                                                  MainCategoryID="86000"
                                                  SubCategoryID="97000"/>
                                                 <Category
                                                  MainCategoryID="86000"
                                                  SubCategoryID="97001"/>
                                                 <Category
                                                  MainCategoryID="86000"
                                                  SubCategoryID="97002"/>
                                             </ROOT>'
        EXEC bodb_CRM.dbo.Acc_CRM_CategoryClassificationList @Category     = @Category_in,
                                                             @RemarkSearch = '',
                                                             @Active       = 1
*/

BEGIN

	SET NOCOUNT ON

    DECLARE	@iDoc INT
    EXECUTE sys.sp_xml_preparedocument @iDoc OUTPUT, @Category

    CREATE TABLE #tmpCategory (MainCategoryID INT, SubCategoryID INT)
    INSERT INTO	 #tmpCategory (MainCategoryID, SubCategoryID)
    SELECT ox.MainCategoryID, ox.SubCategoryID
    FROM OPENXML(@iDoc, '/ROOT/Category', 1)
         WITH (MainCategoryID INT, SubCategoryID INT) AS ox

    SELECT m.SettingValue Category,
           s.SettingValue SubCategory,
           sr.Remark      Remark
    FROM #tmpCategory tmp
         INNER JOIN bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK) ON tmp.MainCategoryID = sr.ParentID AND tmp.SubCategoryID = sr.SettingID
         INNER JOIN bodb_CRM.dbo.crmSetting m WITH (NOLOCK) ON tmp.MainCategoryID = m.SettingID
         INNER JOIN bodb_CRM.dbo.crmSetting s WITH (NOLOCK) ON tmp.SubCategoryID = s.SettingID
    WHERE ISNULL(sr.Remark, '') LIKE ('%' + @RemarkSearch + '%')
          AND 1 = CASE WHEN (@Active = 1 AND m.IsActive = 1) OR @Active = 2 THEN 1 ELSE 0 END
          AND 1 = CASE WHEN (@Active = 1 AND s.IsActive = 1) OR @Active = 2 THEN 1 ELSE 0 END

END
GO