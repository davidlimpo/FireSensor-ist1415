#! /usr/bin/python
from TOSSIM import *
import sys

t = Tossim([])
r = t.radio()

t.addChannel("FireSensorC", sys.stdout)
t.addChannel("Boot", sys.stdout)

noise = open("terrainNoise.txt", "r")

def init(routingNum, sensorNum, f):
  bootTime = 100001

  print "----- Topology -----\n"

  for line in f:
    s = line.split()
    if s:
      print " ", s[0], " ", s[1], " ", s[2];
      r.add(int(s[0]), int(s[1]), float(s[2]))

  for line in noise:
    str1 = line.strip()
    if str1:
      val = int(str1)
      for i in range(0, routingNum):
        t.getNode(i).addNoiseTraceReading(val)
      for i in range(100, sensorNum):
        t.getNode(i).addNoiseTraceReading(val)

  for i in range(0, routingNum):
    t.getNode(i).createNoiseModel()

  for i in range(100, sensorNum): 
    t.getNode(i).createNoiseModel()

  for i in range(0, routingNum):
    t.getNode(i).bootAtTime(bootTime);
    bootTime = bootTime + 1

  for i in range(100, sensorNum): 
    t.getNode(i).bootAtTime(bootTime);
    bootTime = bootTime + 1
  return;

while True:  
  command = raw_input("\n*************** Choose network topology ***************\n[1] Topology 1\n[2] Topology 2\n[3] Topology 3\n[0] Exit\nCommand:\n");

  if command.strip() == '1':
    f = open("topo1.txt", "r")
    init(routingNum = 2, sensorNum = 101, f = f);
    for i in range(5000):
      t.runNextEvent()

  elif command.strip() == '2':
    f = open("topo2.txt", "r")
    init(routingNum = 3, sensorNum = 102, f = f);
    for i in range(10000):
      t.runNextEvent()

  elif command.strip() == '3':
    f = open("topo3.txt", "r")
    init(routingNum = 3, sensorNum = 102, f = f);
    
    for i in range(10000):
      t.runNextEvent()
    
    print "----- SHUTTING DOWN NODE 1 -----\n*\n*\n*\n*\n*\n*\n*\n*\n*\n*\n*\n*\n*\n*\n*\n*\n*\n*\n*\n*\n*\n*\n***************************************************"
    t.getNode(1).turnOff()
    
    for i in range(10000):
      t.runNextEvent()

  elif command.strip() == '0':
    break;