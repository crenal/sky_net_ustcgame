local socket = require"skynet.socket"
local runconfig = require"runconfig"

local skynet = require "skynet"
local s = require "service"

conns = {} --保存客户端连接信息
players = {} --记录已登录玩家信息
--连接类 
function conn()
    local m ={
        fd =nil, --socket通信用的文件描述符 索引
        playerid = nil, 
    }
    return m
end
--玩家类
function gateplayer()
    local m={
        playerid = nil, --玩家id 索引
        agent = nil, --对应的代理服务id
        conn = nil,
    }
    return m
end
--将消息体用','分割为列表
local str_unpack = function(msgstr)
    local msg ={}
    while true do
        local arg,rest = string.match(msgstr,"(.-),(.*)")
        if arg then
            msgstr = rest
            table.insert(msg,arg)
        else
            table.insert(msg,msgstr)
            break
        end
    end
    return msg[1],msg --msg[1]是cmd 
end
--将消息列表转为字符串形式
local str_pack = function(cmd,msg)
    return table.concat(msg,",").."\r\n"
end
--命令处理函数
local process_msg = function(fd,msgstr)
    --print(fd,msgstr)
    local cmd,msg = str_unpack(msgstr)
    skynet.error("recv "..fd.."["..cmd.."]{"..table.concat(msg,",").."}")
    --通过fd获取玩家id
    local conn = conns[fd]
    local playerid = conn.playerid
    if not playerid then
        local node =skynet.getenv("node")
        local nodecfg = runconfig[node]
        local loginid = math.random(1,#nodecfg.login)
        local login = "login"..loginid
        skynet.send(login,"lua","client",fd,cmd,msg)
    else
        print("playerid="..playerid)
        local gplayer = players[playerid]
        local agent =gplayer.agent
        skynet.error(agent)
        skynet.send(agent,"lua","client",cmd,msg)
    end
end
--消息处理函数 两条msg由\r\n来分割
local process_buff = function(fd,readbuff)
    while true do
        local msgstr,rest = string.match(readbuff,"(.-)\r\n(.*)")--正则匹配 msgstr分别是两个括号匹配的串
        if msgstr then
            readbuff =rest
            process_msg(fd,msgstr)
        else
            return readbuff
        end
    end
end
--向指定fd转发信息给客户端
s.resp.send_by_fd = function(source,fd,msg)
    if not conns[fd] then
        return
    end
    local buff = str_pack(msg[1],msg)
    skynet.error("send "..fd.." ["..msg[1].."] {"..table.concat(msg,",").."}")
    socket.write(fd,buff)
end
--向指定玩家转发消息给客户端
s.resp.send = function(source,playerid,msg)
    local gplayer = players[playerid]
    if gplayer == nil then
        return
    end
    local c = gplayer.conn
    if c==nil then
        return
    end
    s.resp.send_by_fd(nil,c.fd,msg)
end
--将客户端与新的agent连接起来
s.resp.sure_agent = function(source,fd,playerid,agent)
    local conn =conns[fd]
    if not conn then --登录过程中已经下线
        skynet.call("agentmgr",lua,"reqkick",playerid,"未完成登录即下线")
        return false
    end
    conn.playerid=playerid
    local gplayer = gateplayer()
    gplayer.playerid=playerid
    gplayer.conn=conn
    gplayer.agent = agent
    
    players[playerid]=gplayer
    return true
end
--客户端掉线导致的下线操作
local disconnect = function(fd)
    local c = conns[fd]
    if not c then 
        return
    end
    local playerid = c.playerid
    --还没完成登录
    if not playerid then 
        return 
    else
        players[playerid]=nil
        local reason = "断线"
        skynet.call("agentmgr","lua","reqkick",playerid,reason)
    end
end
--agentmgr把玩家踢下线
s.resp.kick = function(source,playerid)
    local gplayer = players[playerid]
    if not gplayer then
        return
    end
    local c = gplayer.conn
    players[playerid]=nil
    if not c then
        return
    end
    conns[c.fd]=nil
    disconnect(c.fd)
    socket.close(c.fd)
end
--每一条连接都fork一个recv_loop线程,fd是通信的文件描述符
--协议格式 cmd,arg1,arg2,...
local recv_loop =function(fd)
    --开启连接
    socket.start(fd)
    skynet.error("socket connect "..fd)
    --为了处理粘包，将接收到的数据全部存入readbuff中
    local readbuff = ""
    while true do
        local recvstr = socket.read(fd)
        if recvstr then
            readbuff = readbuff..recvstr
            readbuff = process_buff(fd,readbuff)
        else
            skynet.error("socket close "..fd)
            disconnect(fd)
            socket.close(fd)
            return
        end
    end
end

--当有连接时connect函数启动，addr是客户端的地址，fd是与对方通信的唯一文件描述符
local connect = function(fd,addr)
    print("connect from "..addr.." "..fd)
    local c = conn()
    --将连接信息以fd为主键放入列表中
    conns[fd]=c
    c.fd=fd
    --另外开启线程处理连接
    skynet.fork(recv_loop,fd)
end

--定义回调函数初始化函数init
function s.init()
    skynet.error("start gateway service")
    local node = skynet.getenv("node")--获取当前节点
    local nodecfg = runconfig[node]--当前节点的配置
    local port = nodecfg.gateway[s.id].port--当前gateway的端口

    local listenfd = socket.listen("0.0.0.0",port)
    skynet.error("Listen socket:","0.0.0.0",port)
    
    socket.start(listenfd,connect)
end

s.start(...)