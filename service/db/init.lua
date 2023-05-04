local skynet = require "skynet"
local mysql = require "skynet.db.mysql"
local s = require "service"
function length(t)
    local res=0
    for k,v in pairs(t) do
        res=res+1
    end
    return res
end
local function dump(res, tab)
    tab = tab or 0
    if(tab == 0) then
        skynet.error("............dump...........")
    end
    if type(res) == "table" then
        skynet.error(string.rep("\t", tab).."{")
        for k,v in pairs(res) do
            if type(v) == "table" then
                dump(v, tab + 1)
             else
                skynet.error(string.rep("\t", tab), k, "=", v, ",")
            end
        end
        skynet.error(string.rep("\t", tab).."}")
    else
        skynet.error(string.rep("\t", tab) , res)
    end
end

s.client={}
s.client.login=function(source,msg)
    local sql = string.format("select * from players where name = '%s' and passwd = '%s'",msg[2],msg[3])
    local exit = s.db:query(sql)
    if length(exit)==0 then --登录失败
        return{1,-1}
    else 
        return{0,exit[1].playerid}
    end
end
    
s.client.signup=function(source,msg)
    local sql = string.format("insert into players(name,passwd) values ('%s','%s')",msg[2],msg[3])
    local res = s.db:query(sql)
    dump(res)
    if res.badresult == true then --注册成功
        return(1)
    else
        return(0)
    end
end
s.resp.client=function(source,cmd,msg)

    if s.client[cmd] then
        local ret_msg = s.client[cmd](source,msg)
        return(ret_msg)
    else
        skynet.error("db fail",cmd) 
    end
end
function s.init()
    s.db=mysql.connect({
        host="127.0.0.1",
        port=3306,
        database="game",
        user="root",
        password="thekl6666",
        max_packet_size=1024*1024,
        on_connect=nil
    })
    skynet.error("mysql服务启动")
end
s.start(...)