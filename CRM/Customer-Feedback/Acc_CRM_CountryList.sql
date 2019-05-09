create procedure Acc_CRM_CountryList
as
select * from crmCountry(nolock) where IsActive = 1
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_CountryList] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CountryList] TO [vnteam]
GO 
