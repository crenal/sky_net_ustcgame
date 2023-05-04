local skynet = require "skynet"
local s = require "service"

s.client={}--对于client方法的处理函数列表
s.client.signup=function(source,fd,msg)
    local res = skynet.call("db","lua","client","signup",msg)
    if res == 0 then
        return {"signup",0,"注册成功"}
    else 
        return {"signup",1,"注册失败"}
    end
end
s.client.login=function(source,fd,msg)
    local gate = source
    node = skynet.getenv("node")
    local res = skynet.call("db","lua","client","login",msg)
    if res[1] == 1 then 
        return {"login",1,"账号或密码错误"}
    else --处理登录事务，请求agentmgr新建agent
        local playerid =res[2]
        --发给agentmgr
        local isok,agent =skynet.call("agentmgr","lua","reqlogin",playerid,node,gate)
        if not isok then
            return{"login",2,"请求mgr失败"}
        end
        --回应gate
        local isok = skynet.call(gate,"lua","sure_agent",fd,playerid,agent)
        if not isok then
            return{"login",3,"gete注册失败"}
        end
        skynet.error("login succ "..playerid)
        return {"login",0,"登录成功"}
    end
end


--向外开放的client协议
s.resp.client=function(source,fd,cmd,msg)--这里的source是某个gateway
    if s.client[cmd] then
        local ret_msg = s.client[cmd](source,fd,msg)
        skynet.send(source,"lua","send_by_fd",fd,ret_msg)
    else
        skynet.error("s.resp.client fail",cmd)
    end
end

function s.init()
    skynet.error("start login service")
end
s.start(...)
