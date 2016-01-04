#!/usr/bin/python

import time
import argparse
import zmq

connections = 0


parser = argparse.ArgumentParser()
parser.add_argument('--file', '-f', required=True, help='File to dump vars to')
parser.add_argument('--string', '-s', required=True, help='String to listen for')
parser.add_argument('--send', '-ss', required=True, help='String to send')

args = parser.parse_args()

acceptStr=args.string
sendStr=args.send
localSocket=args.file

context = zmq.Context()
socket = context.socket(zmq.REP)

socket.bind("ipc://" +localSocket)

while True:
    print("Waiting for initiate")
    message = socket.recv_string()
    if message == acceptStr:
        print("Received request: %s" % message)
        socket.send_string(sendStr)
        connections += 1
    else:
        print("BAD MESSAGE: " +message)
        socket.send_string("BAD MESSAGE")
        connections += 1
    time.sleep(1)
