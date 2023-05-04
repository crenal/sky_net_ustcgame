local skynet = require "skynet"
local cluster = require "skynet.cluster"
--对Skynet服务的一种封装 
local M ={
    --类型和id
    name = "",
    id = 0,
    --回调函数
    exit = nil,
    init = nil,
    --存放函数列表,通常是本服务提供给别的服务调用的接口
    resp = {},
}
function traceback(err)
	skynet.error(tostring(err))
	skynet.error(debug.traceback())
end
--adress就是source，这就是为什么resp中的函数的第一个参数总是source
function dispatch(session,address,cmd,...)
    local fun = M.resp[cmd]
    if not fun then
        skynet.ret()
        return
    end
    --xpcall 是安全调用函数的方法，参数1是函数名，参数2是错误信息，从第三个值开始是函数参数
    --xpcall的返回值 第一个值是函数是否正常执行，第二个值开始是返回值
    local ret = table.pack(xpcall(fun,traceback,address,...))
    local isok = ret[1]

    if not isok then
        skynet.ret()
        return
    end
    -- 返回ret第二个开始的值
    skynet.retpack(table.unpack(ret,2))
end

function init()
    skynet.dispatch("lua",dispatch)
    if M.init then
        M.init()
    end
end
function M.call(node,srv,...)
    local mynode = skynet.getenv("node")
    if node == mynode then
        return skynet.call(srv,"lua",...)
    else
        return cluster.call(node,srv,...)
    end
end
function M.send(node,srv,...)
    local mynode = skynet.getenv("node")
    if node == mynode then
        return skynet.send(srv,"lua",...)
    else
        return cluster.send(node,srv,...)
    end
end

--入口函数
function M.start(name,id,...)
    M.name = name
    M.id = tonumber(id)
    --调用skynet的开始函数
    skynet.start(init)
end
--return M 所以require service返回的就是M
return(M)
