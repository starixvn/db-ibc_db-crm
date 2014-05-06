
ALTER PROCEDURE [dbo].[Acc_CRM_StatusList] 
	@type int = 0
as

if(@type=1)
select * from crmStatus(nolock) where StatusID in(11001, 11002, 11003, 11004, 11006)
else if(@type=2)
select * from crmStatus(nolock) where StatusID in(11002, 11008,11009,11004)
else 
select * from crmStatus(nolock) where isactive=1
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_StatusList] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_StatusList] TO [vnteam]
GO 
