return {
    -- 集群的节点地址
    cluster = {
        node1 = "127.0.0.1:5678",
        node2 = "127.0.0.1:5679"
    },
    --代理管理的位置
    agentmgr = {node = "node1"},
    --scene 在每个节点的编号
    scene = {
        node1 = {1001,1002},
        --node2 = {1003},
    },
    node1 = {
        gateway = {
            [1] = {port=8016},
        },
        login = {
            [1] = {},
        },
    },

    node2 = {
        gateway = {
            [1] = {port=8011},
            [2] = {port=8022},
        },
        login = {
            [1] = {},
            [2] = {},
        },
    },
}