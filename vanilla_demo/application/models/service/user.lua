local table_dao = LoadApplication('models.dao.table'):new()
local UserService = {}

function UserService:get()
    table_dao:set('zhou', 'UserService res')
    return table_dao.zhou
end

return UserService
