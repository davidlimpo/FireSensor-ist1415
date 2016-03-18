 #include <Timer.h>
 #include "FireSensor.h"
 
 configuration FireSensorAppC {
 }
 implementation {
   components MainC;
   components FireSensorC as App;
   components new TimerMilliC() as TimerGps;
   components new TimerMilliC() as TimerData;
   components new TimerMilliC() as TimerSmoke;
   components ActiveMessageC;
   components new AMSenderC(AM_FIRESENSOR);
   components new AMReceiverC(AM_FIRESENSOR);
 
   App.Boot -> MainC;
   App.TimerGps -> TimerGps;
   App.TimerData -> TimerData;
   App.TimerSmoke -> TimerSmoke;
   App.Packet -> AMSenderC;
   App.AMPacket -> AMSenderC;
   App.AMSend -> AMSenderC;
   App.AMControl -> ActiveMessageC;
   App.Receive -> AMReceiverC;
 }
