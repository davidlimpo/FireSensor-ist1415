
#ifndef FIRESENSOR_H
#define FIRESENSOR_H

enum {
GPS_PERIOD_MILLI = 555,
DATA_PERIOD_MILLI = 777,
SMOKE_PERIOD_MILLI = 333,
AM_FIRESENSOR = 6,
NUMBER_OF_MESSAGES = 10000,
MAX_NUMBER_OF_SENSORS = 100,
MAX_GPS_RELAY = 5,
MAX_ROUTING_RELAY = 5,
MAX_SMOKE_RELAY = 5
};
 
typedef nx_struct GPSMsg {
  nx_uint16_t nodeid;
  nx_uint16_t x;
  nx_uint16_t y;
} GPSMsg;

typedef nx_struct DataMsg {
  nx_uint16_t nodeid;
  nx_uint16_t messageid;
  nx_uint16_t humidity;
  nx_uint16_t temperature;
} DataMsg;

typedef nx_struct RoutingMsg {
  DataMsg sensorMessage;
  nx_uint16_t routingid;
} RoutingMsg;

typedef nx_struct SmokeMsg {
  nx_uint16_t nodeid;
  nx_uint16_t routingid;
} SmokeMsg;

typedef nx_struct History {
  nx_uint16_t nodeid;
  nx_uint16_t messageid;
} History;

typedef nx_struct GpsMsgControl {
  nx_uint16_t nodeid;
  nx_uint16_t counter;
} GpsMsgControl;

typedef nx_struct RoutingMsgControl {
  nx_uint16_t messageid;
  nx_uint16_t sensorid;
  nx_uint16_t counter;
} RoutingMsgControl;

typedef nx_struct SmokeMsgControl {
  nx_uint16_t nodeid;
  nx_uint16_t counter;
} SmokeMsgControl;

#endif
