#!/usr/bin/python

import os
import argparse
import time
import psutil
import zmq

connections = 0
context = zmq.Context()
socket = context.socket(zmq.REP)

parser = argparse.ArgumentParser()
parser.add_argument('--ip', '-i', required=True, help='Ip to listen on')
parser.add_argument('--file', '-f', required=True, help='File to dump vars to')
parser.add_argument('--string', '-s', required=True, help='String to listen for')
parser.add_argument('--send', '-ss', required=True, help='String to send')

args = parser.parse_args()

listenIP=args.ip
listenSTR=args.string
sendSTR=args.send
tmpFile=args.file

socket.bind("tcp://" +listenIP +":0")

myPid = os.getpid()
p = psutil.Process(myPid)

conn = p.connections()

for element in conn:
    laddr= "%s:%s" % (element.laddr)
    lip=laddr.split(':')[0]
    lport=laddr.split(':')[1]

with open(tmpFile, 'w') as f:
    f.write("Listening on: " +listenIP +" Port: " +lport +" for string: " +listenSTR +"\n")
f.closed

while connections < 1:
    print("Waiting for initiate")
    message = socket.recv_string()
    if message == listenSTR:
        print("Received request: %s" % message)
        socket.send_string(sendSTR)
        connections += 1
    else:
        print("BAD MESSAGE: " +message)
        socket.send_string("BAD MESSAGE")
        connections += 1
    time.sleep(1)
