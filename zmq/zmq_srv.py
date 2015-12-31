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
parser.add_argument('--ip', required=True, help='Ip to listen on')
parser.add_argument('--string', required=True, help='String to listen for')

args = parser.parse_args()

listenIP=args.ip
listenSTR=args.string

socket.bind("tcp://" +listenIP +":0")

myPid = os.getpid()
p = psutil.Process(myPid)

conn = p.connections()

for element in conn:
    laddr= "%s:%s" % (element.laddr)
    lip=laddr.split(':')[0]
    lport=laddr.split(':')[1]

while connections < 1:
    #  Wait for next request from client
    print("Listening on: " +listenIP +" Port: " +lport +" for string: " +listenSTR)
    message = socket.recv_string()
    if message == listenSTR:
        print("Received request: %s" % message)
        #  Send reply back to client
        socket.send_string("Welcome son, here are your secrets")
        connections += 1
    else:
        print("BAD MESSAGE: " +message)
        socket.send_string("BAD MESSAGE")
        connections += 1
    #  Do some 'work'
    time.sleep(1)
