#!/usr/bin/python2.7

import argparse
import zmq

connections = 0

parser = argparse.ArgumentParser()
parser.add_argument('--file', '-f', required=True, help='Socket to connect to')
parser.add_argument('--string', '-s', required=True, help='String to send')

args = parser.parse_args()

localSocket=args.file
connString=args.string

context = zmq.Context()

socket = context.socket(zmq.REQ)
socket.connect("ipc://" +localSocket)

print("Connecting...")
socket.send_string(connString)

message = socket.recv_string()
print(message)
