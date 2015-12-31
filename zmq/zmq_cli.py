#!/usr/bin/python

import argparse
import zmq

context = zmq.Context()

parser = argparse.ArgumentParser()
parser.add_argument('--ip', '-i', required=True, help='Ip to connect to')
parser.add_argument('--port', '-p', required=True, help='Port to connect to')
parser.add_argument('--string', '-s', required=True, help='String to send')

args = parser.parse_args()

connIP=args.ip
connPort=args.port
connString=args.string

#  Socket to talk to server
print("Connecting to hello world server…")
socket = context.socket(zmq.REQ)
socket.connect("tcp://" +connIP +":" +connPort)

for request in range(1):
    print("Sending request %s …" % request)
    socket.send_string(connString)

    #  Get the reply.
    message = socket.recv_string()
    print(message)
