sh.addShard("shard1/shard1-0.mongodb:27017");
sh.addShard("shard2/shard2-0.mongodb:27017");
sh.enableSharding("testdb");
sh.shardCollection("testdb.sample", { _id: "hashed" });
