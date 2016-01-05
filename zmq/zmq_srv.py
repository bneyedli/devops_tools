#!/usr/bin/python

import os
import argparse
import time
import psutil
import zmq


def zmqListen():
    context = zmq.Context()
    socket = context.socket(zmq.REP)
    socket.bind("tcp://" +listenIP +":0")

    message = socket.recv_string()
    if message == listenSTR:
        socket.send_string(sendSTR)
    else:
        socket.send_string("BAD MESSAGE")
    os._exit(0)

parser = argparse.ArgumentParser()
parser.add_argument('--ip', '-i', required=True, help='Ip to listen on')
parser.add_argument('--string', '-s', required=True, help='String to listen for')
parser.add_argument('--send', '-ss', required=True, help='String to send')

args = parser.parse_args()

listenIP=args.ip
listenSTR=args.string
sendSTR=args.send

childPid = os.fork()

if childPid == 0:
    zmqListen()
else:
    time.sleep(1)

parentPid = os.getpid()

p = psutil.Process(childPid)

conn = p.connections()

for element in conn:
    laddr= "%s:%s" % (element.laddr)
    lip=laddr.split(':')[0]
    lport=laddr.split(':')[1]
    with open('zmq.args', 'w') as f:
        f.write("Listening on: " +listenIP +" Port: " +lport +" for string: " +listenSTR +"\n")
    f.closed

os._exit(0)
