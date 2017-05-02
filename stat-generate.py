#!/usr/bin/env python

import time
from pymongo import MongoClient

runtime = 0
total_runtime = 3600
filename = "results.csv"
last_ops = {"insert": 0, "update": 0, "delete": 0, "query":0, "writes":0, "write_latency":0}
dbname = "POCDB"

def get_last_ops(client):
    res = client.admin.command('serverStatus')
    ops = res['opcounters']
    gross = ops['insert'] + ops['update']
    last_gross = last_ops['insert'] + last_ops['update']
    writes = ops['opLatencies']['writes']['ops'] - last_ops['writes']
    write_latency = ops['opLatencies']['writes']['latency'] - last_ops['write_latency']
    last_ops['insert'] = ops['insert']
    last_ops['update'] = ops['update']
    last_ops['writes'] = ops['opLatencies']['writes']['ops']
    last_ops['write_latency'] = ops['opLatencies']['writes']['latency']
    collections = client[dbname].command('dbstats')['collections']
    return ("%d,%d,%d,%d" % ((gross - last_gross),collections,writes,write_latency))


client = MongoClient('mongodb://localhost:27017/')
fhandle = open(filename, 'a')
fhandle.write("time,relative_time,inserts,collections,num_writes,write_latency\n")
# Launch the app here?

while (total_runtime > runtime):
    out = get_last_ops(client)
    fhandle.write("%d,%d,%s\n" % (time.time(),runtime,out))
    fhandle.flush()
    time.sleep(1)
    runtime += 1

fhandle.close()
