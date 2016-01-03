#!/usr/bin/python

import argparse
import zmq

context = zmq.Context()
connections = 0

parser = argparse.ArgumentParser()
parser.add_argument('--ip', '-i', required=True, help='Ip to connect to')
parser.add_argument('--port', '-p', required=True, help='Port to connect to')
parser.add_argument('--string', '-s', required=True, help='String to send')

args = parser.parse_args()

connIP=args.ip
connPort=args.port
connString=args.string

socket = context.socket(zmq.REQ)
socket.connect("tcp://" +connIP +":" +connPort)

print("Connecting...")
socket.send_string(connString)

message = socket.recv_string()
print(message)
